import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/install_check_page.dart';
import '../pages/setup_page.dart';
import '../pages/manage_page.dart';

class AppShell extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  const AppShell({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0; // 0: Requirements, 1: Setup, 2: Manage
  String? _lastProjectRoot;
  String? _lastIdentityPath;
  bool _loaded = false;

  static const _kRootKey = 'lastProjectRoot';
  static const _kIdKey = 'lastAgeIdentityPath';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _lastProjectRoot = prefs.getString(_kRootKey);
        _lastIdentityPath = prefs.getString(_kIdKey);
        _loaded = true;
      });
    } catch (_) {
      setState(() => _loaded = true);
    }
  }

  Future<void> _savePaths(String root, String identity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kRootKey, root);
      await prefs.setString(_kIdKey, identity);
    } catch (_) {}
    setState(() {
      _lastProjectRoot = root;
      _lastIdentityPath = identity;
    });
  }

  Widget _buildThemeModeButton() {
    IconData icon;
    String label;
    switch (widget.themeMode) {
      case ThemeMode.light:
        icon = Icons.light_mode;
        label = 'Light';
        break;
      case ThemeMode.dark:
        icon = Icons.dark_mode;
        label = 'Dark';
        break;
      default:
        icon = Icons.brightness_auto;
        label = 'System';
    }
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Theme: $label',
      icon: Icon(icon),
      onSelected: widget.onThemeModeChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: ThemeMode.system,
          child: ListTile(
            leading: Icon(Icons.brightness_auto),
            title: Text('System'),
          ),
        ),
        PopupMenuItem(
          value: ThemeMode.light,
          child: ListTile(
            leading: Icon(Icons.light_mode),
            title: Text('Light'),
          ),
        ),
        PopupMenuItem(
          value: ThemeMode.dark,
          child: ListTile(leading: Icon(Icons.dark_mode), title: Text('Dark')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final destinations = const [
      NavigationDestination(icon: Icon(Icons.rule), label: 'Requirements'),
      NavigationDestination(icon: Icon(Icons.build), label: 'Setup'),
      NavigationDestination(icon: Icon(Icons.key), label: 'Manage'),
    ];

    Widget page;
    if (!_loaded) {
      page = const Center(child: CircularProgressIndicator());
    } else {
      switch (_index) {
        case 0:
          page = InstallCheckPage(
            onContinue: () => setState(() => _index = 1),
            appBarActions: [_buildThemeModeButton()],
          );
          break;
        case 1:
          page = SetupPage(
            onComplete: (ageKey, root, pubKey) async {
              await _savePaths(root, ageKey);
              if (mounted) setState(() => _index = 2);
            },
            appBarActions: [_buildThemeModeButton()],
          );
          break;
        default:
          if (_lastProjectRoot != null && _lastIdentityPath != null) {
            page = ManagePage(
              projectRoot: _lastProjectRoot!,
              ageIdentityPath: _lastIdentityPath!,
              appBarActions: [_buildThemeModeButton()],
            );
          } else {
            page = Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No project configured yet. Complete Setup first.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => setState(() => _index = 1),
                      icon: const Icon(Icons.build),
                      label: const Text('Go to Setup'),
                    ),
                  ],
                ),
              ),
            );
          }
      }
    }

    final rail = NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.rule),
          label: Text('Requirements'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.build),
          label: Text('Setup'),
        ),
        NavigationRailDestination(icon: Icon(Icons.key), label: Text('Manage')),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOPS Manager'),
        actions: [_buildThemeModeButton()],
      ),
      body: Row(
        children: [
          if (isWide) rail,
          if (isWide) const VerticalDivider(width: 1),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(16), child: page),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: destinations,
            ),
    );
  }
}
