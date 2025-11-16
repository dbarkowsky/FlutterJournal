import 'package:flutter/material.dart';
import 'package:journal/providers/db_provider.dart';
import 'package:journal/sqlite/database.dart';
import 'package:journal/widgets/markdown_editor/editor.dart';
import 'package:journal/widgets/markdown_editor/markdown_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class WindowsLayout extends ConsumerWidget {
  const WindowsLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.read(dbProvider);
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
                  onDateChanged: (date) async {
                    // TODO: Should we save here first?
                    String newDate = date.toIso8601String().split('T').first;
                    provider['currentDate'] = newDate;
                    print("new date: ${provider['currentDate']}");
                    // If new date has an entry, load it
                    JournalDB db = provider['db'];
                    String? entryText = await db.getEntry(newDate);
                    if (entryText != null) {
                      // Load entryText into editor
                      print("Loaded entry for $newDate: $entryText");
                    } else {
                      print("No entry for $newDate");
                    }
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
