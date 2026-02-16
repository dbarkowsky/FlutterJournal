import 'package:flutter/material.dart';
import 'image_insert_modal.dart';

class EditorToolbar extends StatelessWidget {
  final String date;
  final TextEditingController controller;
  final bool isEdit;
  final VoidCallback onEditPress;
  final Future<void> Function(String text) onSave;

  const EditorToolbar({
    super.key,
    required this.date,
    required this.controller,
    required this.isEdit,
    required this.onEditPress,
    required this.onSave,
  });

  // Helper to insert markdown at cursor
  Future<void> _insertMarkdown(
    TextEditingController controller,
    String left,
    String right,
  ) async {
    final text = controller.text;
    final selection = controller.selection;
    final selectedText = selection.isValid && selection.start != selection.end
        ? text.substring(selection.start, selection.end)
        : '';
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '$left$selectedText$right',
    );
    controller.text = newText;
    final newPos =
        selection.start + left.length + selectedText.length + right.length;
    controller.selection = TextSelection.collapsed(offset: newPos);
    await onSave(controller.text);
  }

  Future<void> _insertTableMarkdown(TextEditingController controller) async {
    const table =
        '| Header 1 | Header 2 | Header 3 |\n| --- | --- | --- |\n| Row 1 Col 1 | Row 1 Col 2 | Row 1 Col 3 |\n| Row 2 Col 1 | Row 2 Col 2 | Row 2 Col 3 |\n';
    final text = controller.text;
    final selection = controller.selection;
    final newText = text.replaceRange(selection.start, selection.end, table);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(
      offset: selection.start + table.length,
    );
    await onSave(controller.text);
  }

  Widget buildIconButton(String tooltip, Icon icon, VoidCallback onPressed) {
    return IconButton(
      tooltip: tooltip,
      icon: icon,
      constraints: BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.all(4),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minButtonsWidth = 400;
          final showDropdown =
              constraints.maxWidth <
              (minButtonsWidth + 300); // 300 for date, divider, button
          final iconActions = [
            {
              'label': 'Bold',
              'icon': Icon(Icons.format_bold),
              'onTap': () => _insertMarkdown(controller, '**', '**'),
            },
            {
              'label': 'Italics',
              'icon': Icon(Icons.format_italic),
              'onTap': () => _insertMarkdown(controller, '*', '*'),
            },
            {
              'label': 'Strikethrough',
              'icon': Icon(Icons.strikethrough_s),
              'onTap': () => _insertMarkdown(controller, '~~', '~~'),
            },
            {
              'label': 'Header 1',
              'icon': Icon(Icons.title),
              'onTap': () => _insertMarkdown(controller, '# ', ''),
            },
            {
              'label': 'Header 2',
              'icon': Icon(Icons.title, size: 18),
              'onTap': () => _insertMarkdown(controller, '## ', ''),
            },
            {
              'label': 'Header 3',
              'icon': Icon(Icons.title, size: 14),
              'onTap': () => _insertMarkdown(controller, '### ', ''),
            },
            {
              'label': 'Insert Link',
              'icon': Icon(Icons.link),
              'onTap': () => _insertMarkdown(controller, '[', '](url)'),
            },
            {
              'label': 'Insert Image',
              'icon': Icon(Icons.image),
              'onTap': () async {
                final imageUrl = await showDialog<String>(
                  context: context,
                  builder: (ctx) => ImageInsertModal(
                    onInsert: (url) => Navigator.of(ctx).pop(url),
                  ),
                );
                if (imageUrl != null && imageUrl.isNotEmpty) {
                  final text = controller.text;
                  final selection = controller.selection;
                  final imageMarkdown = '![]($imageUrl)';
                  String newText;
                  int newOffset;
                  if (text.isEmpty) {
                    newText = imageMarkdown;
                    newOffset = imageMarkdown.length;
                  } else {
                    newText = text.replaceRange(
                      selection.start,
                      selection.end,
                      imageMarkdown,
                    );
                    newOffset = selection.start + imageMarkdown.length;
                  }
                  controller.text = newText;
                  controller.selection = TextSelection.collapsed(
                    offset: newOffset,
                  );
                  await onSave(controller.text);
                }
              },
            },
            {
              'label': 'Insert Table',
              'icon': Icon(Icons.table_chart),
              'onTap': () => _insertTableMarkdown(controller),
            },
            {
              'label': 'Insert Code Block',
              'icon': Icon(Icons.code),
              'onTap': () => _insertMarkdown(controller, '```\n', '\n```'),
            },
          ];

          return Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 2,
            children: [
              Text(
                date,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              SizedBox(height: 28, child: VerticalDivider(thickness: 1)),
              TextButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    Colors.lightBlueAccent.withAlpha(70),
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
                onPressed: onEditPress,
                child: Text(
                  isEdit ? 'View' : 'Edit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              // Markdown option buttons
              SizedBox(width: 8),
              if (!showDropdown)
                ...iconActions.map(
                  (action) => buildIconButton(
                    action['label'] as String,
                    action['icon'] as Icon,
                    action['onTap'] as VoidCallback,
                  ),
                )
              else
                SizedBox(
                  width: 32,
                  height: 32,
                  child: PopupMenuButton<int>(
                    tooltip: 'Formatting',
                    icon: Icon(Icons.more_horiz, size: 24),
                    padding: EdgeInsets.zero,
                    itemBuilder: (context) => [
                      for (int i = 0; i < iconActions.length; i++)
                        PopupMenuItem<int>(
                          value: i,
                          child: Row(
                            children: [
                              iconActions[i]['icon'] as Icon,
                              SizedBox(width: 8),
                              Text(iconActions[i]['label'] as String),
                            ],
                          ),
                        ),
                    ],
                    onSelected: (i) =>
                        (iconActions[i]['onTap'] as VoidCallback?)?.call(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
