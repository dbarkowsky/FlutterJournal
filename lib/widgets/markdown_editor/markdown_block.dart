import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

class MarkdownBlock extends StatefulWidget {
  final String initialText;
  final Function(String) onChanged;
  final Function() onSubmittedLine;
  final Function() onBackspaceEmpty;

  const MarkdownBlock({
    super.key,
    required this.initialText,
    required this.onChanged,
    required this.onSubmittedLine,
    required this.onBackspaceEmpty,
  });

  @override
  State<MarkdownBlock> createState() => _MarkdownBlockState();
}

class _MarkdownBlockState extends State<MarkdownBlock> {
  late TextEditingController _controller;
  bool isEditing = false;
  late FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.backspace &&
            _controller.text.isEmpty) {
          widget.onBackspaceEmpty();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          node.unfocus();
          setState(() {
            isEditing = false;
          });
          widget.onSubmittedLine();
          return KeyEventResult.handled;
        } else {
          return KeyEventResult.ignored;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextField(
          controller: _controller,
          focusNode: focusNode,
          autofocus: true,
          keyboardType: TextInputType.multiline,
          maxLines: 1,
          style: const TextStyle(fontSize: 16, height: 1.4),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
          onChanged: widget.onChanged,
          onTapOutside: (event) => setState(() {
            isEditing = false;
          }),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () {
          setState(() {
            isEditing = true;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: MarkdownBody(
            data: _controller.text,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(
                  p: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
          ),
          // child: Text(
          //   _controller.text,
          //   style: const TextStyle(
          //     fontSize: 16,
          //     height: 1.4,
          //     color: Colors.purple,
          //   ),
          // ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
