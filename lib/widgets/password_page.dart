import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/layouts/windows_layout.dart';
import 'package:flutter/scheduler.dart';
import 'package:journal/providers/db_provider.dart';
import 'package:journal/sqlite/database.dart';
import 'package:file_picker/file_picker.dart';
import 'package:journal/helpers/last_db_prefs.dart';

class PasswordPage extends ConsumerStatefulWidget {
  const PasswordPage({super.key});

  @override
  ConsumerState<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends ConsumerState<PasswordPage> {
  final _controller = TextEditingController();
  bool _obscure = true;
  String? _error;
  bool _loading = false;
  String? _dbPath;

  @override
  void initState() {
    super.initState();
    _loadLastDbPath();
  }

  Future<void> _loadLastDbPath() async {
    final path = await LastDatabasePrefs.loadPath();
    if (path != null) {
      setState(() {
        _dbPath = path;
      });
    }
  }
  Future<void> _tryPassword(String password) async {
    if (password.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Password cannot be empty';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final notifier = ref.read(dbProvider.notifier);
    await notifier.initWithPassword(password, dbPath: _dbPath);
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
      setState(() {
        _dbPath = result.files.single.path;
        _error = null;
      });
      await LastDatabasePrefs.savePath(_dbPath!);
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
            _error = 'Invalid password';
            _controller.clear();
          });
        },
      );
    });
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter Journal Password', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _dbPath != null ? Text(
                    'Selected: ${_dbPath}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                    overflow: TextOverflow.ellipsis,
                  ) : Text(
                    'Open or create a journal database',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              TextField(
                controller: _controller,
                obscureText: _obscure,
                enabled: _dbPath != null,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: _dbPath != null ?_error : null,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
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
                      onPressed: _dbPath != null ? () => _tryPassword(_controller.text) : null,
                      child: const Text('Unlock'),
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: (){},
                    child: const Text('New'),
                  ),
                  ElevatedButton(
                    onPressed: _chooseDatabase,
                    child: const Text('Open'),
                  ),
                  
                  // TODO: Remove this testing button
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _dbPath = null;
                      });
                      },
                    child: const Text('clear'),
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
