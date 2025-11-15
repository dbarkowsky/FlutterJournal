import 'package:flutter/material.dart';
import 'package:journal/widgets/markdown_editor/editor.dart';
import 'package:journal/widgets/markdown_editor/markdown_editor.dart';

class WindowsLayout extends StatelessWidget {
  const WindowsLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: Text("Flutter Journal")),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 300,
            child: Column(
              children: [
                CalendarDatePicker(
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1970),
                  lastDate: DateTime(DateTime.now().year + 5),
                  onDateChanged: (date) {
                    print(date);
                  },
                ),
                Spacer(),
                Text('controls'),
              ],
            ),
          ),
          Expanded(
            child: Editor(),
          ),
        ],
      ),
    );
  }
}
