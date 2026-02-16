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

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final controller = editorState.controller;
    final date = editorState.date;

    // Listen for date changes and update controller text accordingly
    ref.listen<EditorState>(editorProvider, (previous, next) {
      if (previous?.date != next.date) {
        final dateString = next.date;
        ref.read(entriesProvider.notifier).getEntryContent(dateString).then((entry) {
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
                      _isEditMode = !_isEditMode;
                    });
                  },
                  child: Markdown(
                    data: controller.text,
                    selectable: true,
                    padding: const EdgeInsets.all(12),
                    styleSheet: MarkdownStyleSheet(
                      a: const TextStyle(
                        color: Colors.blue,
                      ),
                      code: const TextStyle(
                        backgroundColor: Color(0xFFF5F5F5),
                        fontFamily: 'monospace',
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
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
                              content: Text(
                                'Failed to open link: $e',
                              ),
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

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
