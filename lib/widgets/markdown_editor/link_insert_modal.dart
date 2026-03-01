import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LinkInsertModal extends StatefulWidget {
  /// Pre-filled link text (e.g. the currently selected editor text).
  final String initialLinkText;

  const LinkInsertModal({super.key, this.initialLinkText = ''});

  @override
  State<LinkInsertModal> createState() => _LinkInsertModalState();
}

class _LinkInsertModalState extends State<LinkInsertModal> {
  late final TextEditingController _urlController;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _textController = TextEditingController(text: widget.initialLinkText);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pasteUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
      _urlController.selection = TextSelection.collapsed(
        offset: _urlController.text.length,
      );
    }
  }

  void _submit() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    final text = _textController.text.trim();
    Navigator.of(context).pop({'url': url, 'text': text});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Insert Link'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Link text (optional)',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      hintText: 'https://',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    autofocus: widget.initialLinkText.isNotEmpty,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Paste from clipboard',
                  child: IconButton.outlined(
                    icon: const Icon(Icons.content_paste),
                    onPressed: _pasteUrl,
                  ),
                ),
              ],
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
          onPressed: _submit,
          child: const Text('Insert'),
        ),
      ],
    );
  }
}
