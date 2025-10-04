import 'package:flutter/material.dart';

import '../models/log_entry.dart';

class LogView extends StatefulWidget {
  final List<LogEntry> entries;
  final void Function()? onClear;
  final void Function()? onCopy;
  const LogView({super.key, required this.entries, this.onClear, this.onCopy});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  bool _autoScroll = true;
  String _level = 'ALL'; // ALL/INFO/WARN/ERROR
  String _query = '';
  final _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(covariant LogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && _scrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Color _levelColor(String level, ThemeData theme) {
    switch (level) {
      case 'ERROR':
        return Colors.red.shade400;
      case 'WARN':
        return Colors.orange.shade600;
      case 'INFO':
        return theme.colorScheme.secondary;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.entries.where((e) {
      if (_level != 'ALL' && e.level != _level) return false;
      if (_query.isNotEmpty &&
          !e.message.toLowerCase().contains(_query.toLowerCase()))
        return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              value: _level,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All')),
                DropdownMenuItem(value: 'INFO', child: Text('Info')),
                DropdownMenuItem(value: 'WARN', child: Text('Warn')),
                DropdownMenuItem(value: 'ERROR', child: Text('Error')),
              ],
              onChanged: (v) => setState(() => _level = v ?? 'ALL'),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search message',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            FilterChip(
              label: const Text('Autoscroll'),
              selected: _autoScroll,
              onSelected: (v) => setState(() => _autoScroll = v),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: widget.onClear,
              icon: const Icon(Icons.clear),
              label: const Text('Clear'),
            ),
            TextButton.icon(
              onPressed: widget.onCopy,
              icon: const Icon(Icons.copy_all),
              label: const Text('Copy'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              controller: _scrollCtrl,
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final e = filtered[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 84,
                        child: Text(
                          _fmtTs(e.ts),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: _levelColor(e.level, theme).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          e.level,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _levelColor(e.level, theme),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.message)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _fmtTs(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}
