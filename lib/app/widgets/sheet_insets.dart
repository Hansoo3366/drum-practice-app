import 'package:flutter/material.dart';

EdgeInsets sheetContentPadding(
  BuildContext context, {
  double horizontal = 16,
  double top = 8,
  double bottom = 16,
}) {
  final media = MediaQuery.of(context);
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    bottom + media.viewPadding.bottom + media.viewInsets.bottom,
  );
}
