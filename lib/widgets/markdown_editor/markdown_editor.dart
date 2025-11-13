import 'package:flutter/material.dart';
import 'package:journal/widgets/markdown_editor/markdown_block.dart';

class MarkdownEditor extends StatefulWidget {
  final String initialText;

  const MarkdownEditor({super.key, required this.initialText});

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late List<TextEditingController> controllers;
  int editingIndex = 0;
  @override
  void initState() {
    super.initState();
    controllers = widget.initialText
        .split('\n')
        .map((text) => TextEditingController(text: text))
        .toList();
    if (controllers.isEmpty) {
      controllers.add(TextEditingController(text: ''));
    }
    if (controllers.length > 1) {
      editingIndex = controllers.length - 1;
    }
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < controllers.length; i++)
            MarkdownBlock(
              controller: controllers[i],
              isEditing: i == editingIndex,
              onSubmittedLine: () {
                setState(() {
                  // Add a new block right after this one and set it to editing mode
                  controllers.insert(i + 1, TextEditingController(text: ""));
                  editingIndex = i + 1;
                  // Place cursor at end of new block
                  controllers[editingIndex]
                      .selection = TextSelection.fromPosition(
                    TextPosition(offset: controllers[editingIndex].text.length),
                  );
                });
              },
              onBackspaceEmpty: () {
                // If there's no text in this block
                if (controllers[i].text.isEmpty) {
                  // If not the first block, remove this block and set previous to editing mode
                  if (i > 0) {
                    setState(() {
                      controllers[i].dispose();
                      controllers.removeAt(i);
                      editingIndex = i - 1;
                      // Place cursor at end of previous block
                      controllers[editingIndex].selection =
                          TextSelection.fromPosition(
                            TextPosition(
                              offset: controllers[editingIndex].text.length,
                            ),
                          );
                    });
                  }
                }
              },
              onTap: () {
                setState(() {
                  editingIndex = i;
                });
                
              },
              onTapOutside: (event) {
                setState(() {
                  editingIndex = -1;
                });
              },
            ),
        ],
      ),
    );
  }
}
