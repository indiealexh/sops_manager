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

    // .sops.yaml: create if missing; otherwise only update recipients under existing creation_rules
    final recipients = current.map((e) => e.key).toList();
    final sopsFile = File(sopsPath);
    if (await sopsFile.exists()) {
      final updated = await updateSopsRecipients(sopsPath, recipients);
      msgs.add(
        'Updated recipients in existing .sops.yaml for $updated creation_rule(s).',
      );
    } else {
      await writeSopsConfig(sopsPath, recipients);
      msgs.add('Created .sops.yaml with ${recipients.length} recipient(s).');
    }
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

  static Future<int> updateSopsRecipients(
    String path,
    List<String> recipients,
  ) async {
    final file = File(path);
    if (!await file.exists()) return 0;
    final content = await file.readAsString();
    final lines = const LineSplitter().convert(content);

    int indentOf(String s) => s.length - s.trimLeft().length;
    String indent(int n) => ' ' * n;

    // Find creation_rules:
    int crStart = -1;
    int crIndent = 0;
    for (int i = 0; i < lines.length; i++) {
      final t = lines[i].trimLeft();
      if (t.startsWith('creation_rules:')) {
        crStart = i;
        crIndent = indentOf(lines[i]);
        break;
      }
    }
    if (crStart == -1) {
      // Nothing to update
      return 0;
    }

    // Find end of creation_rules block
    int crEnd = lines.length;
    for (int i = crStart + 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      if (indentOf(line) <= crIndent && !line.trimLeft().startsWith('-')) {
        crEnd = i;
        break;
      }
    }

    // Collect rule ranges [start, end)
    final ruleRanges = <List<int>>[];
    int i = crStart + 1;
    while (i < crEnd) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      final ind = indentOf(line);
      if (trimmed.startsWith('-')) {
        final ruleIndent = ind;
        int j = i + 1;
        while (j < crEnd) {
          final l = lines[j];
          final ltrim = l.trimLeft();
          final lind = indentOf(l);
          if (l.trim().isEmpty) {
            j++;
            continue;
          }
          if (lind <= ruleIndent && ltrim.startsWith('-')) {
            break;
          }
          if (lind <= crIndent && !ltrim.startsWith('-')) {
            break;
          }
          j++;
        }
        ruleRanges.add([i, j]);
        i = j;
        continue;
      }
      i++;
    }

    if (ruleRanges.isEmpty) {
      return 0;
    }

    final newLines = List<String>.from(lines);
    int updatedCount = 0;

    List<String> buildAgeBlock(int indentAge) {
      if (recipients.isEmpty) {
        return [indent(indentAge) + 'age: []'];
      }
      final out = <String>[];
      out.add(indent(indentAge) + 'age:');
      final ir = indentAge + 2;
      for (final r in recipients) {
        out.add(indent(ir) + '- ' + r);
      }
      return out;
    }

    for (int idx = ruleRanges.length - 1; idx >= 0; idx--) {
      final start = ruleRanges[idx][0];
      final end = ruleRanges[idx][1];

      // Find existing age block inside this rule
      int ageStart = -1;
      int ageIndent = 0;
      int scan = start + 1;
      final ruleIndent = indentOf(newLines[start]);
      while (scan < end) {
        final ln = newLines[scan];
        if (ln.trim().isEmpty) {
          scan++;
          continue;
        }
        final t = ln.trimLeft();
        final ind = indentOf(ln);
        if (t.startsWith('age:') && ind >= ruleIndent + 2) {
          ageStart = scan;
          ageIndent = ind;
          break;
        }
        scan++;
      }

      if (ageStart != -1) {
        // Determine end of existing age block
        int k = ageStart + 1;
        while (k < end) {
          final ln = newLines[k];
          if (ln.trim().isEmpty) {
            k++;
            continue;
          }
          final ind = indentOf(ln);
          if (ind <= ageIndent) break;
          k++;
        }
        newLines.removeRange(ageStart, k);
        final block = buildAgeBlock(ageIndent);
        newLines.insertAll(ageStart, block);
        updatedCount++;
      } else {
        // Insert at end of rule block (before trailing blanks)
        int insert = end;
        while (insert - 1 > start && newLines[insert - 1].trim().isEmpty) {
          insert--;
        }
        final block = buildAgeBlock(ruleIndent + 2);
        newLines.insertAll(insert, block);
        updatedCount++;
      }
    }

    await file.writeAsString(newLines.join('\n'));
    return updatedCount;
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
      if (kDebugMode) {
        print(regexps);
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
          result.add(rel);
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
