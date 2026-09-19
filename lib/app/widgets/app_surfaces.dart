import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_motion.dart';

/// Subtle beat-line texture — use inside a [Stack].
class AppRhythmBackdrop extends StatelessWidget {
  const AppRhythmBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _RhythmPainter(color: AppColors.accent.withValues(alpha: 0.07)),
      ),
    );
  }
}

class _RhythmPainter extends CustomPainter {
  const _RhythmPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final x = size.width * (0.08 + i * 0.085);
      final h = 24 + (i % 3) * 18;
      canvas.drawLine(
        Offset(x, size.height - h),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RhythmPainter oldDelegate) => false;
}

/// Spotify / Apple Music style continue card.
class AppContinueCard extends StatelessWidget {
  const AppContinueCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.bpm,
    this.footnote,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int? bpm;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PressableScale(
      onTap: onTap,
      child: Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const AppRhythmBackdrop(),
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.22),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.continuePractice,
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.canvas,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.canvas.withValues(alpha: 0.72),
                          ),
                        ),
                        if (footnote case final note?)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: AppColors.accent.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (bpm case final value?)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$value',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Square feature tile for home / tools grids.
class AppFeatureTile extends StatelessWidget {
  const AppFeatureTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.featured = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      child: Material(
        color: featured ? AppColors.ink : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: featured
                      ? AppColors.accent.withValues(alpha: 0.25)
                      : AppColors.canvas,
                  borderRadius: BorderRadius.circular(10),
                  border: featured ? null : Border.all(color: colors.outline),
                ),
                child: Icon(icon, size: 20, color: AppColors.accent),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: featured ? AppColors.canvas : null,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: featured
                        ? AppColors.canvas.withValues(alpha: 0.7)
                        : colors.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
