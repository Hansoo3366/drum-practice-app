import 'package:uuid/uuid.dart';

/// Hashtag-style label: strip `#`, trim, lowercase.
String normalizeLabelName(String raw) {
  var value = raw.trim();
  while (value.startsWith('#')) {
    value = value.substring(1).trimLeft();
  }
  return value.toLowerCase();
}

String newLibraryId() => const Uuid().v4();
