import 'package:flutter/material.dart';
import 'package:journal/widgets/sidebars/entry_date_sidebar.dart';
import 'package:journal/widgets/sidebars/search_sidebar.dart';

class DesktopSidebar extends StatefulWidget {
  const DesktopSidebar({super.key});

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  int _selectedIndex = 0;
  double _sidebarWidth = 300;
  static const double _minWidth = 300;
  static const double _maxWidth = 600;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    Widget sidebarContent;
    switch (_selectedIndex) {
      case 0:
        sidebarContent = const EntryDateSidebar();
        break;
      case 1:
        sidebarContent = const SearchSidebar();
        break;
      default:
        sidebarContent = const SizedBox.shrink();
    }

    return Row(
      children: [
        SizedBox(
          width: _sidebarWidth,
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
        ),
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {
              setState(() => _dragging = true);
            },
            onHorizontalDragUpdate: (details) {
              setState(() {
                _sidebarWidth = (_sidebarWidth + details.delta.dx)
                    .clamp(_minWidth, _maxWidth);
              });
            },
            onHorizontalDragEnd: (_) {
              setState(() => _dragging = false);
            },
            child: Container(
              width: 8,
              height: double.infinity,
              color: _dragging
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.transparent,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}
