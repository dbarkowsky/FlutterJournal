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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
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

      final accessString = 'attachment:$attachmentId';
      Navigator.of(context).pop(accessString);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Insert Image'),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'File'),
                Tab(text: 'URL'),
              ],
              onTap: (_) => setState(() {}),
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
            else
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: 'Image URL'),
              ),
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
            }
          },
          child: const Text('Insert'),
        ),
      ],
    );
  }
}
