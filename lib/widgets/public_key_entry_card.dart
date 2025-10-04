import 'package:flutter/material.dart';

import '../models/public_key_entry.dart';

class PublicKeyEntryCard extends StatelessWidget {
  final PublicKeyEntry entry;
  final bool busy;
  final VoidCallback onRemove;

  const PublicKeyEntryCard({
    super.key,
    required this.entry,
    required this.busy,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          spacing: 8.0,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: entry.key,
                    decoration: const InputDecoration(
                      labelText: 'key (age1...)',
                    ),
                    onChanged: (v) => entry.key = v.trim(),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: busy ? null : onRemove,
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      const allowed = ['user', 'cluster'];
                      if (!allowed.contains(entry.ownerType)) {
                        entry.ownerType = 'user';
                      }
                      return DropdownButtonFormField<String>(
                        value: entry.ownerType,
                        decoration: const InputDecoration(
                          labelText: 'ownerType',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'user', child: Text('user')),
                          DropdownMenuItem(
                            value: 'cluster',
                            child: Text('cluster'),
                          ),
                        ],
                        onChanged: busy
                            ? null
                            : (v) {
                                if (v == null) return;
                                entry.ownerType = v;
                                setState(() {});
                              },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: entry.owner,
                    decoration: const InputDecoration(labelText: 'owner'),
                    onChanged: (v) => entry.owner = v.trim(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
