import 'dart:io';

import 'package:flutter/material.dart';
import 'package:journal/layouts/windows_layout.dart';

void main() {
  runApp(const MyApp());
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
      home: Platform.isWindows ? WindowsLayout() : Text('Ooops')
    );
  }
}
