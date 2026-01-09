

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/sqlite/database.dart';
import 'dart:async';

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
