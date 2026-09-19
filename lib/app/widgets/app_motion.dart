import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';

/// Scale + haptic feedback for tappable surfaces.
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    required this.onTap,
    this.enabled = true,
    this.minScale = 0.97,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double minScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  var _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.enabled && widget.onTap != null
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? widget.minScale : 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Entrance fade + slight rise for list sections.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    required this.child,
    this.delay = Duration.zero,
    this.offset = 12,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        // Delay approximated by clamping progress.
        final t = delay == Duration.zero
            ? value
            : ((value - 0.15).clamp(0.0, 1.0));
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, offset * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class AppShimmerBox extends StatefulWidget {
  const AppShimmerBox({
    this.height = 88,
    this.borderRadius = 12,
    super.key,
  });

  final double height;
  final double borderRadius;

  @override
  State<AppShimmerBox> createState() => _AppShimmerBoxState();
}

class _AppShimmerBoxState extends State<AppShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainer;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.2 + _controller.value * 2.4, 0),
              end: Alignment(-0.2 + _controller.value * 2.4, 0),
              colors: [
                base,
                AppColors.accent.withValues(alpha: 0.08),
                base,
              ],
            ),
          ),
        );
      },
    );
  }
}
