

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/sqlite/database.dart';

final dbProvider = AsyncNotifierProvider<DatabaseProvider, JournalDB>(DatabaseProvider.new);

class DatabaseProvider extends AsyncNotifier<JournalDB> {
  String? _password;
  String? _dbPath;

  @override
  Future<JournalDB> build() async {
    if (_password == null) throw Exception('No password provided');
    final db = JournalDB();
    await db.init(_password!, dbPath: _dbPath);
    return db;
  }

  Future<void> initWithPassword(String password, {String? dbPath}) async {
    _password = password;
    if (dbPath != null) {
      _dbPath = dbPath;
    }
    state = const AsyncValue.loading();
    try {
      final db = JournalDB();
      await db.init(password, dbPath: _dbPath);
      if (db.isInitialized()) {
        state = AsyncValue.data(db);
      } else {
        state = AsyncValue.error('Invalid password', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
