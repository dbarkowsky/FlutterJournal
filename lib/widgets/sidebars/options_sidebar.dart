import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/providers/db_provider.dart';
import 'package:journal/providers/theme_provider.dart';
import 'package:journal/widgets/password_page.dart';
import 'package:path/path.dart' as p;

class OptionsSidebar extends ConsumerStatefulWidget {
  const OptionsSidebar({super.key});

  @override
  ConsumerState<OptionsSidebar> createState() => _OptionsSidebarState();
}

class _OptionsSidebarState extends ConsumerState<OptionsSidebar> {
  // Password change form state
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _changingPassword = false;
  String? _passwordError;
  String? _passwordSuccess;

  // Export state
  bool _exporting = false;
  String? _exportError;
  String? _exportSuccess;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _changingPassword = true;
      _passwordError = null;
      _passwordSuccess = null;
    });
    try {
      final db = ref.read(dbProvider).asData?.value;
      if (db == null) throw Exception('Database not available');
      await db.changePassword(_newPasswordController.text);
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _passwordSuccess = 'Password changed successfully.');
    } catch (e) {
      setState(() => _passwordError = e.toString());
    } finally {
      setState(() => _changingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // ── Appearance ──────────────────────────────────────────────────────
        Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode),
              label: Text('Light', style: TextStyle(fontSize: 12)),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto),
              label: Text('Auto', style: TextStyle(fontSize: 12)),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode),
              label: Text('Dark', style: TextStyle(fontSize: 12)),
            ),
          ],
          selected: {themeMode},
          onSelectionChanged: (selected) {
            ref.read(themeModeProvider.notifier).setThemeMode(selected.first);
          },
        ),

        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 12),

        // ── Change Password ─────────────────────────────────────────────────
        Text('Change Password', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'All entries and attachments will be re-encrypted with the new password.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),

        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // New password
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a new password';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Confirm password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Error / success messages
              if (_passwordError != null) ...[
                Text(
                  _passwordError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (_passwordSuccess != null) ...[
                Text(
                  _passwordSuccess!,
                  style: const TextStyle(color: Colors.green, fontSize: 13),
                ),
                const SizedBox(height: 8),
              ],

              FilledButton.icon(
                onPressed: _changingPassword ? null : _changePassword,
                icon: _changingPassword
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_reset),
                label: const Text('Change Password'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 12),

        // ── Export Data ─────────────────────────────────────────────────────
        Text('Export Data', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Save all journal entries as unencrypted Markdown files (.md) to a folder you choose.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),

        // Error / success messages
        if (_exportError != null) ...[
          Text(
            _exportError!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_exportSuccess != null) ...[
          Text(
            _exportSuccess!,
            style: const TextStyle(color: Colors.green, fontSize: 13),
          ),
          const SizedBox(height: 8),
        ],

        OutlinedButton.icon(
          onPressed: _exporting ? null : _exportData,
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_download_outlined),
          label: const Text('Export to Files'),
        ),

        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 12),

        // ── Close Journal ───────────────────────────────────────────────────
        Text('Close Journal', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Lock the journal and return to the password screen.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _closeJournal,
          icon: const Icon(Icons.logout),
          label: const Text('Close Journal'),
        ),
      ],
    );
  }

  Future<void> _exportData() async {
    setState(() {
      _exporting = true;
      _exportError = null;
      _exportSuccess = null;
    });
    try {
      final outputDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose export folder',
      );
      if (outputDir == null) {
        setState(() => _exporting = false);
        return;
      }

      final db = ref.read(dbProvider).asData?.value;
      if (db == null) throw Exception('Database not available');

      // ── Export entries ───────────────────────────────────────────────────
      final entries = await db.getAllEntries();
      for (final entry in entries.entries) {
        final date = entry.key;
        final content = entry.value;
        final file = File(p.join(outputDir, '$date.md'));
        await file.writeAsString('# $date\n\n$content\n', flush: true);
      }

      // ── Export attachments ───────────────────────────────────────────────
      final attachments = await db.getAllAttachments();
      int exportedAttachments = 0;
      if (attachments.isNotEmpty) {
        final attachDir = Directory(p.join(outputDir, 'attachments'));
        await attachDir.create(recursive: true);
        for (final att in attachments) {
          final id = att['id'] as int;
          final mimeType = att['mime_type'] as String;
          final data = att['data'] as List<int>;
          final ext = _extensionFromMime(mimeType);
          final file = File(p.join(attachDir.path, '$id$ext'));
          await file.writeAsBytes(data, flush: true);
          exportedAttachments++;
        }
      }

      final entriesLabel =
          '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}';
      final attachLabel = attachments.isEmpty
          ? ''
          : ' and $exportedAttachments '
              '${exportedAttachments == 1 ? 'attachment' : 'attachments'}';
      setState(
        () => _exportSuccess =
            'Exported $entriesLabel$attachLabel to $outputDir.',
      );
    } catch (e) {
      setState(() => _exportError = e.toString());
    } finally {
      setState(() => _exporting = false);
    }
  }

  /// Returns a file extension (including the dot) for a given MIME type.
  String _extensionFromMime(String mimeType) {
    const map = {
      'image/jpeg': '.jpg',
      'image/jpg': '.jpg',
      'image/png': '.png',
      'image/gif': '.gif',
      'image/webp': '.webp',
      'image/bmp': '.bmp',
      'image/tiff': '.tiff',
      'image/svg+xml': '.svg',
      'application/pdf': '.pdf',
      'text/plain': '.txt',
      'text/markdown': '.md',
      'video/mp4': '.mp4',
      'video/quicktime': '.mov',
      'audio/mpeg': '.mp3',
      'audio/wav': '.wav',
      'audio/ogg': '.ogg',
    };
    return map[mimeType.toLowerCase()] ?? '.bin';
  }

  Future<void> _closeJournal() async {
    await ref.read(dbProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PasswordPage()),
      );
    }
  }
}
