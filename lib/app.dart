import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/app_shell.dart';

class SopsManagerApp extends StatefulWidget {
  const SopsManagerApp({super.key});

  @override
  State<SopsManagerApp> createState() => _SopsManagerAppState();
}

class _SopsManagerAppState extends State<SopsManagerApp> {
  ThemeMode _mode = ThemeMode.system;

  static const _kThemeKey = 'themeMode';

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_kThemeKey);
      setState(() {
        _mode = switch (v) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
      });
    } catch (_) {}
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _mode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeKey, switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      });
    } catch (_) {}
  }

  ThemeData _buildLightTheme() {
    // Brand colors
    const primary = Color(0xFFEEE8D5); // light mode primary
    const secondary = Color(0xFF4E6664);
    const tertiary = Color(0xFF1F2949);
    final scheme = ColorScheme.fromSeed(
      seedColor: tertiary,
      brightness: Brightness.light,
    ).copyWith(primary: primary, secondary: secondary, tertiary: tertiary);

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimaryContainer,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const primary = Color(0xFF4E6664); // dark mode primary
    const secondary = Color(0xFFEEE8D5);
    const tertiary = Color(0xFF1F2949);
    final scheme = ColorScheme.fromSeed(
      seedColor: tertiary,
      brightness: Brightness.dark,
    ).copyWith(primary: primary, secondary: secondary, tertiary: tertiary);

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimaryContainer,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOPS Manager',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: _mode,
      home: AppShell(themeMode: _mode, onThemeModeChanged: _setThemeMode),
    );
  }
}
