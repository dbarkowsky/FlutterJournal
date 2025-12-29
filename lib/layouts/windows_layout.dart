import 'package:flutter/material.dart';
import 'package:journal/providers/editor_provider.dart';
import 'package:journal/widgets/markdown_editor/editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class WindowsLayout extends ConsumerWidget {
  const WindowsLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorProvider);
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 300,
            child: Column(
              children: [
                CalendarDatePicker(
                  initialDate: editorState.date,
                  firstDate: DateTime(1970),
                  lastDate: DateTime(DateTime.now().year + 5),
                  onDateChanged: (date) {
                    ref.read(editorProvider.notifier).setDate(date);
                  },
                ),
                const Spacer(),
                const Text('controls'),
              ],
            ),
          ),
          Expanded(
            child: MarkdownEditor(),
          ),
        ],
      ),
    );
  }
}
