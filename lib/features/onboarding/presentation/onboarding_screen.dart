import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_brand_mark.dart';
import 'package:page_a_diddle/app/widgets/app_surfaces.dart';
import 'package:page_a_diddle/features/onboarding/data/onboarding_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  var _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    unawaited(HapticFeedback.mediumImpact());
    await ref.read(onboardingCompletedProvider.notifier).complete();
    if (mounted) context.go('/home');
  }

  void _next(int lastIndex) {
    unawaited(HapticFeedback.selectionClick());
    if (_index >= lastIndex) {
      unawaited(_finish());
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final pages = [
      (l10n.onboardTitle1, l10n.onboardBody1),
      (l10n.onboardTitle2, l10n.onboardBody2),
      (l10n.onboardTitle3, l10n.onboardBody3),
    ];
    final lastIndex = pages.length - 1;
    final isLast = _index >= lastIndex;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: AppColors.ink)),
          const AppRhythmBackdrop(),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      unawaited(_finish());
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.canvas.withValues(alpha: 0.7),
                    ),
                    child: Text(l10n.onboardingSkip),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: pages.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, index) {
                      final (title, body) = pages[index];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.92, end: 1),
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 520),
                              curve: Curves.easeOutBack,
                              builder: (context, scale, child) {
                                return Transform.scale(
                                  scale: scale,
                                  child: child,
                                );
                              },
                              child: const AppBrandMark(size: 64),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              l10n.appName,
                              style: textTheme.labelLarge?.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              style: textTheme.displaySmall?.copyWith(
                                color: AppColors.canvas,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                fontSize: 34,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              body,
                              style: textTheme.bodyLarge?.copyWith(
                                color: AppColors.canvas.withValues(alpha: 0.78),
                                height: 1.45,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: Row(
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < pages.length; i++)
                            AnimatedContainer(
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 240),
                              margin: const EdgeInsets.only(right: 6),
                              width: i == _index ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _index
                                    ? AppColors.accent
                                    : AppColors.canvas.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => _next(lastIndex),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.ink,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 14,
                          ),
                        ),
                        child: Text(
                          isLast ? l10n.onboardingStart : l10n.onboardingNext,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
