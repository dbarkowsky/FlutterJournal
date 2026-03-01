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

  Future<void> createNewDatabase(String password, {String? dbPath}) async {
    if (_initialized) return;

    sqfliteFfiInit();
    final dbFactory = databaseFactoryFfi;

    String resolvedDbPath = dbPath ?? '';
    if (resolvedDbPath.isEmpty) {
      final io.Directory dir = await getApplicationDocumentsDirectory();
      resolvedDbPath = p.join(dir.path, 'databases', 'journal.db');
    }

    _db = await dbFactory.openDatabase(resolvedDbPath);

    // New database: create tables and metadata
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS entries (
        date TEXT PRIMARY KEY,
        content TEXT
      )
    ''');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        data BLOB NOT NULL
      )
    ''');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS entries_attachments (
        entry_date TEXT NOT NULL,
        attachment_id INTEGER NOT NULL,
        PRIMARY KEY (entry_date, attachment_id),
        FOREIGN KEY (entry_date) REFERENCES entries(date) ON DELETE CASCADE,
        FOREIGN KEY (attachment_id) REFERENCES attachments(id) ON DELETE CASCADE
      )
    ''');

    // Generate salt and IV
    final salt = _generateSalt();
    await _db.insert('metadata', {
      'key': 'salt',
      'value': base64Encode(salt),
    });
    _iv = IV.fromSecureRandom(16);
    await _db.insert('metadata', {'key': 'iv', 'value': _iv.base64});

    // Derive AES key
    final keyBytes = await _deriveKey(password, salt);
    final key = Key(keyBytes);
    _encrypter = Encrypter(AES(key));

    // Store encrypted marker
    final encryptedMarker = _encryptValue('verified');
    await _db.insert('metadata', {
      'key': 'marker',
      'value': encryptedMarker,
    });

    // Mark attachments as already encrypted (new DB has no plaintext blobs)
    await _db.insert('metadata', {
      'key': 'attachments_encrypted_v1',
      'value': '1',
    });

    _initialized = true;
  }

  Future<void> openExistingDatabase(String password, {String? dbPath}) async {
    if (_initialized) return;

    sqfliteFfiInit();
    final dbFactory = databaseFactoryFfi;

    String resolvedDbPath = dbPath ?? '';
    if (resolvedDbPath.isEmpty) {
      final io.Directory dir = await getApplicationDocumentsDirectory();
      resolvedDbPath = p.join(dir.path, 'databases', 'journal.db');
    }

    _db = await dbFactory.openDatabase(resolvedDbPath);


    // Get salt
    final saltRow = await _db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: ['salt'],
    );
    if (saltRow.isEmpty) throw Exception('Corrupt database: missing salt');
    final salt = base64Decode(saltRow.first['value'] as String);

    // Derive AES key
    final keyBytes = await _deriveKey(password, salt);
    final key = Key(keyBytes);

    // Get IV
    final ivRow = await _db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: ['iv'],
    );
    if (ivRow.isEmpty) throw Exception('Corrupt database: missing IV');
    _iv = IV.fromBase64(ivRow.first['value'] as String);

    _encrypter = Encrypter(AES(key));

    // Validate marker
    final markerRow = await _db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: ['marker'],
    );
    if (markerRow.isEmpty) throw Exception('Corrupt database: missing marker');
    final encryptedMarker = markerRow.first['value'] as String;
    try {
      final decryptedMarker = _decryptValue(encryptedMarker);
      if (decryptedMarker != 'verified') {
        throw Exception('Invalid password (marker mismatch)');
      } else {
        _initialized = true;
      }
    } catch (e) {
      throw Exception('Invalid password (decryption failed)');
    }

    // Migrate unencrypted attachment blobs to encrypted, if not done yet
    await _migrateAttachmentsEncryption();
  }

  bool isInitialized(){
    return _initialized;
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

  // Encrypt binary data
  List<int> _encryptBytes(List<int> data) {
    final encrypted = _encrypter.encryptBytes(Uint8List.fromList(data), iv: _iv);
    return encrypted.bytes;
  }

  // Decrypt binary data
  Uint8List _decryptBytes(List<int> data) {
    return Uint8List.fromList(_encrypter.decryptBytes(Encrypted(Uint8List.fromList(data)), iv: _iv));
  }

  // One-time migration: encrypts any attachment blobs that were stored in plaintext
  Future<void> _migrateAttachmentsEncryption() async {
    final flagRow = await _db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: ['attachments_encrypted_v1'],
    );
    if (flagRow.isNotEmpty) return; // already migrated

    final rows = await _db.query('attachments');
    for (final row in rows) {
      final id = row['id'] as int;
      final raw = row['data'];
      final List<int> bytes;
      if (raw is Uint8List) {
        bytes = raw;
      } else if (raw is List) {
        bytes = raw.cast<int>();
      } else {
        continue;
      }
      await _db.update(
        'attachments',
        {'data': _encryptBytes(bytes)},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    await _db.insert('metadata', {
      'key': 'attachments_encrypted_v1',
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // Helper: extract attachment IDs from markdown (expects ![...](attachment:ID) or similar)
  Set<int> _extractAttachmentIds(String content) {
    final regex = RegExp(r'attachment:(\d+)', caseSensitive: false);
    return regex.allMatches(content).map((m) => int.tryParse(m.group(1) ?? '')).whereType<int>().toSet();
  }

  // Encrypt and insert or update an entry by date (yyyy-mm-dd), update relationship table
  Future<void> upsertEntry(String date, String content) async {
    if (!_initialized) throw Exception('Database not initialized');
    final encrypted = _encrypter.encrypt(content, iv: _iv).base64;
    await _db.insert('entries', {
      'date': date,
      'content': encrypted,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Update entries_attachments table
    final referencedIds = _extractAttachmentIds(content);
    // Remove all old links for this entry
    await _db.delete('entries_attachments', where: 'entry_date = ?', whereArgs: [date]);
    // Add new links
    for (final id in referencedIds) {
      await _db.insert('entries_attachments', {
        'entry_date': date,
        'attachment_id': id,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
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

  // Search for entries where decrypted content contains the query string (case-insensitive)
  Future<List<Map<String, dynamic>>> searchEntries(String query) async {
    if (!_initialized) throw Exception('Database not initialized');
    final rows = await _db.query('entries', orderBy: 'date DESC');
    final List<Map<String, dynamic>> results = [];
    final lowerQuery = query.toLowerCase();
    for (var r in rows) {
      final date = r['date'] as String;
      final encrypted = Encrypted.fromBase64(r['content'] as String);
      final content = _encrypter.decrypt(encrypted, iv: _iv);
      if (content.toLowerCase().contains(lowerQuery)) {
        results.add({'date': date, 'content': content});
      }
    }
    return results;
  }

  Future<void> removeEntry(String date) async {
    if (!_initialized) throw Exception('Database not initialized');
    // Remove from entries_attachments first (optional, ON DELETE CASCADE should handle it)
    await _db.delete('entries_attachments', where: 'entry_date = ?', whereArgs: [date]);
    await _db.delete('entries', where: 'date = ?', whereArgs: [date]);
  }

  // Insert a new attachment, returns the inserted row id
  Future<int> insertAttachment({
    required String mimeType,
    required List<int> data,
    String? createdAt,
  }) async {
    if (!_initialized) throw Exception('Database not initialized');
    final now = createdAt ?? DateTime.now().toIso8601String();
    return await _db.insert('attachments', {
      'created_at': now,
      'mime_type': mimeType,
      'data': _encryptBytes(data),
    });
  }

  // Delete an attachment by id
  Future<void> deleteAttachment(int id) async {
    if (!_initialized) throw Exception('Database not initialized');
    await _db.delete('attachments', where: 'id = ?', whereArgs: [id]);
  }

  /// Update an existing attachment's data and mime type by id
  Future<void> updateAttachment({
    required int id,
    required String mimeType,
    required List<int> data,
  }) async {
    if (!_initialized) throw Exception('Database not initialized');
    await _db.update(
      'attachments',
      {
        'mime_type': mimeType,
        'data': _encryptBytes(data),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Count how many entries reference this attachment
  Future<int> countEntriesReferencingAttachment(int attachmentId) async {
    if (!_initialized) throw Exception('Database not initialized');
    // If you have a join table, adjust the table/column names accordingly
    final result = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM entries_attachments WHERE attachment_id = ?
    ''', [attachmentId]);
    if (result.isNotEmpty && result.first.containsKey('count')) {
      final value = result.first['count'];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // Get attachment data by id
  Future<Map<String, dynamic>?> getAttachment(int id) async {
    if (!_initialized) throw Exception('Database not initialized');
    final rows = await _db.query('attachments', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final row = Map<String, dynamic>.from(rows.first);
    row['data'] = _decryptBytes((row['data'] as List).cast<int>());
    return row;
  }

  Future<List<Map<String, dynamic>>> getAllAttachments() async {
    if (!_initialized) throw Exception('Database not initialized');
    final rows = await _db.query('attachments');
    return rows.map((r) {
      final row = Map<String, dynamic>.from(r);
      row['data'] = _decryptBytes((row['data'] as List).cast<int>());
      return row;
    }).toList();
  }
}
