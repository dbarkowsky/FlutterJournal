import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:journal/sqlite/database.dart';

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
    try {
      await db.updateAttachment(
        id: attachmentId,
        mimeType: mimeType,
        data: bytes,
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

/// Deletes an attachment by id. Returns true if successful.
Future<bool> deleteAttachmentImage({
  required BuildContext context,
  required JournalDB db,
  required int attachmentId,
}) async {
  try {
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
    try {
      final attachmentId = await db.insertAttachment(
        mimeType: mimeType,
        data: bytes,
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
