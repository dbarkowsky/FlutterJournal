import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class MarkdownBlock extends StatelessWidget {
  final bool isEditing;
  final Function() onSubmittedLine;
  final Function() onBackspaceEmpty;
  final TapRegionCallback? onTapOutside;
  final Function() onTap;
  final TextEditingController controller;

  const MarkdownBlock({
    super.key,
    required this.isEditing,
    required this.onSubmittedLine,
    required this.onBackspaceEmpty,
    required this.onTapOutside,
    required this.onTap,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextField(
          controller: controller,
          focusNode: FocusNode(
            onKeyEvent: (node, event) {
              if (event.logicalKey == LogicalKeyboardKey.backspace &&
                  controller.text.isEmpty) {
                onBackspaceEmpty();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                onSubmittedLine();
                return KeyEventResult.handled;
              } else {
                return KeyEventResult.ignored;
              }
            },
          ),
          autofocus: isEditing,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.multiline,
          maxLines: 1,
          style: const TextStyle(fontSize: 16, height: 1.4),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
          onTapOutside: onTapOutside,
        ),
      );
    } else {
      return GestureDetector(
        onTap: () {
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
          onTap();
        },
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: MarkdownBody(
              data: controller.text,
              onTapLink: (text, href, title) => {
                // TODO: Handle link taps
                print('Link tapped: $text, $href, $title'),
              },
              // TODO: Make selection work
              selectable: false,
              onSelectionChanged: (text, selection, cause) {
                print('Selection changed: $selection');
                print(text);
                print(cause);
              },
              styleSheet: MarkdownStyleSheet.fromTheme(
                Theme.of(context),
              ).copyWith(p: const TextStyle(fontSize: 16, height: 1.4)),
            ),
          ),
        ),
      );
    }
  }
}
