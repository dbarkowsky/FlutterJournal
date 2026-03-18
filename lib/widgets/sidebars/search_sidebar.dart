import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/providers/db_provider.dart';
import 'package:journal/providers/editor_provider.dart';

class SearchSidebar extends ConsumerStatefulWidget {
  const SearchSidebar({super.key});

  @override
  ConsumerState<SearchSidebar> createState() => _SearchSidebarState();
}

class _SearchSidebarState extends ConsumerState<SearchSidebar> {
  static const int _pageSize = 20;
  static const int _wordsAround = 4;

  final TextEditingController _controller = TextEditingController();
  /// Flat list of individual match occurrences, one item per match across all
  /// entries. Each map has: 'date' (String), 'content' (String), 'matchIndex' (int).
  List<Map<String, dynamic>> _matches = [];
  bool _loading = false;
  int _currentPage = 0;
  DateTime? _fromDate;
  DateTime? _toDate;
  final Duration _debounceDuration = const Duration(milliseconds: 200);
  Timer? _debounceTimer;

  void _onTextChanged(String query) {
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      _search(query);
      return;
    }
    _debounceTimer = Timer(_debounceDuration, () => _search(query));
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _matches = [];
        _currentPage = 0;
      });
      return;
    }
    setState(() => _loading = true);
    final entriesNotifier = ref.read(entriesProvider.notifier);
    // searchEntries returns one record per entry (date + decrypted content).
    final results = await entriesNotifier.searchEntries(query);
    // Expand each entry into one item per match occurrence, applying date filter.
    final flat = _expandToMatches(results, query);
    setState(() {
      _matches = flat;
      _loading = false;
      _currentPage = 0;
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = (isFrom ? _fromDate : _toDate) ?? DateTime.now();
    final first = DateTime(2000);
    final last = DateTime(2100);
    final clamped = initial.isBefore(first) ? first : initial.isAfter(last) ? last : initial;
    final picked = await showDatePicker(
      context: context,
      initialDate: clamped,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = null;
      } else {
        _toDate = picked;
        if (_fromDate != null && _fromDate!.isAfter(picked)) _fromDate = null;
      }
    });
    _onTextChanged(_controller.text);
  }

  /// Given a list of entry maps and a query, returns a flat list of match
  /// records – one per distinct (non-overlapping) occurrence of [query] inside
  /// each entry's content. Entries outside the [_fromDate]..[_toDate] window
  /// are skipped.
  List<Map<String, dynamic>> _expandToMatches(
    List<Map<String, dynamic>> entries,
    String query,
  ) {
    final lowerQuery = query.toLowerCase();
    final result = <Map<String, dynamic>>[];

    for (final entry in entries) {
      final content = entry['content'] as String? ?? '';
      final date = entry['date'] as String;

      // Date-range filter (compare as date-only by stripping time).
      final entryDate = DateTime.parse(date);
      final entryDay = DateTime(entryDate.year, entryDate.month, entryDate.day);
      if (_fromDate != null && entryDay.isBefore(_fromDate!)) continue;
      if (_toDate != null && entryDay.isAfter(_toDate!)) continue;

      final lowerContent = content.toLowerCase();

      int searchFrom = 0;
      while (true) {
        final idx = lowerContent.indexOf(lowerQuery, searchFrom);
        if (idx == -1) break;
        result.add({'date': date, 'content': content, 'matchIndex': idx});
        searchFrom = idx + lowerQuery.length;
      }
    }

    return result;
  }

  /// Builds a single snippet widget for the match at [matchIndex] inside [content].
  Widget buildSnippet(
    String content,
    String query,
    int matchIndex,
    BuildContext context,
  ) {
    final wordRegExp = RegExp(r'\b\w+\b');
    final wordMatches = wordRegExp.allMatches(content).toList();
    if (wordMatches.isEmpty) {
      return Text(content, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final words =
        wordMatches.map((m) => content.substring(m.start, m.end)).toList();

    // Find which word contains the match character position.
    int matchWordIdx = words.length - 1;
    for (int i = 0; i < wordMatches.length; i++) {
      if (wordMatches[i].start <= matchIndex &&
          wordMatches[i].end >= matchIndex) {
        matchWordIdx = i;
        break;
      }
      if (wordMatches[i].start > matchIndex) {
        matchWordIdx = (i - 1).clamp(0, wordMatches.length - 1);
        break;
      }
    }

    final startWord =
        (matchWordIdx - _wordsAround).clamp(0, words.length - 1);
    final endWord =
        (matchWordIdx + _wordsAround + 1).clamp(0, words.length);
    final snippet = words.sublist(startWord, endWord).join(' ');
    final snippetLower = snippet.toLowerCase();
    final snippetMatchIndex = snippetLower.indexOf(query.toLowerCase());
    final prefix = startWord > 0 ? '... ' : '';
    final suffix = endWord < words.length ? ' ...' : '';

    if (snippetMatchIndex == -1) {
      // Match spans a word boundary – show the snippet without highlighting.
      return RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            if (prefix.isNotEmpty) TextSpan(text: prefix),
            TextSpan(text: snippet),
            if (suffix.isNotEmpty) TextSpan(text: suffix),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final highlightEnd =
        (snippetMatchIndex + query.length).clamp(0, snippet.length);

    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodySmall,
        children: [
          if (prefix.isNotEmpty) TextSpan(text: prefix),
          if (snippetMatchIndex > 0)
            TextSpan(text: snippet.substring(0, snippetMatchIndex)),
          TextSpan(
            text: snippet.substring(snippetMatchIndex, highlightEnd),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (highlightEnd < snippet.length)
            TextSpan(text: snippet.substring(highlightEnd)),
          if (suffix.isNotEmpty) TextSpan(text: suffix),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  int get _totalPages => (_matches.length / _pageSize).ceil();

  List<Map<String, dynamic>> get _pageMatches {
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _matches.length);
    return _matches.sublist(start, end);
  }

  /// Groups the current page's flat match list by date, preserving order.
  /// Each element has: 'date' (String), 'content' (String),
  /// 'matchIndices' (`List<int>`).
  List<Map<String, dynamic>> get _groupedPageMatches {
    final grouped = <Map<String, dynamic>>[];
    for (final match in _pageMatches) {
      final date = match['date'] as String;
      if (grouped.isNotEmpty && grouped.last['date'] == date) {
        (grouped.last['matchIndices'] as List<int>).add(match['matchIndex'] as int);
      } else {
        grouped.add({
          'date': date,
          'content': match['content'],
          'matchIndices': <int>[match['matchIndex'] as int],
        });
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Search',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _onTextChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateChip(
                  label: 'From',
                  date: _fromDate,
                  onTap: () => _pickDate(isFrom: true),
                  onClear: _fromDate != null
                      ? () {
                          setState(() => _fromDate = null);
                          _onTextChanged(_controller.text);
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DateChip(
                  label: 'To',
                  date: _toDate,
                  onTap: () => _pickDate(isFrom: false),
                  onClear: _toDate != null
                      ? () {
                          setState(() => _toDate = null);
                          _onTextChanged(_controller.text);
                        }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading) const CircularProgressIndicator(),
          if (!_loading)
            Expanded(
              child: Column(
                children: [
                  if (_matches.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Text(
                        '${_matches.length} match${_matches.length == 1 ? '' : 'es'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _groupedPageMatches.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final group = _groupedPageMatches[index];
                        final date = group['date'] as String;
                        final content = group['content'] as String? ?? '';
                        final matchIndices = group['matchIndices'] as List<int>;
                        return InkWell(
                          onTap: () {
                            ref
                                .read(editorProvider.notifier)
                                .setDate(DateTime.parse(date));
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8.0,
                              horizontal: 4.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  date,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                ...matchIndices.map(
                                  (mi) => buildSnippet(
                                    content,
                                    _controller.text,
                                    mi,
                                    context,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_totalPages > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            tooltip: 'Previous page',
                            onPressed: _currentPage > 0
                                ? () => setState(() => _currentPage--)
                                : null,
                          ),
                          Text('${_currentPage + 1} / $_totalPages'),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            tooltip: 'Next page',
                            onPressed: _currentPage < _totalPages - 1
                                ? () => setState(() => _currentPage++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A compact chip-style button that shows a date label and an optional
/// clear (×) button when a date is selected.
class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    final display = hasDate
        ? '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}'
        : label;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasDate
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(20),
          color: hasDate
              ? Theme.of(context).colorScheme.primaryContainer.withAlpha(80)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                display,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: hasDate
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight:
                          hasDate ? FontWeight.w600 : FontWeight.normal,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasDate && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              Icon(
                Icons.calendar_today,
                size: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
