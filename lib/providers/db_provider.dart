import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/sqlite/database.dart';

class EntriesNotifier extends Notifier<AsyncValue<Map<String, String>>> {
  late JournalDB db;

  @override
  AsyncValue<Map<String, String>> build() {
    final dbAsync = ref.watch(dbProvider);
    db = dbAsync.maybeWhen(
      data: (db) => db,
      orElse: () => JournalDB(),
    );
    _loadEntries();
    return const AsyncValue.loading();
  }

  Future<void> _loadEntries() async {
    try {
      final entries = await db.getAllEntries();
      state = AsyncValue.data(entries);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addOrUpdateEntry(String date, String content) async {
    await db.upsertEntry(date, content);
    await _loadEntries();
  }

  Future<void> removeEntry(String date) async {
    await db.removeEntry(date);
    await _loadEntries();
  }
}

final entriesProvider = NotifierProvider<EntriesNotifier, AsyncValue<Map<String, String>>>(EntriesNotifier.new);




final dbProvider = AsyncNotifierProvider<DatabaseProvider, JournalDB>(DatabaseProvider.new);

class DatabaseProvider extends AsyncNotifier<JournalDB> {
  String? _password;
  String? _dbPath;


  @override
  Future<JournalDB> build() async {
    // Guard: wait forever if no password is set, so provider never errors or completes.
    if (_password == null) {
      final completer = Completer<JournalDB>();
      return completer.future;
    }
    // Default: open existing database (for backward compatibility)
    final db = JournalDB();
    await db.openExistingDatabase(_password!, dbPath: _dbPath);
    return db;
  }

  Future<void> openDatabaseWithPassword(String password, {String? dbPath}) async {
    _password = password;
    if (dbPath != null) {
      _dbPath = dbPath;
    }
    state = const AsyncValue.loading();
    try {
      final db = JournalDB();
      await db.openExistingDatabase(password, dbPath: _dbPath);
      if (db.isInitialized()) {
        state = AsyncValue.data(db);
      } else {
        state = AsyncValue.error('Invalid password', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createDatabase(String password, {String? dbPath}) async {
    _password = password;
    if (dbPath != null) {
      _dbPath = dbPath;
    }
    state = const AsyncValue.loading();
    try {
      final db = JournalDB();
      await db.createNewDatabase(password, dbPath: _dbPath);
      if (db.isInitialized()) {
        state = AsyncValue.data(db);
      } else {
        state = AsyncValue.error('Database creation failed', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
