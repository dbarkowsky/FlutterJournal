import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/sqlite/database.dart';

// Use this provider when you need to access the entries.
// It will cause consumers using it to reload when the entries change.
class EntriesNotifier extends Notifier<AsyncValue<Map<String, String>>> {
  late JournalDB db;

  @override
  AsyncValue<Map<String, String>> build() {
    final dbAsync = ref.watch(dbProvider);
    return dbAsync.when(
      data: (openedDb) {
        db = openedDb;
        _loadEntries();
        return const AsyncValue.loading();
      },
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
    );
  }

  Future<void> _loadEntries() async {
    try {
      final entries = await db.getAllEntries();
      state = AsyncValue.data(entries);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String> getEntryContent(String date) async {
    final content = await db.getEntry(date);
    if (content == null){
      return '';
    }
    return content;
  }

  Future<void> addOrUpdateEntry(String date, String content) async {
    await db.upsertEntry(date, content);
    await _loadEntries();
  }

  Future<void> removeEntry(String date) async {
    await db.removeEntry(date);
    await _loadEntries();
  }

  Future<List<Map<String, dynamic>>> searchEntries(String query) async {
    final entries = await db.searchEntries(query);
    return entries;
  }
}

// Use this provider to init and access the database as a whole.
// It will not refresh the UI when values inside the database change.
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

  /// Clears credentials and closes the DB. build() will then wait forever
  /// (password guard), preventing an automatic re-login.
  Future<void> logout() async {
    final db = state.asData?.value;
    _password = null;
    _dbPath = null;
    if (db != null) await db.close();
    // Set to a never-resolving loading state rather than invalidating,
    // so build() is not called again (which would re-open the DB).
    state = AsyncValue.loading();
  }
}

final entriesProvider = NotifierProvider<EntriesNotifier, AsyncValue<Map<String, String>>>(EntriesNotifier.new);

final dbProvider = AsyncNotifierProvider<DatabaseProvider, JournalDB>(DatabaseProvider.new);
