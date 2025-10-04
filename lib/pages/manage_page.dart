import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/public_key_entry.dart';
import '../models/log_entry.dart';
import '../services/log_bus.dart';
import '../services/sops_service.dart';
import '../utils/file_path.dart';
import '../widgets/log_view.dart';
import '../widgets/outputs_panel.dart';
import '../widgets/public_key_entry_card.dart';
import '../widgets/responsive_action_bar.dart';

class ManagePage extends StatefulWidget {
  final String projectRoot;
  final String ageIdentityPath;
  final List<Widget>? appBarActions;
  const ManagePage({
    super.key,
    required this.projectRoot,
    required this.ageIdentityPath,
    this.appBarActions,
  });

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> {
  List<PublicKeyEntry> entries = [];
  String log = '';
  bool busy = false;

  // Iteration 2 additions
  List<String> _patterns = [];
  List<String> _allMatches = [];
  Set<String> _encryptedSet = {};
  Set<String> _selected = {};
  String _search = '';
  bool _scanning = false;

  // Logs
  final List<LogEntry> _logs = [];
  StreamSubscription<LogEntry>? _sub;

  String get publicKeysPath =>
      FilePath.join(widget.projectRoot, 'public-age-keys.yaml');
  String get sopsConfigPath => FilePath.join(widget.projectRoot, '.sops.yaml');

  @override
  void initState() {
    super.initState();
    _load();
    _sub = LogBus.instance.stream.listen((e) {
      setState(() => _logs.add(e));
    });
    // Auto-scan on load so user doesn't have to click Scan manually
    Future.microtask(_scanFiles);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _scanFiles() async {
    setState(() {
      _scanning = true;
    });
    try {
      _patterns = await SopsService.listPathRegexps(widget.projectRoot);
      final all = await SopsService.findSopsFiles(
        widget.projectRoot,
        includeNonSops: true,
      );
      final enc = await SopsService.findSopsFiles(
        widget.projectRoot,
        includeNonSops: false,
      );
      setState(() {
        _allMatches = all;
        _encryptedSet = enc.toSet();
        // default select: all encrypted files
        _selected = _encryptedSet.toSet();
      });
      LogBus.instance.info(
        'Scanned ${all.length} files (encrypted: ${enc.length}).',
        scope: 'Manage',
      );
    } catch (e) {
      LogBus.instance.error('Scan failed: $e', scope: 'Manage');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
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
      final recipients = entries.map((e) => e.key).toList();
      final sopsFile = File(sopsConfigPath);
      if (await sopsFile.exists()) {
        final updated = await SopsService.updateSopsRecipients(
          sopsConfigPath,
          recipients,
        );
        setState(
          () => log =
              'Saved public-age-keys.yaml and updated recipients in .sops.yaml for ' +
              updated.toString() +
              ' creation_rule(s).',
        );
      } else {
        await SopsService.writeSopsConfig(sopsConfigPath, recipients);
        setState(
          () => log = 'Saved public-age-keys.yaml and created .sops.yaml',
        );
      }
    } catch (e) {
      setState(() => log = 'Error saving: $e');
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> _updateKeys() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No files selected. Run Scan and select files.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final files = _selected.toList();
      LogBus.instance.info(
        'Running sops updatekeys on ${files.length} file(s)...',
        scope: 'Manage',
      );
      int ok = 0;
      await SopsService.runBatch(
        files,
        (f) => ['updatekeys', '-y', f],
        cwd: widget.projectRoot,
        identityPath: widget.ageIdentityPath,
        concurrency: 4,
        onProgress: (f, res) {
          if (res.exitCode == 0) ok++;
          LogBus.instance.info(
            '[updatekeys] $f -> exit ${res.exitCode}${res.stderr.isNotEmpty ? ' err=${res.stderr}' : ''}',
            scope: 'Manage',
            file: f,
          );
        },
      );
      LogBus.instance.info(
        'updatekeys complete: $ok/${files.length} succeeded.',
        scope: 'Manage',
      );
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> _unlock() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No files selected. Run Scan and select files.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final files = _selected.toList();
      LogBus.instance.info(
        'Decrypting ${files.length} file(s)...',
        scope: 'Manage',
      );
      int ok = 0;
      await SopsService.runBatch(
        files,
        (f) => ['-d', '-i', f],
        cwd: widget.projectRoot,
        identityPath: widget.ageIdentityPath,
        concurrency: 4,
        onProgress: (f, res) {
          if (res.exitCode == 0) ok++;
          LogBus.instance.info(
            '[decrypt] $f -> exit ${res.exitCode}${res.stderr.isNotEmpty ? ' err=${res.stderr}' : ''}',
            scope: 'Manage',
            file: f,
          );
        },
      );
      LogBus.instance.info(
        'Decrypt complete: $ok/${files.length} succeeded.',
        scope: 'Manage',
      );
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> _lock() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No files selected. Run Scan and select files.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final files = _selected.toList();
      if (kDebugMode) {
        print(files);
      }
      LogBus.instance.info(
        'Encrypting ${files.length} file(s)...',
        scope: 'Manage',
      );
      int ok = 0;
      await SopsService.runBatch(
        files,
        (f) => ['-e', '-i', f],
        cwd: widget.projectRoot,
        identityPath: widget.ageIdentityPath,
        concurrency: 4,
        onProgress: (f, res) {
          if (res.exitCode == 0) ok++;
          LogBus.instance.info(
            '[encrypt] $f -> exit ${res.exitCode}${res.stderr.isNotEmpty ? ' err=${res.stderr}' : ''}',
            scope: 'Manage',
            file: f,
          );
        },
      );
      LogBus.instance.info(
        'Encrypt complete: $ok/${files.length} succeeded.',
        scope: 'Manage',
      );
    } finally {
      setState(() => busy = false);
    }
  }

  Widget _buildFilesList() {
    final q = _search.toLowerCase();
    final items =
        _allMatches
            .where((f) => q.isEmpty || f.toLowerCase().contains(q))
            .toList()
          ..sort();
    if (items.isEmpty) {
      return const Center(child: Text('No files. Click Scan to discover.'));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final f = items[i];
        final enc = _encryptedSet.contains(f);
        return CheckboxListTile(
          value: _selected.contains(f),
          onChanged: (v) => setState(() {
            if (v == true) {
              _selected.add(f);
            } else {
              _selected.remove(f);
            }
          }),
          dense: true,
          title: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: enc ? const Text('Encrypted') : const Text('Plain'),
          secondary: Icon(
            enc ? Icons.lock : Icons.description,
            color: enc ? Colors.green : Colors.grey,
          ),
        );
      },
    );
  }

  void _copyLogs() {
    final b = StringBuffer();
    for (final e in _logs) {
      b.writeln('[${_fmtTs(e.ts)}] ${e.level} ${e.message}');
    }
    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logs copied to clipboard')));
  }

  String _fmtTs(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Public Keys & Project'),
        actions: widget.appBarActions,
      ),
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
            Expanded(
              child: Row(
                children: [
                  // Left: Keys editor
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right: Files panel + Logs
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Files'),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _scanning || busy ? null : _scanFiles,
                              icon: const Icon(Icons.search),
                              label: Text(_scanning ? 'Scanning…' : 'Scan'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: _allMatches.isEmpty
                                  ? null
                                  : () => setState(
                                      () => _selected = _allMatches.toSet(),
                                    ),
                              child: const Text('Select All'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: _selected.isEmpty
                                  ? null
                                  : () => setState(() => _selected.clear()),
                              child: const Text('Select None'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _patterns.isEmpty
                              ? [const Chip(label: Text('No patterns'))]
                              : _patterns
                                    .map((p) => Chip(label: Text(p)))
                                    .toList(),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Filter files',
                          ),
                          onChanged: (v) => setState(() => _search = v.trim()),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _buildFilesList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Logs'),
                        const SizedBox(height: 6),
                        Expanded(
                          child: LogView(
                            entries: _logs,
                            onClear: () => setState(() => _logs.clear()),
                            onCopy: () => _copyLogs(),
                          ),
                        ),
                      ],
                    ),
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
