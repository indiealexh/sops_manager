import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: checking ? null : _check,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recheck'),
                ),
                const SizedBox(width: 8),
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

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final ageKeyCtrl = TextEditingController();
  final projectRootCtrl = TextEditingController();
  final publicKeyCtrl = TextEditingController();
  bool busy = false;
  String output = '';

  Future<void> _pickAgeKeyFile() async {
    final typeGroup = const XTypeGroup(
      label: 'Age key',
      extensions: ['txt', 'agekey'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null) {
      setState(() {
        ageKeyCtrl.text = file.path;
      });
      try {
        if (publicKeyCtrl.text.trim().isEmpty) {
          final pk = await SopsService.derivePublicKey(file.path);
          if (pk != null && pk.isNotEmpty) {
            setState(() {
              publicKeyCtrl.text = pk;
            });
          }
        }
      } catch (_) {
        // ignore
      }
    }
  }

  Future<void> _pickProjectRootDir() async {
    final path = await getDirectoryPath();
    if (path != null) {
      setState(() {
        projectRootCtrl.text = path;
      });
    }
  }

  @override
  void dispose() {
    ageKeyCtrl.dispose();
    projectRootCtrl.dispose();
    publicKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    setState(() {
      busy = true;
      output = '';
    });
    final ageKey = ageKeyCtrl.text.trim();
    final root = projectRootCtrl.text.trim();
    var pubKey = publicKeyCtrl.text.trim();

    if (ageKey.isEmpty || root.isEmpty) {
      setState(() {
        busy = false;
        output =
            'Please provide both Age identity file path and project root directory.';
      });
      return;
    }

    try {
      if (pubKey.isEmpty) {
        pubKey = await SopsService.derivePublicKey(ageKey) ?? '';
      }
      if (pubKey.isEmpty) {
        setState(() {
          busy = false;
          output =
              'Could not derive public key from the identity. Please provide Public Key explicitly.';
        });
        return;
      }

      final messages = <String>[];
      await SopsService.ensureProjectFiles(
        root: root,
        publicKey: pubKey,
        messages: messages,
      );

      setState(() => output = messages.join('\n'));

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              ManagePage(projectRoot: root, ageIdentityPath: ageKey),
        ),
      );
    } catch (e) {
      setState(() {
        output = 'Error: $e';
      });
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Initial Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provide paths:'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ageKeyCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText:
                          'Age identity file path (e.g. ~/.config/age/keys.txt)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: busy ? null : _pickAgeKeyFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Browse'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: projectRootCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Project root directory',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: busy ? null : _pickProjectRootDir,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Browse'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: publicKeyCtrl,
              decoration: const InputDecoration(
                labelText: 'Public key (optional, will be derived if empty)',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: busy ? null : _proceed,
                  icon: const Icon(Icons.done),
                  label: const Text('Proceed'),
                ),
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
                child: SingleChildScrollView(child: Text(output)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final file = File(publicKeysPath);
    if (await file.exists()) {
      final content = await file.readAsString();
      setState(() {
        entries = SopsService.parsePublicKeysYaml(content);
      });
    } else {
      setState(() {
        entries = [];
      });
    }
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
          '[updatekeys] ${f}: exit=${res.exitCode}${res.stderr.isNotEmpty ? ' err=' + res.stderr : ''}',
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
          '[decrypt] ${f}: exit=${res.exitCode}${res.stderr.isNotEmpty ? ' err=' + res.stderr : ''}',
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
          '[encrypt] ${f}: exit=${res.exitCode}${res.stderr.isNotEmpty ? ' err=' + res.stderr : ''}',
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
            Text('Project: ${widget.projectRoot}'),
            Text('Identity: ${widget.ageIdentityPath}'),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: busy ? null : _saveKeys,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Keys & Update .sops.yaml'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: busy ? null : _updateKeys,
                  icon: const Icon(Icons.sync),
                  label: const Text('sops updatekeys'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: busy ? null : _unlock,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Unlock Project'),
                ),
                const SizedBox(width: 8),
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
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: e.key,
                                          decoration: const InputDecoration(
                                            labelText: 'key (age1...)',
                                          ),
                                          onChanged: (v) => e.key = v.trim(),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remove',
                                        onPressed: busy
                                            ? null
                                            : () => setState(() {
                                                entries.removeAt(index);
                                              }),
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: e.ownerType,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'ownerType (user/cluster)',
                                          ),
                                          onChanged: (v) =>
                                              e.ownerType = v.trim(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: e.owner,
                                          decoration: const InputDecoration(
                                            labelText: 'owner',
                                          ),
                                          onChanged: (v) => e.owner = v.trim(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
            SizedBox(
              height: 120,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(child: Text(log)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PublicKeyEntry {
  String key;
  String ownerType;
  String owner;
  PublicKeyEntry({
    required this.key,
    required this.ownerType,
    required this.owner,
  });
}

class FilePath {
  static String join(String a, String b) {
    if (a.endsWith(Platform.pathSeparator)) return a + b;
    return a + Platform.pathSeparator + b;
  }
}

class ProcResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  ProcResult(this.exitCode, this.stdout, this.stderr);
}

class SopsService {
  static String _username() {
    final env = Platform.environment;
    return env['USER'] ?? env['USERNAME'] ?? 'unknown';
  }

  static Future<String?> derivePublicKey(String identityPath) async {
    try {
      final res = await Process.run('age-keygen', ['-y', '-i', identityPath]);
      if (res.exitCode == 0) {
        final out = (res.stdout as String).toString();
        final m = RegExp(r'public key:\s*(age1[0-9a-z]+)').firstMatch(out);
        if (m != null) return m.group(1);
        // Sometimes age-keygen prints only the key
        final mm = RegExp(r'\b(age1[0-9a-z]+)\b').firstMatch(out);
        if (mm != null) return mm.group(1);
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  static Future<void> ensureProjectFiles({
    required String root,
    required String publicKey,
    List<String>? messages,
  }) async {
    final msgs = messages ?? <String>[];
    final pkPath = FilePath.join(root, 'public-age-keys.yaml');
    final sopsPath = FilePath.join(root, '.sops.yaml');

    // Ensure project root exists
    final dir = Directory(root);
    if (!await dir.exists()) {
      throw Exception('Project root does not exist: $root');
    }

    // Ensure public-age-keys.yaml
    final pkFile = File(pkPath);
    List<PublicKeyEntry> current = [];
    if (await pkFile.exists()) {
      current = parsePublicKeysYaml(await pkFile.readAsString());
    }

    if (!current.any((e) => e.key == publicKey)) {
      current.add(
        PublicKeyEntry(key: publicKey, ownerType: 'user', owner: _username()),
      );
      msgs.add('Added current user public key to public-age-keys.yaml');
    } else {
      msgs.add('Public key already present in public-age-keys.yaml');
    }

    await writePublicKeysYaml(pkPath, current);

    // Ensure .sops.yaml
    await writeSopsConfig(sopsPath, current.map((e) => e.key).toList());
    msgs.add('Wrote .sops.yaml with ${current.length} recipient(s).');
  }

  static List<PublicKeyEntry> parsePublicKeysYaml(String content) {
    final lines = const LineSplitter().convert(content);
    final out = <PublicKeyEntry>[];
    String? key;
    String? ownerType;
    String? owner;
    for (final raw in lines) {
      final line = raw.trim();
      final keyMatch = RegExp(r'^-\s*key:\s*(\S+)$').firstMatch(line);
      if (keyMatch != null) {
        // If previous entry incomplete, drop it
        key = keyMatch.group(1);
        ownerType = null;
        owner = null;
        continue;
      }
      final otMatch = RegExp(r'^ownerType:\s*(\S+)').firstMatch(line);
      if (otMatch != null) {
        ownerType = otMatch.group(1);
        continue;
      }
      final oMatch = RegExp(r'^owner:\s*(.+)$').firstMatch(line);
      if (oMatch != null) {
        owner = oMatch.group(1)?.trim();
      }
      if (key != null && ownerType != null && owner != null) {
        out.add(
          PublicKeyEntry(key: key!, ownerType: ownerType!, owner: owner!),
        );
        key = null;
        ownerType = null;
        owner = null;
      }
    }
    return out;
  }

  static Future<void> writePublicKeysYaml(
    String path,
    List<PublicKeyEntry> entries,
  ) async {
    final b = StringBuffer();
    b.writeln('publicKeys:');
    for (final e in entries) {
      b.writeln('  - key: ${e.key}');
      b.writeln('    ownerType: ${e.ownerType}');
      b.writeln('    owner: ${e.owner}');
    }
    await File(path).writeAsString(b.toString());
  }

  static Future<void> writeSopsConfig(
    String path,
    List<String> recipients,
  ) async {
    final b = StringBuffer();
    b.writeln('creation_rules:');
    b.writeln(
      "  - path_regex: '.*\\.(yaml|yml|json|env)'".replaceAll('\u001b', ''),
    );
    b.writeln('    age:');
    for (final r in recipients) {
      b.writeln('      - $r');
    }
    await File(path).writeAsString(b.toString());
  }

  static Future<List<String>> findSopsFiles(String root) async {
    final result = <String>[];
    final dir = Directory(root);
    if (!await dir.exists()) return result;

    final allowedExt = {'.yaml', '.yml', '.json', '.env'};

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name == '.sops.yaml' || name == 'public-age-keys.yaml') continue;
        final ext = _extension(name).toLowerCase();
        if (!allowedExt.contains(ext)) continue;
        final len = await entity.length();
        if (len > 5 * 1024 * 1024) continue; // skip very large files
        try {
          final content = await entity.readAsString();
          if (content.contains('\nsops:') || content.contains('"sops"')) {
            // Likely a sops file
            // store relative path for nicer CLI workingDirectory usage
            final rel = _relativeTo(root, entity.path);
            result.add(rel);
          }
        } catch (_) {
          // ignore
        }
      }
    }
    return result;
  }

  static String _extension(String name) {
    final i = name.lastIndexOf('.');
    return i == -1 ? '' : name.substring(i);
  }

  static String _relativeTo(String root, String fullPath) {
    if (!fullPath.startsWith(root)) return fullPath;
    var rel = fullPath.substring(root.length);
    if (rel.startsWith(Platform.pathSeparator)) rel = rel.substring(1);
    return rel;
  }

  static Future<ProcResult> runSops(
    List<String> args, {
    required String cwd,
  }) async {
    try {
      final res = await Process.run('sops', args, workingDirectory: cwd);
      return ProcResult(
        res.exitCode,
        (res.stdout ?? '').toString(),
        (res.stderr ?? '').toString(),
      );
    } catch (e) {
      return ProcResult(127, '', e.toString());
    }
  }
}
