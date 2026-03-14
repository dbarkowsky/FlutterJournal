import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/providers/db_provider.dart';
import 'package:journal/providers/editor_provider.dart';
import 'package:journal/providers/image_selection_provider.dart';
import 'package:journal/helpers/image_tools.dart';
import 'package:journal/widgets/sidebars/image_tile.dart';

class ImageGallerySidebar extends ConsumerWidget {
  const ImageGallerySidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
  final dbAsync = ref.watch(dbProvider);
  final refresh = ref.watch(imageListRefreshProvider);
  final multiSelect = ref.watch(multiSelectProvider);

  return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: multiSelect.isActive
              ? _MultiSelectToolbar(multiSelect: multiSelect)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate),
                      tooltip: 'Add Image',
                      onPressed: () async {
                        if (!dbAsync.hasValue) return;
                        final db = dbAsync.value!;
                        final id = await pickAndInsertImage(context: context, db: db);
                        if (id != null) {
                          ref.read(imageListRefreshProvider.notifier).refresh();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz),
                      tooltip: 'Replace Image',
                      onPressed: () async {
                        if (!dbAsync.hasValue) return;
                        final db = dbAsync.value!;
                        final selectedIndex = ref.read(selectedImageIndexProvider);
                        if (selectedIndex == null) return;
                        final attachments = await db.getAllAttachmentHeaders();
                        if (selectedIndex < 0 || selectedIndex >= attachments.length) return;
                        final attachment = attachments[selectedIndex];
                        final attachmentId = attachment['id'];
                        final success = await replaceAttachmentImage(
                          context: context,
                          db: db,
                          attachmentId: attachmentId,
                        );
                        if (success) {
                          ref.read(imageListRefreshProvider.notifier).refresh();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Delete Image',
                      onPressed: () async {
                        if (!dbAsync.hasValue) return;
                        final db = dbAsync.value!;
                        final selectedIndex = ref.read(selectedImageIndexProvider);
                        if (selectedIndex == null) return;
                        final attachments = await db.getAllAttachmentHeaders();
                        if (selectedIndex < 0 || selectedIndex >= attachments.length) return;
                        final attachment = attachments[selectedIndex];
                        final attachmentId = attachment['id'];
                        final success = await deleteAttachmentImage(
                          context: context,
                          db: db,
                          attachmentId: attachmentId,
                        );
                        if (success) {
                          ref.read(imageListRefreshProvider.notifier).refresh();
                          ref.read(selectedImageIndexProvider.notifier).select(null);
                          // Reload the active entry so the editor reflects any
                          // image markdown that was removed.
                          final editorDate = ref.read(editorProvider).date;
                          final updatedContent = await ref
                              .read(entriesProvider.notifier)
                              .getEntryContent(editorDate);
                          ref.read(editorProvider.notifier).setText(updatedContent);
                        }
                      },
                    ),
                  ],
                ),
        ),
        Expanded(
          child: dbAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (db) {
              // Use refresh to trigger rebuild
              return FutureBuilder<List<Map<String, dynamic>>>(
                key: ValueKey(refresh),
                future: db.getAllAttachmentHeaders(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No images found.'));
                  }
                  final attachments = snapshot.data!;
                  return GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: attachments.length,
                    itemBuilder: (context, index) {
                      final attachment = attachments[index];
                      final rawThumb = attachment['thumbnail'];
                      Uint8List? imageBytes;
                      if (rawThumb is Uint8List) {
                        imageBytes = rawThumb;
                      } else if (rawThumb is List) {
                        imageBytes = Uint8List.fromList(rawThumb.cast<int>());
                      }
                      if (imageBytes == null) {
                        return const Icon(Icons.broken_image);
                      }
                      return ImageTile(
                        imageBytes: imageBytes,
                        index: index,
                        attachmentId: attachment['id'] as int,
                        createdAt: attachment['created_at'] as String? ?? '',
                        updatedAt: attachment['updated_at'] as String?,
                        mimeType: attachment['mime_type'] as String? ?? 'image/jpeg',
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Toolbar shown while multi-select mode is active.
class _MultiSelectToolbar extends ConsumerWidget {
  final MultiSelectState multiSelect;

  const _MultiSelectToolbar({required this.multiSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = multiSelect.selectedIds.length;

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.deselect),
          tooltip: 'Deselect All',
          onPressed: () {
            ref.read(multiSelectProvider.notifier).deselectAll();
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          tooltip: 'Delete Selected',
          onPressed: count == 0
              ? null
              : () async {
                  final dbAsync = ref.read(dbProvider);
                  if (!dbAsync.hasValue) return;
                  final db = dbAsync.value!;
                  final ids = multiSelect.selectedIds.toList();
                  final success = await deleteMultipleAttachmentImages(
                    context: context,
                    db: db,
                    attachmentIds: ids,
                  );
                  if (success) {
                    ref.read(multiSelectProvider.notifier).deselectAll();
                    ref.read(selectedImageIndexProvider.notifier).select(null);
                    ref.read(imageListRefreshProvider.notifier).refresh();
                    // Reload the active entry to reflect removed image markdown.
                    final editorDate = ref.read(editorProvider).date;
                    final updatedContent = await ref
                        .read(entriesProvider.notifier)
                        .getEntryContent(editorDate);
                    ref.read(editorProvider.notifier).setText(updatedContent);
                  }
                },
        ),
        const SizedBox(width: 4),
        Text(
          '$count selected',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
