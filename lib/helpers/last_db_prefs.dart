import 'package:shared_preferences/shared_preferences.dart';

class LastDatabasePrefs {
  static const _key = 'last_db_path';

  static Future<void> savePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }

  static Future<String?> loadPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }
}
