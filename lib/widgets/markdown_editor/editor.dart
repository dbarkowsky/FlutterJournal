import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/providers/editor_provider.dart';
import 'package:journal/providers/db_provider.dart';

class MarkdownEditor extends ConsumerWidget {
  const MarkdownEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorProvider);
    final dbState = ref.watch(dbProvider);
    final db = dbState["db"];
    final controller = editorState.controller;
    final date = editorState.date;

    ref.listen<EditorState>(editorProvider, (previous, next) {
      if (previous?.date != next.date && db != null) {
        final dateString = next.date.toIso8601String().split('T').first;
        db.getEntry(dateString).then((entry) {
          if (controller.text != entry) {
            controller.text = entry ?? "";
          }
        });
      }
    });

    return SizedBox.expand(
      child: TextField(
        controller: controller,
        textAlignVertical: TextAlignVertical.top,
        maxLines: null,
        expands: true,
        onChanged: (text) async {
          if (db != null) {
            await db.upsertEntry(date.toIso8601String().split('T').first, text);
          }
        },
        decoration: const InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.zero),
          ),
          hintText: 'Write your journal entry (Markdown supported)...',
        ),
      ),
    );
  }
}
