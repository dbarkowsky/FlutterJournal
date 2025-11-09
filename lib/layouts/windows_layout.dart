import 'package:flutter/material.dart';

import '../widgets/markdown_editor/markdown_block.dart';


class WindowsLayout extends StatelessWidget {
  const WindowsLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final textController = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: Text("Flutter Journal")),
      body: Row(
        children: [
          Container(
            width: 300,
            child: Column(
              children: [
              CalendarDatePicker(initialDate: DateTime.now(), firstDate: DateTime(1970), lastDate: DateTime(DateTime.now().year + 5), onDateChanged: (date){print(date);}),
              Spacer(),
              Text('controls'),
            ],),
          ),
          Expanded(child: MarkdownBlock(initialText: '# Hello World', onChanged: (text){}, onSubmittedLine: (){}, onBackspaceEmpty: (){})),
          // Expanded(child: TextField(controller: textController, expands: true, minLines: null, maxLines: null,))
        ],
      ),
    );
  }
}
