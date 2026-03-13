import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:journal/sqlite/database.dart';

class ImageViewerDialog extends StatefulWidget {
  final JournalDB db;
  final int attachmentId;
  final String createdAt;
  final String? updatedAt;
  final String mimeType;

  const ImageViewerDialog({
    super.key,
    required this.db,
    required this.attachmentId,
    required this.createdAt,
    this.updatedAt,
    required this.mimeType,
  });

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  Uint8List? _imageData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final attachment = await widget.db.getAttachment(widget.attachmentId);
      if (attachment == null) {
        setState(() {
          _error = 'Image not found.';
          _loading = false;
        });
        return;
      }
      final raw = attachment['data'];
      Uint8List? bytes;
      if (raw is Uint8List) {
        bytes = raw;
      } else if (raw is List) {
        bytes = Uint8List.fromList(raw.cast<int>());
      }
      setState(() {
        _imageData = bytes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load image: $e';
        _loading = false;
      });
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!))
                        : InteractiveViewer(
                            child: Image.memory(_imageData!, fit: BoxFit.contain),
                          ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Type: ${widget.mimeType}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text('Uploaded: ${_formatDate(widget.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (widget.updatedAt != null) ...[
                    const SizedBox(height: 2),
                    Text('Updated: ${_formatDate(widget.updatedAt)}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            OverflowBar(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
