import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_html/flutter_html.dart';
import 'package:journal/providers/editor_provider.dart';
import 'package:journal/providers/db_provider.dart';

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
        ref.read(entriesProvider.notifier).getEntryContent(dateString).then((
          entry,
        ) {
          controller.text = entry;
        });
      }
      // Always open a day's entry in view mode
      setState(() {
        _isEditMode = false;
      });
    });

    // On initial build, load the entry for the current date if needed
    ref.read(entriesProvider.notifier).getEntryContent(date).then((entry) {
      if (controller.text != entry) {
        controller.text = entry;
        // Empty state call just to refresh widget after text is loaded in controller
        setState(() {});
      }
    });

    return Column(
      children: [
        // Options bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 2,
            children: [
              Text(
                date,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              SizedBox(
                height: 28, // Set height to match your row content
                child: VerticalDivider(thickness: 1),
              ),
              TextButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    Colors.lightBlueAccent.withAlpha(70),
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ), // Makes it more square
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _isEditMode = !_isEditMode;
                  });
                },
                child: Text(
                  _isEditMode ? 'View' : 'Edit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isEditMode
              ? KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (KeyEvent event) async {
                    if (event is KeyDownEvent) {
                      final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
                      if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyS) {
                        final text = controller.text;
                        if (text.isEmpty) {
                          await ref.read(entriesProvider.notifier).removeEntry(date);
                        } else {
                          await ref.read(entriesProvider.notifier).addOrUpdateEntry(date, text);
                        }
                        // Optionally show a snackbar or feedback
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Manual save! (Ctrl+S)')),
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
                          if (text.isEmpty) {
                            await ref.read(entriesProvider.notifier).removeEntry(date);
                            return;
                          }
                          await ref.read(entriesProvider.notifier).addOrUpdateEntry(date, text);
                        },
                      );
                    },
                    decoration: const InputDecoration(hintText: '...'),
                  ),
                )
              : GestureDetector(
                  child: _MarkdownView(markdownData: controller.text),
                  onDoubleTap: () {
                    setState(() {
                      _isEditMode = !_isEditMode;
                    });
                  },
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

/// A widget to render markdown using the markdown package and flutter_html for display
class _MarkdownView extends StatelessWidget {
  final String markdownData;
  const _MarkdownView({required this.markdownData});

  @override
  Widget build(BuildContext context) {
    final html = md.markdownToHtml(markdownData);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Html(
        data: html,
        style: {
          "body": Style(
            margin: Margins.zero,
            fontSize: FontSize(
              Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16,
            ),
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
          ),
        },
      ),
    );
  }
}
