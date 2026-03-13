import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/providers/db_provider.dart';
import 'package:intl/intl.dart';
import 'package:journal/providers/editor_provider.dart';

// Derived provider: groups entry dates into year > month > [days].
// Recomputes only when the entries map itself changes, not on UI rebuilds.
final _groupedEntriesProvider = Provider<Map<int, Map<int, List<int>>>>((ref) {
  final entries = ref.watch(entriesProvider).asData?.value ?? {};
  final Map<int, Map<int, List<int>>> grouped = {};
  for (final dateStr in entries.keys) {
    final date = DateTime.parse(dateStr);
    grouped.putIfAbsent(date.year, () => {});
    grouped[date.year]!.putIfAbsent(date.month, () => []);
    grouped[date.year]![date.month]!.add(date.day);
  }
  return grouped;
});

class EntryDateAccordionList extends ConsumerWidget {
  const EntryDateAccordionList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(entriesProvider);
    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('DB Error: $e')),
      data: (_) {
        final grouped = ref.watch(_groupedEntriesProvider);
        if (grouped.isEmpty) {
          return const Center(child: Text('No entries'));
        }
        final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
        // ListView.builder virtualizes the year list so only visible items
        // are built, and each year is an independent subtree.
        return ListView.builder(
          itemCount: years.length,
          itemBuilder: (context, index) {
            final year = years[index];
            return _YearTile(year: year, monthMap: grouped[year]!);
          },
        );
      },
    );
  }
}

// ── Year tile ────────────────────────────────────────────────────────────────

class _YearTile extends StatelessWidget {
  final int year;
  final Map<int, List<int>> monthMap;

  const _YearTile({required this.year, required this.monthMap});

  @override
  Widget build(BuildContext context) {
    final months = monthMap.keys.toList()..sort((a, b) => a.compareTo(b));
    return ExpansionTile(
      // Each ExpansionTile manages its own expanded state — no setState needed.
      title: Text(year.toString()),
      children: [
        for (final month in months)
          _MonthTile(year: year, month: month, days: monthMap[month]!),
      ],
    );
  }
}

// ── Month tile ───────────────────────────────────────────────────────────────

class _MonthTile extends ConsumerWidget {
  final int year;
  final int month;
  final List<int> days;

  const _MonthTile({
    required this.year,
    required this.month,
    required this.days,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortedDays = [...days]..sort((a, b) => a.compareTo(b));
    return ExpansionTile(
      title: Text(DateFormat.MMMM().format(DateTime(year, month))),
      tilePadding: const EdgeInsets.only(left: 25),
      children: [
        for (final day in sortedDays)
          _DayTile(year: year, month: month, day: day),
      ],
    );
  }
}

// ── Day tile ─────────────────────────────────────────────────────────────────

class _DayTile extends ConsumerWidget {
  final int year;
  final int month;
  final int day;

  const _DayTile({required this.year, required this.month, required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateTime(year, month, day);
    return ListTile(
      title: Text(DateFormat('d - EEEE').format(date)),
      contentPadding: const EdgeInsets.only(left: 40),
      dense: true,
      onTap: () => ref.read(editorProvider.notifier).setDate(date),
    );
  }
}
