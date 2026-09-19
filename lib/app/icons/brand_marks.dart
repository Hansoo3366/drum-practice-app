import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';

/// Brand marks for import sources.
///
/// Cloud logos are Simple Icons (CC0). Using a mark to label that service
/// (nominative use) is normal; we do not claim affiliation.
abstract final class BrandMarks {
  static const size = 28.0;

  static Widget device({double size = size}) => _Shell(
    size: size,
    color: const Color(0xFF303033),
    child: Icon(
      Icons.smartphone_rounded,
      size: size * 0.62,
      color: Colors.white,
    ),
  );

  static Widget googleDrive({double size = size}) =>
      _SvgMark(asset: 'assets/brands/google_drive.svg', size: size);

  static Widget dropbox({double size = size}) =>
      _SvgMark(asset: 'assets/brands/dropbox.svg', size: size);

  static Widget webDav({double size = size}) => _Shell(
    size: size,
    color: AppColors.accent,
    child: Icon(Icons.dns_rounded, size: size * 0.58, color: Colors.white),
  );
}

class _SvgMark extends StatelessWidget {
  const _SvgMark({required this.asset, required this.size});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(asset, width: size, height: size),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.size, required this.color, required this.child});

  final double size;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: child,
    );
  }
}
