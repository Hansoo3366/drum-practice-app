import 'package:page_a_diddle/core/session/jam_session.dart';
import 'package:page_a_diddle/l10n/app_localizations.dart';

abstract final class JamSessionErrorKeys {
  static const noSession = 'jamSessionNotFound';
  static const setlistNotFound = 'setlistNotFound';
  static const notReady = JamSessionException.notReady;
}

String jamSessionErrorMessage(
  AppLocalizations l10n,
  JamSessionException error,
) {
  return switch (error.message) {
    JamSessionErrorKeys.noSession => l10n.jamSessionNotFound,
    JamSessionErrorKeys.setlistNotFound => l10n.setlistNotFound,
    JamSessionErrorKeys.notReady => l10n.jamNotReady,
    JamSessionException.networkUnavailable => l10n.jamNetworkUnavailable,
    JamSessionException.joinTimedOut => l10n.jamJoinTimedOut,
    JamSessionException.hostUnavailable => l10n.jamHostUnavailable,
    _ => error.message,
  };
}
