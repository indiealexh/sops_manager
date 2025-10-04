import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/public_key_entry.dart';
import '../models/proc_result.dart';
import '../utils/file_path.dart';

class SopsService {
  static String _username() {
    final env = Platform.environment;
    return env['USER'] ?? env['USERNAME'] ?? 'unknown';
  }

  static Future<String?> derivePublicKey(String identityPath) async {
    try {
      final res = await Process.run('age-keygen', ['-y', identityPath]);
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
        out.add(PublicKeyEntry(key: key, ownerType: ownerType, owner: owner));
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
      "  - path_regex: '.*\\.(yaml|yml|json|env)\u001b'".replaceAll(
        '\u001b',
        '',
      ),
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

    // Helper: read path_regex patterns from .sops.yaml at project root.
    Future<List<RegExp>> _readPathRegexps() async {
      final regexps = <RegExp>[];
      try {
        final cfgPath = FilePath.join(root, '.sops.yaml');
        final cfgFile = File(cfgPath);
        if (await cfgFile.exists()) {
          final content = await cfgFile.readAsString();
          final lines = const LineSplitter().convert(content);
          // Matches: path_regex: '...'
          final pattern = RegExp(
            r'path_regex\s*:\s*(?:([\x22\x27])(.*?)\1|(.*))',
          );
          for (final raw in lines) {
            final line = raw.trim();
            final m = pattern.firstMatch(line);
            if (m != null) {
              var value = (m.group(2) ?? m.group(3) ?? '').trim();
              // Trim inline comments for unquoted values only
              if (m.group(2) == null) {
                final hash = value.indexOf(' #');
                if (hash != -1) value = value.substring(0, hash).trim();
              }
              if (value.isNotEmpty) {
                try {
                  regexps.add(RegExp(value));
                } catch (_) {
                  // Skip invalid regex
                }
              }
            }
          }
        }
      } catch (_) {
        // ignore config read/parse errors and use fallback
      }
      if (regexps.isEmpty) {
        // Fallback to the historical default
        regexps.add(RegExp(r'.*\.(yaml|yml|json|env)$'));
      }
      return regexps;
    }

    String _norm(String p) => p.replaceAll('\\', '/');

    final pathRegexps = await _readPathRegexps();

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name == '.sops.yaml' || name == 'public-age-keys.yaml') continue;

        final rel = _relativeTo(root, entity.path);
        final relNorm = _norm(rel);

        bool matches = false;
        for (final re in pathRegexps) {
          if (re.hasMatch(relNorm)) {
            matches = true;
            break;
          }
        }
        if (!matches) continue;

        final len = await entity.length();
        if (len > 5 * 1024 * 1024) continue; // skip very large files
        try {
          final content = await entity.readAsString();
          if (content.contains('\nsops:') || content.contains('"sops"')) {
            // Likely a sops-encrypted file
            result.add(rel);
          }
        } catch (_) {
          // ignore unreadable files
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
    String? identityPath,
  }) async {
    try {
      final env = Map<String, String>.from(Platform.environment);
      if (identityPath != null && identityPath.isNotEmpty) {
        env['SOPS_AGE_KEY_FILE'] = identityPath;
      }
      final res = await Process.run(
        'sops',
        args,
        workingDirectory: cwd,
        environment: env,
      );
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
