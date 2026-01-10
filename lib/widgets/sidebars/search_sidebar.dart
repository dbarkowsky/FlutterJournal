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

  Widget buildSnippet(
    String content,
    String query,
    BuildContext context, {
    int wordsAround = 4,
  }) {
    if (query.isEmpty || content.isEmpty) {
      return Text(content, maxLines: 2, overflow: TextOverflow.ellipsis);
    }

    final lowerContent = content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerContent.indexOf(lowerQuery);

    if (matchIndex == -1) {
      // No match, just show the start
      return Text(
        content.length > 40 ? '${content.substring(0, 40)}...' : content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Split content into words and find the word index of the match
    final wordRegExp = RegExp(r'\b\w+\b');
    final matches = wordRegExp.allMatches(content);
    int matchWordIdx = 0;

    for (final m in matches) {
      if (m.start <= matchIndex && m.end >= matchIndex) {
        break;
      }
      matchWordIdx++;
    }

    // Get the words around the match
    final words = matches.map((m) => content.substring(m.start, m.end)).toList();
    final startWord = (matchWordIdx - wordsAround).clamp(0, words.length - 1);
    final endWord = (matchWordIdx + wordsAround + 1).clamp(0, words.length);
    final snippetWords = words.sublist(startWord, endWord);

    // Reconstruct the snippet string
    final snippet = snippetWords.join(' ');

    // Find the match in the snippet (case-insensitive)
    final snippetLower = snippet.toLowerCase();
    final snippetMatchIndex = snippetLower.indexOf(lowerQuery);

    // Add ellipsis if not at start/end
    final prefix = startWord > 0 ? '... ' : '';
    final suffix = endWord < words.length ? ' ...' : '';

    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodySmall,
        children: [
          if (prefix.isNotEmpty) TextSpan(text: prefix),
          if (snippetMatchIndex > 0)
            TextSpan(text: snippet.substring(0, snippetMatchIndex)),
          TextSpan(
            text: snippet.substring(snippetMatchIndex, snippetMatchIndex + query.length),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (snippetMatchIndex + query.length < snippet.length)
            TextSpan(text: snippet.substring(snippetMatchIndex + query.length)),
          if (suffix.isNotEmpty) TextSpan(text: suffix),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
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
                    title: Text(entry['date']!, style: TextStyle(fontWeight: FontWeight.bold),),
                    subtitle: buildSnippet(
                      entry['content'] ?? '',
                      _controller.text,
                      context,
                    ),
                    onTap: () {
                      final String date = entry['date'];
                      ref
                          .read(editorProvider.notifier)
                          .setDate(DateTime.parse(date));
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
