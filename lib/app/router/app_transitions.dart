import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

CustomTransitionPage<T> fadePage<T>({
  required LocalKey key,
  required Widget child,
  Duration duration = const Duration(milliseconds: 280),
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: curve, child: child);
    },
  );
}

CustomTransitionPage<T> sharedAxisPage<T>({
  required LocalKey key,
  required Widget child,
  Axis axis = Axis.horizontal,
  Duration duration = const Duration(milliseconds: 320),
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final offset = switch (axis) {
        Axis.horizontal => Offset(0.04 * (1 - curve.value), 0),
        Axis.vertical => Offset(0, 0.04 * (1 - curve.value)),
      };
      return FadeTransition(
        opacity: curve,
        child: Transform.translate(
          offset: Offset(
            offset.dx * MediaQuery.sizeOf(context).width,
            offset.dy * MediaQuery.sizeOf(context).height,
          ),
          child: child,
        ),
      );
    },
  );
}
