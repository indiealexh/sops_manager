import 'package:flutter/material.dart';

class ResponsiveActionBar extends StatelessWidget {
  final List<Widget> children;
  const ResponsiveActionBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}
