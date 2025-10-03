import 'package:flutter/material.dart';
import 'pages/install_check_page.dart';

class SopsManagerApp extends StatelessWidget {
  const SopsManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOPS Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const InstallCheckPage(),
    );
  }
}
