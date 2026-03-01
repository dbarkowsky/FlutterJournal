import 'package:flutter/material.dart';
import 'package:journal/widgets/markdown_editor/editor.dart';
import 'package:journal/widgets/sidebars/entry_date_sidebar.dart';
import 'package:journal/widgets/sidebars/image_gallery_sidebar.dart';
import 'package:journal/widgets/sidebars/options_sidebar.dart';
import 'package:journal/widgets/sidebars/search_sidebar.dart';

class MobileLayout extends StatelessWidget {
  const MobileLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
      ),
      drawer: const _MobileDrawer(),
      body: const MarkdownEditor(),
    );
  }
}

class _MobileDrawer extends StatefulWidget {
  const _MobileDrawer();

  @override
  State<_MobileDrawer> createState() => _MobileDrawerState();
}

class _MobileDrawerState extends State<_MobileDrawer> {
  int _selectedIndex = 0;

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
        break;
      case 3:
        sidebarContent = const OptionsSidebar();
        break;
      default:
        sidebarContent = const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(child: sidebarContent),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _DrawerTab(
                    icon: Icons.edit_calendar,
                    tooltip: 'Dates',
                    selected: _selectedIndex == 0,
                    selectedColor: colorScheme.primary,
                    onTap: () => setState(() => _selectedIndex = 0),
                  ),
                  _DrawerTab(
                    icon: Icons.search,
                    tooltip: 'Search',
                    selected: _selectedIndex == 1,
                    selectedColor: colorScheme.primary,
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                  _DrawerTab(
                    icon: Icons.image,
                    tooltip: 'Images',
                    selected: _selectedIndex == 2,
                    selectedColor: colorScheme.primary,
                    onTap: () => setState(() => _selectedIndex = 2),
                  ),
                  _DrawerTab(
                    icon: Icons.settings,
                    tooltip: 'Options',
                    selected: _selectedIndex == 3,
                    selectedColor: colorScheme.primary,
                    onTap: () => setState(() => _selectedIndex = 3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTab extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _DrawerTab({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: selected ? selectedColor : null),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}
