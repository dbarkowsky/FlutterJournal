import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io' show Platform, Process;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/widgets/markdown_editor/editor_toolbar.dart';
import 'package:journal/providers/editor_provider.dart';
import 'package:journal/providers/db_provider.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class MarkdownEditor extends ConsumerStatefulWidget {
  const MarkdownEditor({super.key});

  @override
  ConsumerState<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends ConsumerState<MarkdownEditor> {
  bool _isEditMode = false;
  Timer? _debounce;
  final FocusNode _editFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final controller = editorState.controller;
    final date = editorState.date;

    // Listen for date changes and update controller text accordingly
    ref.listen<EditorState>(editorProvider, (previous, next) {
      if (previous?.date != next.date) {
        final dateString = next.date;
        ref.read(entriesProvider.notifier).getEntryContent(dateString).then((
          entry,
        ) {
          controller.text = entry;
          // Always open a day's entry in view mode
          setState(() {
            _isEditMode = false;
          });
        });
      }
    });

    // On initial build, load the entry for the current date if needed
    ref.read(entriesProvider.notifier).getEntryContent(date).then((entry) {
      if (controller.text != entry) {
        controller.text = entry;
        // Empty state call just to refresh widget after text is loaded in controller
        setState(() {});
      }
    });

    Future<void> save(String text) async {
      if (text.isEmpty) {
        await ref.read(entriesProvider.notifier).removeEntry(date);
      } else {
        await ref.read(entriesProvider.notifier).addOrUpdateEntry(date, text);
      }
    }

    return Column(
      children: [
        // Options bar
        EditorToolbar(
          date: date,
          controller: controller,
          isEdit: _isEditMode,
          onEditPress: () {
            setState(() {
              _isEditMode = !_isEditMode;
            });
          },
          onSave: save,
        ),
        const Divider(height: 1),
        Expanded(
          child: _isEditMode
              ? KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (KeyEvent event) async {
                    if (event is KeyDownEvent) {
                      final isCtrlPressed =
                          HardwareKeyboard.instance.isControlPressed;
                      if (isCtrlPressed &&
                          event.logicalKey == LogicalKeyboardKey.keyS) {
                        final text = controller.text;
                        await save(text);
                        // Optionally show a snackbar or feedback
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Manual save! (Ctrl+S)'),
                          ),
                        );
                      }
                    }
                  },
                  child: TextField(
                    controller: controller,
                    focusNode: _editFocusNode,
                    textAlignVertical: TextAlignVertical.top,
                    maxLines: null,
                    expands: true,
                    onChanged: (text) {
                      _debounce?.cancel();
                      _debounce = Timer(
                        const Duration(milliseconds: 1000),
                        () async {
                          await save(text);
                        },
                      );
                    },
                    decoration: const InputDecoration(hintText: '...'),
                  ),
                )
              : GestureDetector(
                  onDoubleTap: () {
                    setState(() {
                      _isEditMode = true;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _editFocusNode.requestFocus();
                    });
                  },
                  child: Markdown(
                    // Adds extra blank lines to preserve single line breaks, but
                    // skips table rows so markdown table formatting is not broken.
                    data: _processMarkdownLineBreaks(controller.text),
                    selectable: true,
                    padding: const EdgeInsets.all(12),
                    styleSheet: MarkdownStyleSheet(
                      a: const TextStyle(color: Colors.blue),
                      code: const TextStyle(
                        backgroundColor: Color(0xFFF5F5F5),
                        fontFamily: 'monospace',
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    imageBuilder: (Uri uri, String? title, String? alt) {
                      // Parse Obsidian-style size hint from alt text.
                      // e.g. "![my image|300](url)" renders at 300 px wide.
                      double? imageWidth;
                      if (alt != null && alt.contains('|')) {
                        final pipeIdx = alt.lastIndexOf('|');
                        final sizePart = alt.substring(pipeIdx + 1).trim();
                        final parsed = double.tryParse(sizePart);
                        if (parsed != null && parsed > 0) {
                          imageWidth = parsed;
                        }
                      }

                      if (uri.scheme == 'attachment') {
                        final attachmentId = int.tryParse(uri.path);
                        if (attachmentId == null) {
                          return const Icon(Icons.broken_image);
                        }
                        final dbAsync = ref.read(dbProvider);
                        if (!dbAsync.hasValue) {
                          return const SizedBox.shrink();
                        }
                        final db = dbAsync.value!;
                        return FutureBuilder<Map<String, dynamic>?>(
                          future: db.getAttachment(attachmentId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }
                            if (!snapshot.hasData || snapshot.data == null) {
                              return const Icon(Icons.broken_image);
                            }
                            Uint8List imageBytes = snapshot.data!['data'];
                            return Image.memory(
                              imageBytes,
                              width: imageWidth,
                              fit: imageWidth != null
                                  ? BoxFit.contain
                                  : null,
                            );
                          },
                        );
                      }
                      if (uri.scheme == 'http' || uri.scheme == 'https') {
                        return Image.network(
                          uri.toString(),
                          width: imageWidth,
                          fit: imageWidth != null ? BoxFit.contain : null,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.broken_image);
                          },
                        );
                      }
                      return const Icon(Icons.broken_image);
                    },
                    onTapLink: (text, href, title) async {
                      if (href == null) return;
                      Uri uri = Uri.parse(href);
                      // if the link is missing the protocol, we have to add it
                      if (uri.scheme.isEmpty) {
                        uri = Uri.parse('https://$href');
                      }
                      try {
                        if (Platform.isWindows) {
                          await Process.run('start', [
                            uri.toString(),
                          ], runInShell: true);
                        } else if (Platform.isMacOS) {
                          await Process.run('open', [uri.toString()]);
                        } else if (Platform.isLinux) {
                          await Process.run('xdg-open', [uri.toString()]);
                        } else {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to open link: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
        ),
      ],
    );
  }

  /// Inserts extra blank lines between non-table lines so that single newlines
  /// in the source are rendered as line breaks in the markdown preview.
  /// Table rows (lines starting with `|`) are kept consecutive so that the
  /// table structure is preserved.
  String _processMarkdownLineBreaks(String text) {
    final lines = text.split('\n');
    final buffer = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
      buffer.write(lines[i]);
      buffer.write('\n');
      if (i < lines.length - 1) {
        final curr = lines[i].trimLeft();
        final next = lines[i + 1].trimLeft();
        // Don't add a blank line if either side is a table row/separator,
        // or if either side is already blank (avoids triple newlines).
        if (!curr.startsWith('|') &&
            !next.startsWith('|') &&
            curr.isNotEmpty &&
            next.isNotEmpty) {
          buffer.write('\n');
        }
      }
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _editFocusNode.dispose();
    super.dispose();
  }
}
