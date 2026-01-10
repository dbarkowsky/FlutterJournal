

import 'package:flutter/material.dart';

class EditorToolbar extends StatelessWidget
{
  String date;
  TextEditingController controller;
  bool isEdit;
  VoidCallback onEditPress;

  EditorToolbar({super.key, required this.date, required this.controller, required this.isEdit, required this.onEditPress });
  
  // Helper to insert markdown at cursor
  void _insertMarkdown(TextEditingController controller, String left, String right) {
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
    final newPos = selection.start + left.length + selectedText.length + right.length;
    controller.selection = TextSelection.collapsed(offset: newPos);
  }

  // Helper to insert a markdown table
  void _insertTableMarkdown(TextEditingController controller) {
    const table =
        '| Header 1 | Header 2 | Header 3 |\n| --- | --- | --- |\n| Row 1 Col 1 | Row 1 Col 2 | Row 1 Col 3 |\n| Row 2 Col 1 | Row 2 Col 2 | Row 2 Col 3 |\n';
    final text = controller.text;
    final selection = controller.selection;
    final newText = text.replaceRange(selection.start, selection.end, table);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: selection.start + table.length);
  }

  @override
  Widget build(BuildContext context) {
  return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 2,
            children: [
              Text(
                date,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              SizedBox(
                height: 28,
                child: VerticalDivider(thickness: 1),
              ),
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
                    const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
                onPressed: this.onEditPress,
                child: Text(
                  isEdit ? 'View' : 'Edit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              // Markdown option buttons
              SizedBox(width: 8),
              IconButton(
                tooltip: 'Bold',
                icon: Icon(Icons.format_bold),
                onPressed: () => _insertMarkdown(controller, '**', '**'),
              ),
              IconButton(
                tooltip: 'Italics',
                icon: Icon(Icons.format_italic),
                onPressed: () => _insertMarkdown(controller, '*', '*'),
              ),
              IconButton(
                tooltip: 'Underline',
                icon: Icon(Icons.format_underline),
                onPressed: () => _insertMarkdown(controller, '<u>', '</u>'),
              ),
              IconButton(
                tooltip: 'Strikethrough',
                icon: Icon(Icons.strikethrough_s),
                onPressed: () => _insertMarkdown(controller, '~~', '~~'),
              ),
              IconButton(
                tooltip: 'Header 1',
                icon: Icon(Icons.title),
                onPressed: () => _insertMarkdown(controller, '# ', ''),
              ),
              IconButton(
                tooltip: 'Header 2',
                icon: Icon(Icons.title, size: 18),
                onPressed: () => _insertMarkdown(controller, '## ', ''),
              ),
              IconButton(
                tooltip: 'Header 3',
                icon: Icon(Icons.title, size: 14),
                onPressed: () => _insertMarkdown(controller, '### ', ''),
              ),
              IconButton(
                tooltip: 'Insert Link',
                icon: Icon(Icons.link),
                onPressed: () => _insertMarkdown(controller, '[', '](url)'),
              ),
              IconButton(
                tooltip: 'Insert Image',
                icon: Icon(Icons.image),
                onPressed: () => _insertMarkdown(controller, '![', '](url)'),
              ),
              IconButton(
                tooltip: 'Insert Table',
                icon: Icon(Icons.table_chart),
                onPressed: () => _insertTableMarkdown(controller),
              ),
            ],
          ),
        );
    
  }
}
