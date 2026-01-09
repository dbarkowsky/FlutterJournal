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
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
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
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    final entriesNotifier = ref.read(entriesProvider.notifier);
    final results = await entriesNotifier.searchEntries(query);
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  void dispose() {
  _debounceTimer?.cancel();
  _controller.dispose();
  super.dispose();
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
          const SizedBox(height: 12),
          if (_loading) const CircularProgressIndicator(),
          if (!_loading)
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final entry = _results[index];
                  return ListTile(
                    title: Text(entry['date']!),
                    subtitle: Text(entry['content'] ?? ''),
                    onTap: () {
                      final String date = entry['date'];
                      ref.read(editorProvider.notifier).setDate(DateTime.parse(date));
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
