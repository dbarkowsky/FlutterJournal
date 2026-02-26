import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:journal/helpers/image_tools.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/providers/db_provider.dart';

class ImageInsertModal extends ConsumerStatefulWidget {
  final void Function(String markdown) onInsert;
  const ImageInsertModal({super.key, required this.onInsert});

  @override
  ConsumerState<ImageInsertModal> createState() => _ImageInsertModalState();
}

class _ImageInsertModalState extends ConsumerState<ImageInsertModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  String? _filePath;

  // Gallery tab state
  List<Map<String, dynamic>> _galleryAttachments = [];
  bool _galleryLoading = false;
  int? _selectedAttachmentId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
      if (_tabController.index == 2 && _galleryAttachments.isEmpty && !_galleryLoading) {
        _loadGallery();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadGallery() async {
    final dbAsync = ref.read(dbProvider);
    if (!dbAsync.hasValue) return;
    setState(() => _galleryLoading = true);
    try {
      final attachments = await dbAsync.value!.getAllAttachments();
      if (mounted) {
        setState(() {
          _galleryAttachments = attachments;
          _galleryLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _galleryLoading = false);
    }
  }

  Future<void> _handleFileInsert() async {
    final dbAsync = ref.read(dbProvider);
    if (!dbAsync.hasValue) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to access database.')),
      );
      Navigator.of(context).pop();
      return;
    }
    final db = dbAsync.value!;
    // Insert into attachments table
    final attachmentId = await pickAndInsertImage(context: context, db: db);

    if (attachmentId == null) return; // user cancelled picker
    if (!context.mounted) return;
    Navigator.of(context).pop('attachment:$attachmentId');
  }

  Widget _buildGalleryTab() {
    if (_galleryLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_galleryAttachments.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No attachments found.')),
      );
    }
    return SizedBox(
      height: 260,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: _galleryAttachments.length,
        itemBuilder: (context, index) {
          final attachment = _galleryAttachments[index];
          final id = attachment['id'] as int;
          final rawData = attachment['data'];
          Uint8List? bytes;
          if (rawData is Uint8List) {
            bytes = rawData;
          } else if (rawData is List<int>) {
            bytes = Uint8List.fromList(rawData);
          }

          final isSelected = _selectedAttachmentId == id;
          return GestureDetector(
            onTap: () => setState(() => _selectedAttachmentId = id),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: bytes != null
                    ? Image.memory(bytes, fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.broken_image)),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Insert Image'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'File'),
                Tab(text: 'URL'),
                Tab(text: 'Gallery'),
              ],
            ),
            const SizedBox(height: 16),
            if (_tabController.index == 0)
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _handleFileInsert,
                    child: const Text('Select Image File'),
                  ),
                ],
              )
            else if (_tabController.index == 1)
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: 'Image URL'),
              )
            else
              _buildGalleryTab(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_tabController.index == 0 && _filePath != null) {
              // Not used, file picker returns immediately
            } else if (_tabController.index == 1 &&
                _urlController.text.isNotEmpty) {
              Navigator.of(context).pop(_urlController.text);
            } else if (_tabController.index == 2 &&
                _selectedAttachmentId != null) {
              Navigator.of(context).pop('attachment:$_selectedAttachmentId');
            }
          },
          child: const Text('Insert'),
        ),
      ],
    );
  }
}
