import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/format/relative_time.dart';
import 'package:page_a_diddle/l10n/app_localizations.dart';

void main() {
  final anchor = DateTime(2026, 8, 24, 12, 0);
  final l10n = lookupAppLocalizations(const Locale('ko'));

  test('formatRelativeTime returns 방금 for under one minute', () {
    expect(
      formatRelativeTime(
        anchor.subtract(const Duration(seconds: 30)),
        l10n,
        now: anchor,
      ),
      '방금',
    );
  });

  test('formatRelativeTime returns minutes', () {
    expect(
      formatRelativeTime(
        anchor.subtract(const Duration(minutes: 12)),
        l10n,
        now: anchor,
      ),
      '12분 전',
    );
  });

  test('formatRelativeTime returns hours', () {
    expect(
      formatRelativeTime(
        anchor.subtract(const Duration(hours: 3)),
        l10n,
        now: anchor,
      ),
      '3시간 전',
    );
  });

  test('formatRelativeTime returns days', () {
    expect(
      formatRelativeTime(
        anchor.subtract(const Duration(days: 2)),
        l10n,
        now: anchor,
      ),
      '2일 전',
    );
  });

  test('formatRelativeTime returns calendar date after a week', () {
    expect(
      formatRelativeTime(DateTime(2026, 8, 10), l10n, now: anchor),
      '8월 10일',
    );
  });
}
