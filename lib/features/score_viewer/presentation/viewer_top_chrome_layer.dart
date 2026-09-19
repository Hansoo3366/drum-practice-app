import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';

/// Top chrome flush to the physical top (fills status-bar inset).
/// When hidden, slides fully off-screen with no leftover title strip.
class ViewerTopChromeLayer extends StatelessWidget {
  const ViewerTopChromeLayer({
    required this.chromeVisible,
    required this.topBar,
    required this.onReveal,
    super.key,
  });

  final bool chromeVisible;
  final PreferredSizeWidget topBar;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final barHeight = topBar.preferredSize.height;
    final chromeHeight = barHeight + topInset;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: AnimatedSlide(
              offset: chromeVisible ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: IgnorePointer(
                ignoring: !chromeVisible,
                child: ColoredBox(
                  color: AppColors.stage,
                  child: SizedBox(
                    height: chromeHeight,
                    child: Padding(
                      padding: EdgeInsets.only(top: topInset),
                      child: SizedBox(height: barHeight, child: topBar),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!chromeVisible)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + 72,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onReveal,
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }
}
