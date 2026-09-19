import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';

const appWideLayoutBreakpoint = 760.0;

/// Centered content column with consistent padding.
class AppScreen extends StatelessWidget {
  const AppScreen({
    required this.child,
    this.maxWidth = 720,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 28),
    this.scrollable = true,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final body = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: scrollable
            ? SingleChildScrollView(padding: padding, child: child)
            : Padding(padding: padding, child: child),
      ),
    );
    return SafeArea(child: body);
  }
}

class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// Compact navigation row used on Tools / Home style lists.
class AppNavRow extends StatelessWidget {
  const AppNavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: colors.onSurface),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useStage = false,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: useStage
        ? AppColors.stageElevated
        : Theme.of(context).colorScheme.surface,
    showDragHandle: true,
    isScrollControlled: isScrollControlled,
    builder: (sheetContext) {
      final child = builder(sheetContext);
      if (!useStage) {
        return child;
      }
      return Theme(data: AppTheme.stage, child: child);
    },
  );
}

/// Circular transport control (play / stop).
class AppPlayButton extends StatelessWidget {
  const AppPlayButton({
    required this.playing,
    required this.onPressed,
    this.size = 64,
    this.tooltip,
    super.key,
  });

  final bool playing;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size(size, size),
        maximumSize: Size(size, size),
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.canvas,
      ),
      child: Icon(
        playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
        size: size * 0.42,
      ),
    );
    if (tooltip == null) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}
