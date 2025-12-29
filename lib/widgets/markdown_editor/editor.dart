import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/providers/editor_provider.dart';
import 'package:journal/providers/db_provider.dart';

class MarkdownEditor extends ConsumerWidget {
  const MarkdownEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorProvider);
    final db = ref.watch(dbProvider);
    final controller = editorState.controller;
    final date = editorState.date;

    ref.listen<EditorState>(editorProvider, (previous, next) {
      if (previous?.date != next.date) {
        final dateString = next.date;
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
          if (text.isEmpty) {
            // Remove entry from database.
            await db.removeEntry(date);
          } else {
            await db.upsertEntry(date, text);
          }
        },
        decoration: const InputDecoration(
          // TODO: No border on sides of window
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.zero),
          ),
          hintText: '...',
        ),
      ),
    );
  }
}
