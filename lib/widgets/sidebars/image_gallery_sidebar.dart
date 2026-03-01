import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/providers/db_provider.dart';
import 'package:journal/providers/image_selection_provider.dart';
import 'package:journal/helpers/image_tools.dart';

class ImageGallerySidebar extends ConsumerWidget {
  const ImageGallerySidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
  final dbAsync = ref.watch(dbProvider);
  final refresh = ref.watch(imageListRefreshProvider);

  return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
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
                  final attachments = await db.getAllAttachments();
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
                  final attachments = await db.getAllAttachments();
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
                future: db.getAllAttachments(),
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
                      final Uint8List? imageBytes = attachment['data'];
                      if (imageBytes == null) {
                        return const Icon(Icons.broken_image);
                      }
                      return _ImageTile(imageBytes: imageBytes, index: index);
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

class _ImageTile extends ConsumerWidget {
  final Uint8List imageBytes;
  final int index;

  const _ImageTile({required this.imageBytes, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedImageIndexProvider);
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => ref.read(selectedImageIndexProvider.notifier).select(index),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image.memory(
            imageBytes,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}