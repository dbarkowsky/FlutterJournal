// Import tool: reads entries.csv and/or attachments.csv and imports them
// into the FlutterJournal SQLite database.
//
// Usage:
//   dart run tools/import_data.dart \
//     --db <path/to/journal.db> \
//     --password <password> \
//     [--entries <path/to/entries.csv>] \
//     [--attachments <path/to/attachments.csv>]
//
// CSV columns expected:
//   entries.csv     : entry_id, folder_id, date, created, modified, content
//   attachments.csv : attachment_id, created, mime_type, data
//
// - Entry content must be HTML; it will be converted to Markdown.
// - Attachment data must be base64-encoded binary.
// - Existing entries for a date are overwritten.
// - Attachments are always inserted as new rows; a mapping from old IDs to
//   new IDs is applied to any attachment references found in entry content.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart' show CsvDecoder;
import 'package:cryptography/cryptography.dart';
import 'package:encrypt/encrypt.dart';
import 'package:html2md/html2md.dart' as html2md;
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  final parsedArgs = _parseArgs(args);

  final dbPath = parsedArgs['db'];
  final password = parsedArgs['password'];
  final entriesCsv = parsedArgs['entries'];
  final attachmentsCsv = parsedArgs['attachments'];

  if (dbPath == null || password == null) {
    _die('Usage: dart run tools/import_data.dart '
        '--db <path> --password <pass> '
        '[--entries <csv>] [--attachments <csv>]');
  }
  if (entriesCsv == null && attachmentsCsv == null) {
    _die('Provide at least one of --entries or --attachments.');
  }

  // Open database
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(dbPath);
  print('Opened database: $dbPath');

  // Load encryption state
  final crypto = await _CryptoState.fromDatabase(db, password);
  print('Password verified.');

  // -- Phase 1: attachments (must come first so we can remap IDs in entries) --
  final Map<int, int> attachmentIdMap = {}; // old_id -> new_id

  if (attachmentsCsv != null) {
    await _importAttachments(
      csvPath: attachmentsCsv,
      db: db,
      crypto: crypto,
      idMap: attachmentIdMap,
    );
  }

  // -- Phase 2: entries --
  if (entriesCsv != null) {
    await _importEntries(
      csvPath: entriesCsv,
      db: db,
      crypto: crypto,
      attachmentIdMap: attachmentIdMap,
    );
  }

  await db.close();
  print('\nDone.');
}

// ---------------------------------------------------------------------------
// Image compression  (mirrors lib/helpers/image_tools.dart)
// ---------------------------------------------------------------------------

const int _maxImageDimension = 2048;
const int _jpegQuality = 85;

/// Resizes [bytes] so neither dimension exceeds [_maxImageDimension] and
/// re-encodes at [_jpegQuality]. PNG inputs stay PNG; everything else becomes
/// JPEG. Returns the original bytes if compression yields a larger result.
Uint8List _compressImageBytes(Uint8List bytes, String mimeType) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  img.Image resized = decoded;
  if (decoded.width > _maxImageDimension || decoded.height > _maxImageDimension) {
    resized = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: _maxImageDimension)
        : img.copyResize(decoded, height: _maxImageDimension);
  }

  final encoded = mimeType.toLowerCase() == 'image/png'
      ? img.encodePng(resized)
      : img.encodeJpg(resized, quality: _jpegQuality);

  final result = Uint8List.fromList(encoded);
  return result.length < bytes.length ? result : bytes;
}

// ---------------------------------------------------------------------------
// Attachment import
// ---------------------------------------------------------------------------

const _chunkSize = 100;

/// Ensures the attachments table has an `import_id` column (INTEGER, nullable,
/// unique). Safe to call on both new and existing databases.
Future<void> _ensureImportIdColumn(Database db) async {
  // PRAGMA table_info returns one row per column.
  final cols = await db.rawQuery('PRAGMA table_info(attachments)');
  final hasColumn = cols.any((c) => c['name'] == 'import_id');
  if (!hasColumn) {
    await db.execute(
      'ALTER TABLE attachments ADD COLUMN import_id INTEGER',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_attachments_import_id '
      'ON attachments (import_id) WHERE import_id IS NOT NULL',
    );
  }
}

