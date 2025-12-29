

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/sqlite/database.dart';

final dbProvider = AsyncNotifierProvider<DatabaseProvider, JournalDB>(DatabaseProvider.new);

class DatabaseProvider extends AsyncNotifier<JournalDB> {
  @override
  Future<JournalDB> build() async {
    final db = JournalDB();
    await db.init('temp_password');
    // Optionally add a test entry
    // await db.upsertEntry('2025-11-16', 'oh hello');
    return db;
  }
}
