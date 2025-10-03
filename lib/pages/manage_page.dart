import 'dart:io';
import 'package:flutter/material.dart';

import '../models/public_key_entry.dart';
import '../services/sops_service.dart';
import '../utils/file_path.dart';
import '../widgets/outputs_panel.dart';
import '../widgets/public_key_entry_card.dart';
import '../widgets/responsive_action_bar.dart';

class ManagePage extends StatefulWidget {
  final String projectRoot;
  final String ageIdentityPath;
  const ManagePage({
    super.key,
    required this.projectRoot,
    required this.ageIdentityPath,
  });

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> {
  List<PublicKeyEntry> entries = [];
  String log = '';
  bool busy = false;

  String get publicKeysPath =>
      FilePath.join(widget.projectRoot, 'public-age-keys.yaml');
  String get sopsConfigPath => FilePath.join(widget.projectRoot, '.sops.yaml');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final content = await _readPublicKeysFile();
    setState(() {
      entries = content;
    });
  }

  Future<List<PublicKeyEntry>> _readPublicKeysFile() async {
    try {
      final file = File(publicKeysPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        return SopsService.parsePublicKeysYaml(content);
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveKeys() async {
    setState(() => busy = true);
    try {
      await SopsService.writePublicKeysYaml(publicKeysPath, entries);
      await SopsService.writeSopsConfig(
        sopsConfigPath,
        entries.map((e) => e.key).toList(),
      );
      setState(() => log = 'Saved public-age-keys.yaml and updated .sops.yaml');
    } catch (e) {
      setState(() => log = 'Error saving: $e');
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> _updateKeys() async {
    setState(() => busy = true);
    try {
      final files = await SopsService.findSopsFiles(widget.projectRoot);
      final outputs = <String>[];
      for (final f in files) {
        final res = await SopsService.runSops([
          'updatekeys',
          '-y',
          f,
        ], cwd: widget.projectRoot);
        outputs.add(
          '[updatekeys] $f: exit=${res.exitCode}${res.stderr.isNotEmpty ? ' err=${res.stderr}' : ''}',
        );
      }
      setState(() => log = outputs.join('\n'));
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> _unlock() async {
    setState(() => busy = true);
    try {
      final files = await SopsService.findSopsFiles(widget.projectRoot);
      final outputs = <String>[];
      for (final f in files) {
        final res = await SopsService.runSops([
          '-d',
          '-i',
          f,
        ], cwd: widget.projectRoot);
        outputs.add(
          '[decrypt] $f: exit=${res.exitCode}${res.stderr.isNotEmpty ? ' err=${res.stderr}' : ''}',
        );
      }
      setState(() => log = outputs.join('\n'));
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> _lock() async {
    setState(() => busy = true);
    try {
      final files = await SopsService.findSopsFiles(widget.projectRoot);
      final outputs = <String>[];
      for (final f in files) {
        final res = await SopsService.runSops([
          '-e',
          '-i',
          f,
        ], cwd: widget.projectRoot);
        outputs.add(
          '[encrypt] $f: exit=${res.exitCode}${res.stderr.isNotEmpty ? ' err=${res.stderr}' : ''}',
        );
      }
      setState(() => log = outputs.join('\n'));
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Public Keys & Project')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project: ${widget.projectRoot}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
            Text(
              'Identity: ${widget.ageIdentityPath}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
            const SizedBox(height: 8),
            ResponsiveActionBar(
              children: [
                ElevatedButton.icon(
                  onPressed: busy ? null : _saveKeys,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Keys & Update .sops.yaml'),
                ),
                ElevatedButton.icon(
                  onPressed: busy ? null : _updateKeys,
                  icon: const Icon(Icons.sync),
                  label: const Text('sops updatekeys'),
                ),
                ElevatedButton.icon(
                  onPressed: busy ? null : _unlock,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Unlock Project'),
                ),
                ElevatedButton.icon(
                  onPressed: busy ? null : _lock,
                  icon: const Icon(Icons.lock),
                  label: const Text('Lock Project'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('public-age-keys.yaml'),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final e = entries[index];
                          return PublicKeyEntryCard(
                            entry: e,
                            busy: busy,
                            onRemove: () => setState(() {
                              entries.removeAt(index);
                            }),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                entries.add(
                                  PublicKeyEntry(
                                    key: '',
                                    ownerType: 'user',
                                    owner: '',
                                  ),
                                );
                              }),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Entry'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Output'),
            const SizedBox(height: 6),
            Flexible(
              fit: FlexFit.loose,
              child: OutputsPanel(text: log),
            ),
          ],
        ),
      ),
    );
  }
}
