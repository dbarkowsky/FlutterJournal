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
    final multiSelect = ref.read(multiSelectProvider);

    if (multiSelect.isActive) {
      // In multi-select mode, tapping simply toggles this item.
      ref.read(multiSelectProvider.notifier).toggle(widget.attachmentId);
      return;
    }

    // Normal mode: single tap selects, double tap opens viewer.
    if (_doubleTapTimer != null && _doubleTapTimer!.isActive) {
      _doubleTapTimer!.cancel();
      _doubleTapTimer = null;
      _openViewer();
    } else {
      ref.read(selectedImageIndexProvider.notifier).select(widget.index);
      _doubleTapTimer = Timer(_doubleTapWindow, () {
        _doubleTapTimer = null;
      });
    }
  }

  void _handleLongPress() {
    // Long press always enters multi-select mode and selects this tile.
    ref.read(selectedImageIndexProvider.notifier).select(null);
    ref.read(multiSelectProvider.notifier).enterMode(widget.attachmentId);
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
    final multiSelectState = ref.watch(multiSelectProvider);
    final isMultiSelected =
        multiSelectState.isActive &&
        multiSelectState.selectedIds.contains(widget.attachmentId);

    final highlighted = isMultiSelected || (!multiSelectState.isActive && isSelected);

    return GestureDetector(
      onTap: _handleTap,
      onLongPress: _handleLongPress,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: highlighted ? Colors.blue : Colors.transparent,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                widget.imageBytes,
                fit: BoxFit.cover,
              ),
              if (multiSelectState.isActive)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isMultiSelected
                          ? Colors.blue
                          : Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      isMultiSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
