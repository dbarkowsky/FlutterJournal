import 'dart:io';

import 'package:flutter/material.dart';
import 'package:journal/layouts/windows_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Journal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Platform.isWindows || Platform.isLinux || Platform.isMacOS
          ? DesktopLayout()
          : Text('Ooops'),
    );
  }
}
