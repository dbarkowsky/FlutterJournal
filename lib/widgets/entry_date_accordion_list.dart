import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/providers/db_provider.dart';
import 'package:intl/intl.dart';
import 'package:journal/providers/editor_provider.dart';

class EntryDateAccordionList extends ConsumerStatefulWidget {
  const EntryDateAccordionList({super.key});

  @override
  ConsumerState<EntryDateAccordionList> createState() => _EntryDateAccordionListState();
}

class _EntryDateAccordionListState extends ConsumerState<EntryDateAccordionList> {
  final Map<int, bool> _expandedYears = {};
  final Map<String, bool> _expandedMonths = {};

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(entriesProvider);
    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('DB Error: $e')),
      data: (entries) {
        final dates = entries.keys.toList();
        if (dates.isEmpty) {
          return const Center(child: Text('No entries'));
        }
        // Parse and group dates
        final Map<int, Map<int, List<int>>> grouped = {};
        for (final dateStr in dates) {
          final date = DateTime.parse(dateStr);
          grouped.putIfAbsent(date.year, () => {});
          grouped[date.year]!.putIfAbsent(date.month, () => []);
          grouped[date.year]![date.month]!.add(date.day);
        }
        final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
        return ListView(
          children: [
            ...years.map((year) {
              final months = grouped[year]!.keys.toList()..sort((a, b) => b.compareTo(a));
              return ExpansionPanelList(
                expansionCallback: (i, isOpen) {
                  setState(() {
                    _expandedYears[year] = !(_expandedYears[year] ?? false);
                  });
                },
                expandedHeaderPadding: EdgeInsets.zero,
                elevation: 1,
                children: [
                  ExpansionPanel(
                    headerBuilder: (context, isOpen) => ListTile(title: Text(year.toString())),
                    isExpanded: _expandedYears[year] ?? false,
                    canTapOnHeader: true,
                    body: Column(
                      children: [
                        ...months.map((month) {
                          final days = grouped[year]![month]!;
                          final monthKey = '$year-$month';
                          return ExpansionPanelList(
                            expansionCallback: (j, isOpen) {
                              setState(() {
                                _expandedMonths[monthKey] = !(_expandedMonths[monthKey] ?? false);
                              });
                            },
                            expandedHeaderPadding: EdgeInsets.zero,
                            elevation: 0,
                            children: [
                              ExpansionPanel(
                                headerBuilder: (context, isOpen) => ListTile(title: Text(DateFormat.MMMM().format(DateTime(year, month))),
                                contentPadding: const EdgeInsets.only(left: 25),),
                                isExpanded: _expandedMonths[monthKey] ?? false,
                                canTapOnHeader: true,
                                body: Column(
                                  children: [
                                    ...days.map((day) {
                                      final date = DateTime(year, month, day);
                                      return ListTile(
                                        title: Text(DateFormat('d - EEEE').format(date)),
                                        contentPadding: const EdgeInsets.only(left: 40),
                                        dense: true,
                                        onTap: () {
                                          // Set the date in the editorProvider
                                          ref.read(editorProvider.notifier).setDate(date);
                                        },
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}
