import 'package:flutter/material.dart';
import 'package:journal/helpers/formatters.dart';
import 'package:journal/providers/editor_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:journal/providers/db_provider.dart';

class Calendar extends StatelessWidget {
  const Calendar({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final dbAsync = ref.watch(dbProvider);
        return dbAsync.when(
          data: (db) {
            return FutureBuilder<Map<String, String>>(
              future: db.getAllEntries(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entryDates = snapshot.data!.keys.toSet();
                return TableCalendar(
                  headerStyle: HeaderStyle(titleCentered: true),
                  onHeaderTapped: (focusedDay) async {
                    final selected = await showMonthPicker(
                      context: context,
                      firstDate: DateTime(1970),
                      lastDate: DateTime(DateTime.now().year + 5),
                      initialDate: DateTime.tryParse(
                        ref.watch(editorProvider).date,
                      )!,
                    );
                    if (selected != null) {
                      ref.read(editorProvider.notifier).setDate(selected);
                    }
                  },
                  daysOfWeekHeight: 25,
                  firstDay: DateTime(1970),
                  lastDay: DateTime(DateTime.now().year + 5),
                  focusedDay: DateTime.tryParse(
                    ref.watch(editorProvider).date,
                  )!,
                  selectedDayPredicate: (day) {
                    DateTime d = DateTime.tryParse(
                      ref.watch(editorProvider).date,
                    )!;
                    return d.year == day.year &&
                        d.month == day.month &&
                        d.day == day.day;
                  },
                  rowHeight: 45,
                  rangeSelectionMode: RangeSelectionMode.disabled,
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month',
                  },
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      final hasEntry = entryDates.contains(
                        Formatters.date(day),
                      );
                      if (hasEntry) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.lightBlueAccent.withAlpha(70),
                            shape: BoxShape.rectangle,
                          ),
                          child: Center(child: Text('${day.day}')),
                        );
                      }
                      return null;
                    },
                    todayBuilder: (context, day, focusedDay) {
                      final hasEntry = entryDates.contains(
                        Formatters.date(day),
                      );
                      if (hasEntry){
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.lightBlueAccent.withAlpha(70),
                            border: Border.all(color: Colors.black),
                            shape: BoxShape.rectangle,
                          ),
                          child: Center(child: Text('${day.day}')),
                        );
                      }
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black),
                          shape: BoxShape.rectangle,
                        ),
                        child: Center(child: Text('${day.day}')),
                      );
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      return Container(
                        decoration: BoxDecoration(color: Colors.blueAccent),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    ref.read(editorProvider.notifier).setDate(selectedDay);
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error loading entries')),
        );
      },
    );
  }
}
