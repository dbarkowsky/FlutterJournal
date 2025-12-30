import 'package:flutter/material.dart';
import 'package:journal/widgets/desktop_sidebar.dart';
import 'package:journal/widgets/markdown_editor/editor.dart';

class DesktopLayout extends StatelessWidget {
  const DesktopLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DesktopSidebar(),
          Expanded(
            child: MarkdownEditor(),
          ),
        ],
      ),
    );
  }
}
