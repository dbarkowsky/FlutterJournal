import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/layouts/windows_layout.dart';
import 'package:flutter/scheduler.dart';
import 'package:journal/providers/db_provider.dart';
import 'package:journal/sqlite/database.dart';

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

  Future<void> _tryPassword(String password) async {
    print('password $password');
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
    await notifier.initWithPassword(password);
    print(ref.read(dbProvider).value?.isInitialized());
    // If the provider is not loading after submit, reset loading state (safety net)
    final state = ref.read(dbProvider);
    if (!state.isLoading) {
      setState(() {
        _loading = false;
      });
    }
    // Success/failure handled by listener
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
              TextField(
                controller: _controller,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: _error,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (val) => _tryPassword(val),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _tryPassword(_controller.text),
                child: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
