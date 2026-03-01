
import 'package:flutter/material.dart';
import 'package:journal/widgets/calendar.dart';
import 'package:journal/widgets/entry_date_accordion_list.dart';

class EntryDateSidebar extends StatelessWidget {
  const EntryDateSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        return Column(
          children: [
            if (isLandscape) ...[
              const Expanded(child: SingleChildScrollView(child: Calendar())),
            ] else ...[
              const Calendar(),
              const SizedBox(height: 10),
              const Expanded(
                child: EntryDateAccordionList(),
              ),
            ],
          ],
        );
      },
    );
  }
}