Future<void> _importAttachments({
  required String csvPath,
  required Database db,
  required _CryptoState crypto,
  required Map<int, int> idMap,
}) async {
  final rows = _readCsv(csvPath);
  if (rows.isEmpty) {
    print('attachments.csv is empty, skipping.');
    return;
  }

  // Ensure the tracking column exists.
  await _ensureImportIdColumn(db);

  final header = rows.first.map((e) => e.toString().trim()).toList();
  final dataRows = rows.skip(1).toList();

  final colAttachmentId = _requireCol(header, 'attachment_id', csvPath);
  final colCreated = _requireCol(header, 'created', csvPath);
  final colMimeType = _requireCol(header, 'mime_type', csvPath);
  final colData = _requireCol(header, 'data', csvPath);

  print('\nPreparing ${dataRows.length} attachment(s)...');

  // Load old→new mappings from any previous run via the import_id column.
  final existingRows = await db.query(
    'attachments',
    columns: ['id', 'import_id'],
    where: 'import_id IS NOT NULL',
  );
  for (final row in existingRows) {
    final oldId = row['import_id'] as int?;
    final newId = row['id'] as int?;
    if (oldId != null && newId != null) idMap[oldId] = newId;
  }
  if (idMap.isNotEmpty) {
    print('  Resuming: ${idMap.length} attachment(s) already imported, skipping.');
  }

  // Pre-process: decode + encrypt everything in memory first.
  final prepared =
      <({int oldId, String createdAt, String mimeType, Uint8List encryptedData})>[];
  int skipped = 0;

  for (final row in dataRows) {
    if (row.length <= colData) { skipped++; continue; }
    final oldId = int.tryParse(row[colAttachmentId].toString().trim());
    if (oldId == null) { skipped++; continue; }

    // Already imported in a previous run — reuse the existing mapping.
    if (idMap.containsKey(oldId)) { skipped++; continue; }

    final createdAt = _normalizeDate(row[colCreated].toString().trim()) ??
        DateTime.now().toIso8601String();
    final mimeType = row[colMimeType].toString().trim();
    final rawData = row[colData].toString().trim();

    List<int> bytes;
    try {
      bytes = base64Decode(rawData);
    } catch (_) {
      print('  [WARN] attachment $oldId: data is not valid base64, skipping.');
      skipped++;
      continue;
    }

    // Compress images using the same settings as the main app.
    final processedBytes = mimeType.startsWith('image/')
        ? _compressImageBytes(Uint8List.fromList(bytes), mimeType)
        : Uint8List.fromList(bytes);

    prepared.add((
      oldId: oldId,
      createdAt: createdAt,
      mimeType: mimeType,
      encryptedData: crypto.encryptBytes(processedBytes),
    ));

    if (prepared.length % 50 == 0) {
      stdout.write('\r  Encrypting... ${prepared.length}/${dataRows.length}');
    }
  }
  stdout.writeln('\r  Encrypted ${prepared.length} attachments.          ');

  if (prepared.isEmpty) {
    print('Attachments: nothing new to insert, $skipped skipped.');
    return;
  }

  // Write in chunked transactions, storing import_id on each row so
  // subsequent runs can detect already-imported attachments.
  print('  Writing to database in chunks of $_chunkSize...');
  int ok = 0;

  for (var start = 0; start < prepared.length; start += _chunkSize) {
    final chunk = prepared.skip(start).take(_chunkSize).toList();
    await db.transaction((txn) async {
      for (final a in chunk) {
        final newId = await txn.insert('attachments', {
          'created_at': a.createdAt,
          'mime_type': a.mimeType,
          'data': a.encryptedData,
          'import_id': a.oldId,
        });
        idMap[a.oldId] = newId;
      }
    });
    ok += chunk.length;
    stdout.write('\r  Written $ok/${prepared.length}');
  }

  stdout.writeln();
  print('Attachments: $ok inserted, $skipped skipped.');
}

// ---------------------------------------------------------------------------
// Entry import
// ---------------------------------------------------------------------------

