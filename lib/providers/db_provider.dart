

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/sqlite/database.dart';

final dbProvider = NotifierProvider(DatabaseProvider.new);

class DatabaseProvider extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() {
        // Initialize your database here
    JournalDB db = JournalDB();
    db.init('temp_password').then((r) {
      db.upsertEntry('2025-11-16', 'oh hello');
    }); // TODO: Handle password input
    // TODO: Remove later, just for testing
    
    // Store date as yyyy-mm-dd
    String currentDate = DateTime.now().toIso8601String().split('T').first;
    print(currentDate);
    return {'db': db, 'currentDate': currentDate};
  }
}
