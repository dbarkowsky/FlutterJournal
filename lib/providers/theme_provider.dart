import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/providers/db_provider.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Whenever the DB becomes available, load the persisted theme.
    final dbAsync = ref.watch(dbProvider);
    dbAsync.whenData((db) => _loadTheme(db));
    return ThemeMode.system;
  }

  Future<void> _loadTheme(dynamic db) async {
    final stored = await db.getThemeMode() as String;
    state = _fromString(stored);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final db = ref.read(dbProvider).asData?.value;
    if (db != null) {
      await db.setThemeMode(_toString(mode));
    }
  }

  ThemeMode _fromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
