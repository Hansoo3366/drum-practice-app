import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Text(
            title,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 3, width: 48, color: AppColors.accent),
          const SizedBox(height: 20),
          Text(
            body,
            style: textTheme.bodyLarge?.copyWith(
              height: 1.55,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
