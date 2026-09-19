import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_motion.dart';

/// Composed empty / error invitation — one purpose, one CTA.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 56 : 76,
          height: compact ? 56 : 76,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(compact ? 14 : 18),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                right: -6,
                top: -8,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: 0.28),
                  ),
                ),
              ),
              Icon(icon, size: compact ? 24 : 30, color: AppColors.canvas),
            ],
          ),
        ),
        SizedBox(height: compact ? 14 : 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: (compact ? textTheme.titleMedium : textTheme.titleLarge)
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: compact ? 16 : 22),
          PressableScale(
            onTap: onAction,
            child: FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.ink,
              ),
              child: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 32),
        child: content,
      ),
    );
  }
}
