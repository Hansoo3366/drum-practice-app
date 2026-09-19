import 'package:page_a_diddle/l10n/app_localizations.dart';

/// Human-readable relative time for recent lists.
String formatRelativeTime(
  DateTime time,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  final anchor = now ?? DateTime.now();
  final diff = anchor.difference(time);
  if (diff.inMinutes < 1) return l10n.relativeJustNow;
  if (diff.inMinutes < 60) return l10n.relativeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.relativeHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.relativeDaysAgo(diff.inDays);
  return l10n.relativeMonthDay(time.month, time.day);
}
