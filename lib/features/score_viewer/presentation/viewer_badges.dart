import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';

/// Overlay badge for difficult measures.
class ViewerHardBadge extends StatelessWidget {
  const ViewerHardBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xD9111214)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          context.l10n.hardBadge,
          style: const TextStyle(
            color: Color(0xFFFFC107),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Overlay badge for performance cues.
class ViewerCueBadge extends StatelessWidget {
  const ViewerCueBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xD9111214)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFFFC107),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
