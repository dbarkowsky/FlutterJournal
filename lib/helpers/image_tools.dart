import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:journal/sqlite/database.dart';

const int _maxImageDimension = 2048;
const int _jpegQuality = 85;

/// Resizes [bytes] so neither dimension exceeds [_maxImageDimension] and
/// re-encodes at [_jpegQuality]. PNG inputs stay PNG; everything else becomes
/// JPEG. Returns the original bytes if compression yields a larger result.
Future<Uint8List> compressImageBytes(Uint8List bytes, String mimeType) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  img.Image resized = decoded;
  if (decoded.width > _maxImageDimension || decoded.height > _maxImageDimension) {
    resized = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: _maxImageDimension)
        : img.copyResize(decoded, height: _maxImageDimension);
  }

  final encoded = switch (mimeType.toLowerCase()) {
    'image/png' => img.encodePng(resized),
    _ => img.encodeJpg(resized, quality: _jpegQuality),
  };

  final result = Uint8List.fromList(encoded);
  return result.length < bytes.length ? result : bytes;
}

/// Replaces the image data for an existing attachment.
/// Returns true if successful, false otherwise.
Future<bool> replaceAttachmentImage({
  required BuildContext context,
  required JournalDB db,
  required int attachmentId,
}) async {
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: 'Replace Image File',
    type: FileType.image,
  );
  if (result != null && result.files.single.path != null) {
    final pickedPath = result.files.single.path!;
    final file = File(pickedPath);
    final bytes = await file.readAsBytes();
    final mimeType = 'image/${pickedPath.split('.').last}';
    final compressedBytes = await compressImageBytes(bytes, mimeType);
    try {
      await db.updateAttachment(
        id: attachmentId,
        mimeType: mimeType,
        data: compressedBytes,
      );
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to replace image: $e')),
        );
      }
      return false;
    }
  }
  return false;
}

/// Deletes an attachment by id after checking for referencing entries.
/// If the image is in use, shows a warning dialog. If the user confirms,
/// the image markdown is removed from all referencing entries before deleting.
/// Returns true if deleted, false if cancelled or failed.
Future<bool> deleteAttachmentImage({
  required BuildContext context,
  required JournalDB db,
  required int attachmentId,
}) async {
  try {
    // Collect dates into a plain list first so that subsequent writes
    // don't interfere with the query result set.
    final referencingDates =
        await db.getEntryDatesReferencingAttachment(attachmentId);

    if (referencingDates.isNotEmpty) {
      if (!context.mounted) return false;
      final count = referencingDates.length;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Image In Use'),
          content: Text(
            'This image is referenced in $count ${count == 1 ? 'entry' : 'entries'}. '
            'Deleting it will remove the image from those entries. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return false;

      // Remove the image markdown from every referencing entry independently
      // so a failure on one entry does not stop the rest.
      for (final date in referencingDates) {
        try {
          await db.removeAttachmentFromEntry(date, attachmentId);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not clean entry $date: $e')),
            );
          }
        }
      }
    }

    await db.deleteAttachment(attachmentId);
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete image: $e')),
      );
    }
    return false;
  }
}

/// Picks an image file and inserts it into the attachments table.
/// Returns the attachment id if successful, or null if cancelled/failed.
Future<int?> pickAndInsertImage({
  required BuildContext context,
  required JournalDB db,
}) async {
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: 'Select Image File',
    type: FileType.image,
  );
  if (result != null && result.files.single.path != null) {
    final pickedPath = result.files.single.path!;
    final file = File(pickedPath);
    final bytes = await file.readAsBytes();
    final mimeType = 'image/${p.extension(pickedPath).replaceAll('.', '')}';
    final compressedBytes = await compressImageBytes(bytes, mimeType);
    try {
      final attachmentId = await db.insertAttachment(
        mimeType: mimeType,
        data: compressedBytes,
      );
      return attachmentId;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add image: $e')),
        );
      }
      return null;
    }
  }
  return null;
}
