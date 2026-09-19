import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_motion.dart';
import 'package:page_a_diddle/features/score_viewer/presentation/viewer_chrome.dart';

/// Floating coaching hint on the viewer surface.
class ViewerFloatingHint extends StatelessWidget {
  const ViewerFloatingHint({
    required this.icon,
    required this.message,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: kViewerChromeFill,
      elevation: 0,
      shape: const StadiumBorder(
        side: BorderSide(color: kViewerChromeBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return child;
    return PressableScale(onTap: onTap, child: child);
  }
}
