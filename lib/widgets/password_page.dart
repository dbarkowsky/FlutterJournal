import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/layouts/windows_layout.dart';
import 'package:flutter/scheduler.dart';
import 'package:journal/providers/db_provider.dart';
import 'package:journal/sqlite/database.dart';
import 'package:file_picker/file_picker.dart';
import 'package:journal/helpers/last_db_prefs.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PasswordPage extends ConsumerStatefulWidget {
  const PasswordPage({super.key});

  @override
  ConsumerState<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends ConsumerState<PasswordPage> {
  Future<void> _showCreateDatabaseDialog() async {
    // Get a cross-platform default folder path
    String defaultFolder = '';
    try {
      final dir = await getApplicationDocumentsDirectory();
      defaultFolder = dir.path;
    } catch (_) {}
    final folderController = TextEditingController(text: defaultFolder);
    final fileNameController = TextEditingController(text: "journal");
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;
    bool obscure1 = true;
    bool obscure2 = true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create New Journal Database'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // TODO: Default folder path
                    TextField(
                      controller: folderController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Folder',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: () async {
                            String? folder = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select Folder');
                            if (folder != null) {
                              setState(() => folderController.text = folder);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: fileNameController,
                      decoration: const InputDecoration(labelText: 'File Name (no extension)'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure1,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(obscure1 ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => obscure1 = !obscure1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmController,
                      obscureText: obscure2,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        suffixIcon: IconButton(
                          icon: Icon(obscure2 ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => obscure2 = !obscure2),
                        ),
                      ),
                    ),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(errorText ?? '', style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final folder = folderController.text.trim();
                    final fileName = fileNameController.text.trim();
                    final password = passwordController.text;
                    final confirm = confirmController.text;
                    final validFileName = RegExp(r'^[\w\-. ]+$');
                    if (folder.isEmpty) {
                      setState(() => errorText = 'Please select a folder.');
                      return;
                    }
                    if (fileName.isEmpty || !validFileName.hasMatch(fileName)) {
                      setState(() => errorText = 'Invalid file name.');
                      return;
                    }
                    if (password.isEmpty) {
                      setState(() => errorText = 'Password cannot be empty.');
                      return;
                    }
                    if (password != confirm) {
                      setState(() => errorText = 'Passwords do not match.');
                      return;
                    }
                    final dbPath = '$folder${Platform.pathSeparator}$fileName.db';
                    final file = File(dbPath);
                    if (await file.exists()) {
                      setState(() => errorText = 'File already exists.');
                      return;
                    }
                    // Create DB
                    final notifier = ref.read(dbProvider.notifier);
                    await notifier.createDatabase(password, dbPath: dbPath);
                    await LastDatabasePrefs.savePath(dbPath);
                    setState(() {
                      _dbPath = dbPath;
                      _dbFileExists = true;
                      _text = Text('Selected: $_dbPath', style: const TextStyle(fontSize: 12, color: Colors.green), overflow: TextOverflow.ellipsis);
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  final _controller = TextEditingController();
  bool _obscure = true;
  String? _passwordError;
  Text? _text;
  bool _loading = false;
  String? _dbPath;
  bool _dbFileExists = false;

  @override
  void initState() {
    super.initState();
    _loadLastDbPath();
  }

  Future<void> _loadLastDbPath() async {
    final path = await LastDatabasePrefs.loadPath();
    if (path != null) {
      final exists = await File(path).exists();
      setState(() {
        _dbPath = exists ? path : null;
        _dbFileExists = exists;
        if (exists) {
          _text = Text(
            'Selected: $_dbPath',
            style: const TextStyle(fontSize: 12, color: Colors.green),
            overflow: TextOverflow.ellipsis,
          );
        } else {
          _text = Text(
            'Previous database file not found',
            style: const TextStyle(fontSize: 12, color: Colors.red),
            overflow: TextOverflow.ellipsis,
          );
        }
      });
    } else {
      setState(() {
        _dbFileExists = false;
        _text = Text(
          'Open or create a journal database',
          style: const TextStyle(fontSize: 12, color: Colors.red),
          overflow: TextOverflow.ellipsis,
        );
      });
    }
  }

  Future<void> _tryPassword(String password) async {
    if (password.isEmpty) {
      setState(() {
        _loading = false;
        _passwordError = 'Password cannot be empty';
      });
      return;
    }
    setState(() {
      _loading = true;
      _passwordError = null;
    });
    final notifier = ref.read(dbProvider.notifier);
    await notifier.openDatabaseWithPassword(password, dbPath: _dbPath);
    // If the provider is not loading after submit, reset loading state (safety net)
    final state = ref.read(dbProvider);
    if (!state.isLoading) {
      setState(() {
        _loading = false;
      });
    }
    // Success/failure handled by listener
  }

  Future<void> _chooseDatabase() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Journal Database',
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final exists = await File(path).exists();
      setState(() {
        _dbPath = exists ? path : null;
        _dbFileExists = exists;
        _text = exists
            ? Text(
                'Selected: $_dbPath',
                style: const TextStyle(fontSize: 12, color: Colors.green),
                overflow: TextOverflow.ellipsis,
              )
            : Text(
                'Selected file does not exist.',
                style: const TextStyle(fontSize: 12, color: Colors.red),
                overflow: TextOverflow.ellipsis,
              );
      });
      if (exists) {
        await LastDatabasePrefs.savePath(_dbPath!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<JournalDB>>(dbProvider, (prev, next) {
      next.whenOrNull(
        data: (db) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DesktopLayout()),
            );
          });
        },
        error: (e, st) {
          setState(() {
            _loading = false;
            _passwordError = 'Invalid password';
            _controller.clear();
          });
        },
      );
    });
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter Journal Password',
                style: TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _text,
              ),
              TextField(
                controller: _controller,
                obscureText: _obscure,
                enabled: _dbFileExists && _dbPath != null,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: _dbFileExists && _dbPath != null
                      ? _passwordError
                      : null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (val) => _tryPassword(val),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _dbFileExists && _dbPath != null
                      ? () => _tryPassword(_controller.text)
                      : null,
                  child: const Text('Unlock'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 100,
                    child: ElevatedButton(
                      onPressed: _showCreateDatabaseDialog,
                      child: const Text('New'),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: ElevatedButton(
                      onPressed: _chooseDatabase,
                      child: const Text('Open'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
