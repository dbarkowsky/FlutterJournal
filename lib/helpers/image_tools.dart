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
