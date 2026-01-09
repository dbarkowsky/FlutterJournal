import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/providers/editor_provider.dart';
import 'package:journal/providers/db_provider.dart';

class MarkdownEditor extends ConsumerWidget {
  const MarkdownEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorProvider);
    final dbAsync = ref.watch(dbProvider);
    final controller = editorState.controller;
    final date = editorState.date;

    return dbAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('DB Error: $e')),
      data: (db) {
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
              if (text.isEmpty){
                await ref.read(entriesProvider.notifier).removeEntry(date);
                return;
              }
              await ref.read(entriesProvider.notifier).addOrUpdateEntry(date, text);
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.zero),
              ),
              hintText: '...',
            ),
          ),
        );
      },
    );
  }
}
