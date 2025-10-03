import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../services/sops_service.dart';
import 'manage_page.dart';

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