Future<void> _importEntries({
  required String csvPath,
  required Database db,
  required _CryptoState crypto,
  required Map<int, int> attachmentIdMap,
}) async {
  final rows = _readCsv(csvPath);
  if (rows.isEmpty) {
    print('entries.csv is empty, skipping.');
    return;
  }

  final header = rows.first.map((e) => e.toString().trim()).toList();
  final dataRows = rows.skip(1).toList();

  final colDate = _requireCol(header, 'date', csvPath);
  final colContent = _requireCol(header, 'content', csvPath);

  print('\nPreparing ${dataRows.length} entr(y/ies)...');

  // Pre-process: convert + encrypt everything in memory first.
  final prepared = <({String date, String encryptedContent, Set<int> attachmentIds})>[];
  int skipped = 0;

  for (final row in dataRows) {
    if (row.length <= colContent) { skipped++; continue; }

    final rawDate = row[colDate].toString().trim();
    final date = _extractDate(rawDate);
    if (date == null) {
      print('  [WARN] Could not parse date "$rawDate", skipping.');
      skipped++;
      continue;
    }

    final remappedHtml =
        _remapAttachmentIdsInHtml(row[colContent].toString(), attachmentIdMap);
    final markdown =
        _fixAttachmentScheme(_htmlToMarkdown(remappedHtml));
    final encrypted = crypto.encryptText(markdown);
    final attachmentIds = _extractAttachmentIds(markdown);

    prepared.add((
      date: date,
      encryptedContent: encrypted,
      attachmentIds: attachmentIds,
    ));

    if (prepared.length % 100 == 0) {
      stdout.write('\r  Converting... ${prepared.length}/${dataRows.length}');
    }
  }
  stdout.writeln('\r  Converted ${prepared.length} entries.          ');

  // Write in chunked transactions.
  print('  Writing to database in chunks of $_chunkSize...');
  int ok = 0;

  for (var start = 0; start < prepared.length; start += _chunkSize) {
    final chunk = prepared.skip(start).take(_chunkSize).toList();
    await db.transaction((txn) async {
      for (final e in chunk) {
        await txn.insert(
          'entries',
          {'date': e.date, 'content': e.encryptedContent},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.delete('entries_attachments',
            where: 'entry_date = ?', whereArgs: [e.date]);
        for (final id in e.attachmentIds) {
          await txn.insert(
            'entries_attachments',
            {'entry_date': e.date, 'attachment_id': id},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });
    ok += chunk.length;
    stdout.write('\r  Written $ok/${prepared.length}');
  }

  stdout.writeln();
  print('Entries: $ok upserted, $skipped skipped.');
}

// ---------------------------------------------------------------------------
// HTML -> Markdown
// ---------------------------------------------------------------------------

String _htmlToMarkdown(String html) {
  if (html.trim().isEmpty) return '';
  return html2md.convert(
    html,
    styleOptions: {
      'headingStyle': 'atx',
      'codeBlockStyle': 'fenced',
    },
    // Keep the attachment: scheme as-is; html2md treats it like any other URL.
    ignore: ['script', 'style'],
  ).trim();
}

/// Rewrites `attach://OLD_ID` occurrences inside HTML attribute values
/// (e.g. `src="attach://12"`) to use the new IDs from [idMap].
String _remapAttachmentIdsInHtml(String html, Map<int, int> idMap) {
  return html.replaceAllMapped(
    RegExp(r'attach://(\d+)'),
    (match) {
      final oldId = int.parse(match.group(1)!);
      final newId = idMap.isEmpty ? oldId : (idMap[oldId] ?? oldId);
      return 'attach://$newId';
    },
  );
}

/// After html2md converts `<img src="attach://ID">` to `![](attach://ID)`,
/// rewrite the scheme to the `attachment:ID` format the database expects.
String _fixAttachmentScheme(String markdown) {
  return markdown.replaceAllMapped(
    RegExp(r'attach://(\d+)'),
    (match) => 'attachment:${match.group(1)}',
  );
}

/// Extracts all `attachment:ID` references from Markdown content.
Set<int> _extractAttachmentIds(String content) {
  return RegExp(r'attachment:(\d+)', caseSensitive: false)
      .allMatches(content)
      .map((m) => int.tryParse(m.group(1) ?? ''))
      .whereType<int>()
      .toSet();
}

// ---------------------------------------------------------------------------
// Date helpers
// ---------------------------------------------------------------------------

/// Returns a yyyy-MM-dd string, or null if unparseable.
String? _extractDate(String raw) {
  if (raw.isEmpty) return null;

  // Already yyyy-MM-dd (possibly with time)
  final isoMatch = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(raw);
  if (isoMatch != null) return isoMatch.group(1);

  // MM/DD/YYYY or M/D/YYYY
  final usMatch = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(raw);
  if (usMatch != null) {
    final m = usMatch.group(1)!.padLeft(2, '0');
    final d = usMatch.group(2)!.padLeft(2, '0');
    final y = usMatch.group(3)!;
    return '$y-$m-$d';
  }

  // DD.MM.YYYY
  final euMatch = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(raw);
  if (euMatch != null) {
    final d = euMatch.group(1)!.padLeft(2, '0');
    final m = euMatch.group(2)!.padLeft(2, '0');
    final y = euMatch.group(3)!;
    return '$y-$m-$d';
  }

  // Try DateTime.parse as a last resort
  try {
    final dt = DateTime.parse(raw);
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  } catch (_) {}

  return null;
}

/// Best-effort: returns the raw string if it's an ISO datetime, otherwise null.
String? _normalizeDate(String raw) {
  if (raw.isEmpty) return null;
  try {
    return DateTime.parse(raw).toIso8601String();
  } catch (_) {
    return raw;
  }
}

// ---------------------------------------------------------------------------
// CSV helper
// ---------------------------------------------------------------------------

List<List<dynamic>> _readCsv(String path) {
  final file = File(path);
  if (!file.existsSync()) _die('File not found: $path');
  final content = file.readAsStringSync();
  return const CsvDecoder(dynamicTyping: false).convert(content);
}

int _requireCol(List<String> header, String name, String csvPath) {
  final idx = header.indexWhere(
      (h) => h.toLowerCase() == name.toLowerCase());
  if (idx == -1) _die('Column "$name" not found in $csvPath.\nHeaders: $header');
  return idx;
}

// ---------------------------------------------------------------------------
// Crypto
// ---------------------------------------------------------------------------

class _CryptoState {
  final Encrypter _encrypter;
  final IV _iv;

  _CryptoState._(this._encrypter, this._iv);

  static Future<_CryptoState> fromDatabase(Database db, String password) async {
    String getMeta(List<Map<String, dynamic>> rows, String key) {
      if (rows.isEmpty) throw Exception('Missing metadata key: $key');
      return rows.first['value'] as String;
    }

    final saltRow = await db.query('metadata',
        where: 'key = ?', whereArgs: ['salt']);
    final salt = base64Decode(getMeta(saltRow, 'salt'));

    final ivRow = await db.query('metadata',
        where: 'key = ?', whereArgs: ['iv']);
    final iv = IV.fromBase64(getMeta(ivRow, 'iv'));

    final keyBytes = await _deriveKey(password, salt);
    final encrypter = Encrypter(AES(Key(keyBytes)));

    // Validate marker
    final markerRow = await db.query('metadata',
        where: 'key = ?', whereArgs: ['marker']);
    final storedMarker = getMeta(markerRow, 'marker');
    try {
      final parts = storedMarker.split(':');
      final decrypted = encrypter.decrypt(
          Encrypted.fromBase64(parts[1]), iv: iv);
      if (decrypted != 'verified') {
        throw Exception('Marker mismatch – wrong password?');
      }
    } catch (e) {
      throw Exception('Invalid password (decryption failed): $e');
    }

    return _CryptoState._(encrypter, iv);
  }

  /// Encrypts a text entry. Returns bare base64 (matching JournalDB.upsertEntry).
  String encryptText(String plaintext) =>
      _encrypter.encrypt(plaintext, iv: _iv).base64;

  /// Encrypts raw bytes for attachment storage.
  Uint8List encryptBytes(List<int> data) =>
      _encrypter.encryptBytes(Uint8List.fromList(data), iv: _iv).bytes;

  static Future<Uint8List> _deriveKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return Uint8List.fromList(await secretKey.extractBytes());
  }
}

// ---------------------------------------------------------------------------
// Arg parsing / utils
// ---------------------------------------------------------------------------

Map<String, String?> _parseArgs(List<String> args) {
  final result = <String, String?>{};
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i].startsWith('--')) {
      result[args[i].substring(2)] = args[i + 1];
      i++; // consume value
    }
  }
  return result;
}

Never _die(String message) {
  stderr.writeln('Error: $message');
  exit(1);
}
