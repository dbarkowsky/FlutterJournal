import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:encrypt/encrypt.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class JournalDB {
  static final JournalDB _instance = JournalDB._internal();
  factory JournalDB() => _instance;
  JournalDB._internal();

  late Database _db;
  late Encrypter _encrypter;
  late IV _iv;
  bool _initialized = false;

  Future<void> init(String password) async {
    if (_initialized) return;

    sqfliteFfiInit();
    final dbFactory = databaseFactoryFfi;

    final io.Directory dir = await getApplicationDocumentsDirectory();
    final String dbPath = p.join(dir.path, 'databases', 'journal.db');
    await dbFactory.openDatabase(dbPath).then((db) async {
      _db = db;

      // Ensure metadata table exists
      await _db.execute('''
        CREATE TABLE IF NOT EXISTS metadata (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');

      // Get or generate salt
      Uint8List salt;
      final saltRow = await _db.query(
        'metadata',
        where: 'key = ?',
        whereArgs: ['salt'],
      );
      if (saltRow.isEmpty) {
        salt = _generateSalt();
        await _db.insert('metadata', {
          'key': 'salt',
          'value': base64Encode(salt),
        });
      } else {
        salt = base64Decode(saltRow.first['value'] as String);
      }

      // Derive AES key from password + salt
      final keyBytes = await _deriveKey(password, salt);
      final key = Key(keyBytes);
      
      final ivRow = await _db.query(
        'metadata',
        where: 'key = ?',
        whereArgs: ['iv'],
      );
      if (ivRow.isEmpty) {
        _iv = IV.fromSecureRandom(16); // Generate a random IV
        await _db.insert('metadata', {
          'key': 'iv',
          'value': _iv.base64,
        });
      } else {
        _iv = IV.fromBase64(ivRow.first['value'] as String);
      }

      _encrypter = Encrypter(AES(key));

      // Create table for encrypted entries
      await _db.execute('''
        CREATE TABLE IF NOT EXISTS entries (
          date TEXT PRIMARY KEY,
          content TEXT
        )
      ''');

      // This marker determines if the correct password was given
      final markerRow = await _db.query(
        'metadata',
        where: 'key = ?',
        whereArgs: ['marker'],
      );

      if (markerRow.isEmpty) {
        // First-time setup: store encrypted marker
        final encryptedMarker = _encryptValue('verified');
        await _db.insert('metadata', {
          'key': 'marker',
          'value': encryptedMarker,
        });
      } else {
        // Try to decrypt marker to validate password
        final encryptedMarker = markerRow.first['value'] as String;
        try {
          final decryptedMarker = _decryptValue(encryptedMarker);
          if (decryptedMarker != 'verified') {
            throw Exception('Invalid password (marker mismatch)');
          }
        } catch (e) {
          throw Exception('Invalid password (decryption failed)');
        }
      }

      _initialized = true;
    });
  }

  // Derive a 256-bit AES key from a password and salt
  Future<Uint8List> _deriveKey(String password, Uint8List salt) async {
    const iterations = 100000; // high = more secure, slower
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );

    // Derive the key
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    // Convert to bytes for encrypt package
    final keyBytes = await secretKey.extractBytes();
    return Uint8List.fromList(keyBytes);
  }

  // Generate a random salt
  Uint8List _generateSalt([int length = 16]) {
    final rand = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rand.nextInt(256)),
    );
  }

  // Encrypt a value
  String _encryptValue(String value) {
    final encrypted = _encrypter.encrypt(value, iv: _iv);
    return '${_iv.base64}:${encrypted.base64}';
  }

  // Decrypt a value
  String _decryptValue(String stored) {
    final parts = stored.split(':');
    final encrypted = Encrypted.fromBase64(parts[1]);
    return _encrypter.decrypt(encrypted, iv: _iv);
  }

  // Encrypt and insert or update an entry by date (yyyy-mm-dd)
  Future<void> upsertEntry(String date, String content) async {
    if (!_initialized) throw Exception('Database not initialized');
    final encrypted = _encrypter.encrypt(content, iv: _iv).base64;
    await _db.insert('entries', {
      'date': date,
      'content': encrypted,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Decrypt and return entry for a specific date
  Future<String?> getEntry(String date) async {
    if (!_initialized) throw Exception('Database not initialized');
    final rows = await _db.query(
      'entries',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (rows.isEmpty) return null;
    final encrypted = Encrypted.fromBase64(rows.first['content'] as String);
    return _encrypter.decrypt(encrypted, iv: _iv);
  }

  // Get all entries, decrypted and sorted by date descending
  Future<Map<String, String>> getAllEntries() async {
    if (!_initialized) throw Exception('Database not initialized');
    final rows = await _db.query('entries', orderBy: 'date ASC');
    final result = <String, String>{};
    for (var r in rows) {
      final encrypted = Encrypted.fromBase64(r['content'] as String);
      result[r['date'] as String] = _encrypter.decrypt(encrypted, iv: _iv);
    }
    return result;
  }

  Future<void> removeEntry(String date) async {
    if (!_initialized) throw Exception('Database not initialized');
    await _db.delete('entries', where: 'date = ?', whereArgs: [date]);
  }
}
