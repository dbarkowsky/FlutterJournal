import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final controller = editorState.controller;
    final date = editorState.date;

    // Listen for date changes and update controller text accordingly
    ref.listen<EditorState>(editorProvider, (previous, next) {
      setState(() {
        _isEditMode = false;
      });
      if (previous?.date != next.date) {
        final dateString = next.date;
        ref.read(entriesProvider.notifier).getEntryContent(dateString).then((
          entry,
        ) {
          controller.text = entry;
        });
      }
    });

    // On initial build, load the entry for the current date if needed
    ref.read(entriesProvider.notifier).getEntryContent(date).then((entry) {
      controller.text = entry;
    });

    return Column(
      children: [
        // Options bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            spacing: 2,
            children: [
              TextButton(
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
              ? TextField(
                  controller: controller,
                  textAlignVertical: TextAlignVertical.top,
                  maxLines: null,
                  expands: true,
                  onChanged: (text) async {
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
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.zero),
                    ),
                    hintText: '...',
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
