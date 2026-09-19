import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_brand_mark.dart';

/// Brief gate while onboarding preference loads.
class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(child: AppBrandMark(size: 56)),
    );
  }
}
