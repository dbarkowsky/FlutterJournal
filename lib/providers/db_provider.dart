

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/sqlite/database.dart';

final dbProvider = AsyncNotifierProvider<DatabaseProvider, JournalDB>(DatabaseProvider.new);

class DatabaseProvider extends AsyncNotifier<JournalDB> {
  String? _password;

  @override
  Future<JournalDB> build() async {
    if (_password == null) throw Exception('No password provided');
    final db = JournalDB();
    await db.init(_password!);
    return db;
  }

  Future<void> initWithPassword(String password) async {
    _password = password;
    state = const AsyncValue.loading();
    try {
      final db = JournalDB();
      await db.init(password);
      if (db.isInitialized()) {
        print('initialized');
        state = AsyncValue.data(db);
      } else {
        print('not initialized');
        state = AsyncValue.error('Invalid password', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
