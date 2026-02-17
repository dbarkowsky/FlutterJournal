import 'package:flutter/material.dart';
import 'package:journal/widgets/sidebars/entry_date_sidebar.dart';
import 'package:journal/widgets/sidebars/image_gallery_sidebar.dart';
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
      case 2:
        sidebarContent = const ImageGallerySidebar();
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
                      tooltip: 'Dates',
                      onPressed: () => setState(() => _selectedIndex = 0),
                    ),
                    IconButton(
                      icon: Icon(Icons.search,
                          color: _selectedIndex == 1 ? Colors.blue : null),
                      tooltip: 'Search',
                      onPressed: () => setState(() => _selectedIndex = 1),
                    ),
                    IconButton(
                      icon: Icon(Icons.image,
                          color: _selectedIndex == 2 ? Colors.blue : null),
                      tooltip: 'Images',
                      onPressed: () => setState(() => _selectedIndex = 2),
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
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.transparent,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}
