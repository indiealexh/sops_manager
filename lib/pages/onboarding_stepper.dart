import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/log_bus.dart';
import '../services/sops_service.dart';
import 'manage_page.dart';

class OnboardingStepperPage extends StatefulWidget {
  final List<Widget>? appBarActions;
  const OnboardingStepperPage({super.key, this.appBarActions});

  @override
  State<OnboardingStepperPage> createState() => _OnboardingStepperPageState();
}

class _OnboardingStepperPageState extends State<OnboardingStepperPage> {
  int _current = 0;

  // Step 1: requirements
  bool? _ageOk;
  bool? _sopsOk;
  bool _checking = false;

  // Step 2: setup
  final _ageKeyCtrl = TextEditingController();
  final _rootCtrl = TextEditingController();
  final _pubKeyCtrl = TextEditingController();

  // Step 3: confirm
  List<String> _patterns = [];
  int _matchedCount = 0;
  Set<String> _currentRecipients = {};
  Set<String> _desiredRecipients = {};

  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _recheck();
  }

  @override
  void dispose() {
    _ageKeyCtrl.dispose();
    _rootCtrl.dispose();
    _pubKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _recheck() async {
    setState(() {
      _checking = true;
      _ageOk = null;
      _sopsOk = null;
    });
    Future<bool> toolOk(String cmd) async {
      try {
        final r = await Process.run(cmd, ['--version']);
        return r.exitCode == 0;
      } catch (_) {
        return false;
      }
    }

    // ignore: no_leading_underscores_for_local_identifiers
    final ageOk = await toolOk('age');
    // ignore: no_leading_underscores_for_local_identifiers
    final sopsOk = await toolOk('sops');
    LogBus.instance.info(
      'Checked tools: age=${ageOk ? 'OK' : 'MISSING'}, sops=${sopsOk ? 'OK' : 'MISSING'}',
      scope: 'Onboarding',
    );
    setState(() {
      _ageOk = ageOk;
      _sopsOk = sopsOk;
      _checking = false;
    });
  }

  Future<void> _pickAgeKey() async {
    final typeGroup = const XTypeGroup(
      label: 'Age key',
      extensions: ['txt', 'agekey'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null) {
      _ageKeyCtrl.text = file.path;
      if (_pubKeyCtrl.text.trim().isEmpty) {
        final pk = await SopsService.derivePublicKey(file.path);
        if (pk != null) _pubKeyCtrl.text = pk;
      }
    }
  }

  Future<void> _pickRoot() async {
    final path = await getDirectoryPath();
    if (path != null) _rootCtrl.text = path;
  }

  Future<void> _prepareConfirm() async {
    final root = _rootCtrl.text.trim();
    final ageKey = _ageKeyCtrl.text.trim();
    var pubKey = _pubKeyCtrl.text.trim();
    if (root.isEmpty || ageKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide both identity and project root'),
        ),
      );
      return;
    }
    if (pubKey.isEmpty) {
      pubKey = await SopsService.derivePublicKey(ageKey) ?? '';
    }
    if (pubKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not derive public key. Enter it manually.'),
        ),
      );
      return;
    }
    _desiredRecipients = {pubKey};

    final patterns = await SopsService.listPathRegexps(root);
    final files = await SopsService.findSopsFiles(root, includeNonSops: true);
    final recipients = await SopsService.readRecipients('$root/.sops.yaml');

    setState(() {
      _patterns = patterns;
      _matchedCount = files.length;
      _currentRecipients = recipients;
    });
    LogBus.instance.info(
      'Confirm step prepared: ${patterns.length} pattern(s), ${files.length} match(es), recipients ${recipients.length}',
      scope: 'Onboarding',
    );
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    try {
      final root = _rootCtrl.text.trim();
      final ageKey = _ageKeyCtrl.text.trim();
      final pk = _pubKeyCtrl.text.trim();
      final messages = <String>[];
      await SopsService.ensureProjectFiles(
        root: root,
        publicKey: pk,
        messages: messages,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastProjectRoot', root);
      await prefs.setString('lastAgeIdentityPath', ageKey);
      await prefs.setBool('onboardingComplete', true);

      LogBus.instance.info(
        'Onboarding finished. ${messages.join(' ')}',
        scope: 'Onboarding',
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              ManagePage(projectRoot: root, ageIdentityPath: ageKey),
        ),
      );
    } catch (e) {
      LogBus.instance.error(
        'Onboarding finish failed: $e',
        scope: 'Onboarding',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.appBarActions ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('First‑run Setup'), actions: actions),
      body: Stepper(
        currentStep: _current,
        onStepContinue: () async {
          if (_current == 0) {
            if (_ageOk == true && _sopsOk == true) setState(() => _current = 1);
          } else if (_current == 1) {
            await _prepareConfirm();
            setState(() => _current = 2);
          } else if (_current == 2) {
            await _finish();
          }
        },
        onStepCancel: () =>
            setState(() => _current = (_current > 0) ? _current - 1 : 0),
        controlsBuilder: (context, details) {
          return Row(
            children: [
              ElevatedButton(
                onPressed: details.onStepContinue,
                child: Text(
                  _current < 2
                      ? 'Next'
                      : (_finishing ? 'Finishing…' : 'Finish'),
                ),
              ),
              const SizedBox(width: 8),
              if (_current > 0)
                OutlinedButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Back'),
                ),
            ],
          );
        },
        steps: [
          Step(
            title: const Text('Requirements'),
            state: (_ageOk == true && _sopsOk == true)
                ? StepState.complete
                : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      (_ageOk == true) ? Icons.check_circle : Icons.error,
                      color: (_ageOk == true) ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    const Text('age installed'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      (_sopsOk == true) ? Icons.check_circle : Icons.error,
                      color: (_sopsOk == true) ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    const Text('sops installed'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _checking ? null : _recheck,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Recheck'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Setup'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ageKeyCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Age identity file path',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _pickAgeKey,
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
                        controller: _rootCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Project root directory',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _pickRoot,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Browse'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _pubKeyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Public key (optional)',
                  ),
                ),
              ],
            ),
          ),
          Step(title: const Text('Confirm'), content: _buildConfirm()),
        ],
      ),
    );
  }

  Widget _buildConfirm() {
    final added = _desiredRecipients.difference(_currentRecipients);
    final removed = _currentRecipients.difference(_desiredRecipients);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detected patterns:'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _patterns.isEmpty
              ? [const Chip(label: Text('(none)'))]
              : _patterns.map((p) => Chip(label: Text(p))).toList(),
        ),
        const SizedBox(height: 12),
        Text('Files matched: $_matchedCount'),
        const SizedBox(height: 12),
        const Text('Recipients preview diff:'),
        const SizedBox(height: 6),
        if (added.isEmpty && removed.isEmpty)
          const Text('No changes to recipients')
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (added.isNotEmpty) ...[
                const Text('To be ADDED:'),
                ...added.map((e) => Text('  + $e')),
              ],
              if (removed.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('To be REMOVED:'),
                ...removed.map((e) => Text('  - $e')),
              ],
            ],
          ),
      ],
    );
  }
}
