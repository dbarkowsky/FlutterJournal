import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ImageInsertModal extends StatefulWidget {
  final void Function(String imageUrl) onInsert;
  const ImageInsertModal({super.key, required this.onInsert});

  @override
  State<ImageInsertModal> createState() => _ImageInsertModalState();
}

class _ImageInsertModalState extends State<ImageInsertModal>
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
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        dialogTitle: 'Select Image File',
                        type: FileType.image,
                      );
                      if (result != null && result.files.single.path != null) {
                        setState(() {
                          String path = result.files.single.path!;
                          path = path.replaceAll('\\', '/'); // Normalize for Windows paths
                          _filePath = 'file:///${path}';
                        });
                      }
                    },
                    child: const Text('Select Image File'),
                  ),
                  if (_filePath != null) ...[
                    const SizedBox(height: 8),
                    Text('Selected: $_filePath'),
                  ],
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
          onPressed: () {
            if (_tabController.index == 0 && _filePath != null) {
              widget.onInsert(_filePath!);
            } else if (_tabController.index == 1 &&
                _urlController.text.isNotEmpty) {
              widget.onInsert(_urlController.text);
            }
          },
          child: const Text('Insert'),
        ),
      ],
    );
  }
}
