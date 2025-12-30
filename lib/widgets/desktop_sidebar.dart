import 'package:flutter/material.dart';
import 'package:journal/widgets/sidebars/entry_date_sidebar.dart';

class DesktopSidebar extends StatefulWidget {
  const DesktopSidebar({super.key});

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget sidebarContent;
    switch (_selectedIndex) {
      case 0:
        sidebarContent = const EntryDateSidebar();
        break;
      case 1:
        sidebarContent = const Center(child: Text('Blank Page'));
        break;
      default:
        sidebarContent = const SizedBox.shrink();
    }

    return SizedBox(
      width: 300,
      child: Column(
        children: [
          Expanded(child: sidebarContent),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_calendar,
                      color: _selectedIndex == 0 ? Colors.blue : null),
                  tooltip: 'Journal Entries',
                  onPressed: () => setState(() => _selectedIndex = 0),
                ),
                IconButton(
                  icon: Icon(Icons.search,
                      color: _selectedIndex == 1 ? Colors.blue : null),
                  tooltip: 'Blank Page',
                  onPressed: () => setState(() => _selectedIndex = 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
