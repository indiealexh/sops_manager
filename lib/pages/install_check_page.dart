import 'dart:io';

import 'package:flutter/material.dart';

import '../pages/setup_page.dart';

class InstallCheckPage extends StatefulWidget {
  const InstallCheckPage({super.key});

  @override
  State<InstallCheckPage> createState() => _InstallCheckPageState();
}

class _InstallCheckPageState extends State<InstallCheckPage> {
  bool? ageInstalled;
  bool? sopsInstalled;
  String log = '';
  bool checking = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      checking = true;
      log = '';
    });
    final ageOk = await _isInstalled('age', ['--version']);
    final sopsOk = await _isInstalled('sops', ['--version']);
    setState(() {
      ageInstalled = ageOk;
      sopsInstalled = sopsOk;
      checking = false;
      if (!ageOk) {
        log +=
            'age not found. Please install age (https://github.com/FiloSottile/age) and ensure it is on PATH.\n';
      }
      if (!sopsOk) {
        log +=
            'sops not found. Please install sops (https://github.com/getsops/sops) and ensure it is on PATH.\n';
      }
      if (ageOk && sopsOk) {
        log = 'All required tools are installed.';
      }
    });
  }

  Future<bool> _isInstalled(String cmd, List<String> args) async {
    try {
      final res = await Process.run(cmd, args);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ageOk = ageInstalled == true;
    final sopsOk = sopsInstalled == true;
    return Scaffold(
      appBar: AppBar(title: const Text('SOPS Manager - Requirements')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ageOk ? Icons.check_circle : Icons.error,
                  color: ageOk ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text('age installed'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  sopsOk ? Icons.check_circle : Icons.error,
                  color: sopsOk ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text('sops installed'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(child: Text(log)),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: checking ? null : _check,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recheck'),
                ),
                ElevatedButton.icon(
                  onPressed: (ageOk && sopsOk && !checking)
                      ? () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const SetupPage()),
                        )
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
