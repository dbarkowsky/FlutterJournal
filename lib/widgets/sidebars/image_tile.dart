import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/providers/db_provider.dart';
import 'package:journal/providers/image_selection_provider.dart';
import 'package:journal/widgets/sidebars/image_viewer_dialog.dart';

class ImageTile extends ConsumerStatefulWidget {
  final Uint8List imageBytes;
  final int index;
  final int attachmentId;
  final String createdAt;
  final String? updatedAt;
  final String mimeType;

  const ImageTile({
    super.key,
    required this.imageBytes,
    required this.index,
    required this.attachmentId,
    required this.createdAt,
    this.updatedAt,
    required this.mimeType,
  });

  @override
  ConsumerState<ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends ConsumerState<ImageTile> {
  Timer? _doubleTapTimer;
  static const _doubleTapWindow = Duration(milliseconds: 250);

  void _handleTap() {
    if (_doubleTapTimer != null && _doubleTapTimer!.isActive) {
      // Second tap within window — treat as double tap
      _doubleTapTimer!.cancel();
      _doubleTapTimer = null;
      _openViewer();
    } else {
      // First tap — select immediately, then wait for possible second tap
      ref.read(selectedImageIndexProvider.notifier).select(widget.index);
      _doubleTapTimer = Timer(_doubleTapWindow, () {
        _doubleTapTimer = null;
      });
    }
  }

  void _openViewer() {
    final dbAsync = ref.read(dbProvider);
    if (!dbAsync.hasValue) return;
    showDialog(
      context: context,
      builder: (_) => ImageViewerDialog(
        db: dbAsync.value!,
        attachmentId: widget.attachmentId,
        createdAt: widget.createdAt,
        updatedAt: widget.updatedAt,
        mimeType: widget.mimeType,
      ),
    );
  }

  @override
  void dispose() {
    _doubleTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = ref.watch(
      selectedImageIndexProvider.select((idx) => idx == widget.index),
    );

    return GestureDetector(
      onTap: _handleTap,
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
            widget.imageBytes,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
