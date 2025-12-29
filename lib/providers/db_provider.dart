

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/sqlite/database.dart';

final dbProvider = NotifierProvider(DatabaseProvider.new);

class DatabaseProvider extends Notifier<JournalDB> {
  @override
  JournalDB build() {
        // Initialize your database here
    JournalDB db = JournalDB();
    db.init('temp_password').then((r) {
      db.upsertEntry('2025-11-16', 'oh hello');
    }); // TODO: Handle password input
    return db;
  }
}
