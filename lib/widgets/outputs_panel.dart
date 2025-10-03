import 'package:flutter/material.dart';

class OutputsPanel extends StatelessWidget {
  final String text;
  const OutputsPanel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 80, maxHeight: 240),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(child: Text(text)),
    );
  }
}
