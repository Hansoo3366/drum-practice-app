import 'package:page_a_diddle/l10n/app_localizations.dart';

enum LibraryFilter {
  all,
  favorites,
  recent;

  String label(AppLocalizations l10n) => switch (this) {
    LibraryFilter.all => l10n.filterAll,
    LibraryFilter.favorites => l10n.filterFavorites,
    LibraryFilter.recent => l10n.filterRecent,
  };
}
