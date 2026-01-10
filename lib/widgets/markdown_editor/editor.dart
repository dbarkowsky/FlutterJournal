import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/widgets/markdown_editor/editor_toolbar.dart';
import 'package:journal/providers/editor_provider.dart';
import 'package:journal/providers/db_provider.dart';
import 'package:markdown_widget/markdown_widget.dart';

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
                        if (text.isEmpty) {
                          await ref
                              .read(entriesProvider.notifier)
                              .removeEntry(date);
                        } else {
                          await ref
                              .read(entriesProvider.notifier)
                              .addOrUpdateEntry(date, text);
                        }
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
                          if (text.isEmpty) {
                            await ref
                                .read(entriesProvider.notifier)
                                .removeEntry(date);
                            return;
                          }
                          await ref
                              .read(entriesProvider.notifier)
                              .addOrUpdateEntry(date, text);
                        },
                      );
                    },
                    decoration: const InputDecoration(hintText: '...'),
                  ),
                )
              : GestureDetector(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: MarkdownBlock(data: controller.text),
                  ),
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
