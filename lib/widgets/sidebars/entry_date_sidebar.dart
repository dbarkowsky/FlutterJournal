
import 'package:flutter/material.dart';
import 'package:journal/providers/editor_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/widgets/entry_date_accordion_list.dart';

class EntryDateSidebar extends StatelessWidget {
  const EntryDateSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Column(
        children: [
          Consumer(
            builder: (context, ref, _) {
              return CalendarDatePicker(
                initialDate: DateTime.now(),
                firstDate: DateTime(1970),
                lastDate: DateTime(DateTime.now().year + 5),
                onDateChanged: (date) {
                  ref.read(editorProvider.notifier).setDate(date);
                },
              );
            },
          ),
          const Expanded(
            child: EntryDateAccordionList(),
          ),
          const Text('controls'),
        ],
      ),
    );
  }
}
