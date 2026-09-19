import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/branding/app_branding.dart';

/// App mark used in navigation rail, home, settings, onboarding.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({this.size = 44, super.key});

  static const assetPath = 'assets/icons/app_icon.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.22;

    return Semantics(
      label: AppBranding.appName,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
