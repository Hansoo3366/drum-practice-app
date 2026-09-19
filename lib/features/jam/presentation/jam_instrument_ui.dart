import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/core/session/jam_session.dart';

String jamInstrumentLabel(
  AppLocalizations l10n,
  JamInstrument instrument, {
  String? custom,
}) {
  if (instrument == JamInstrument.other && custom != null) {
    final value = custom.trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return switch (instrument) {
    JamInstrument.vocal => l10n.jamPartVocal,
    JamInstrument.guitar => l10n.jamPartGuitar,
    JamInstrument.bass => l10n.jamPartBass,
    JamInstrument.drums => l10n.jamPartDrums,
    JamInstrument.keyboard => l10n.jamPartKeyboard,
    JamInstrument.other => l10n.jamPartOther,
  };
}

IconData jamInstrumentIcon(JamInstrument instrument) {
  return switch (instrument) {
    JamInstrument.vocal => Icons.mic_none_rounded,
    JamInstrument.guitar => Icons.music_note_rounded,
    JamInstrument.bass => Icons.graphic_eq_rounded,
    JamInstrument.drums => Icons.album_rounded,
    JamInstrument.keyboard => Icons.keyboard_rounded,
    JamInstrument.other => Icons.more_horiz_rounded,
  };
}
