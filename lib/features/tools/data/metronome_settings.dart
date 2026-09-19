import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/features/tools/domain/metronome_sequence.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'metronome_settings_v1';

int _intOr(Object? value, int fallback) =>
    value is num && value.isFinite ? value.toInt() : fallback;

class MetronomeSettings {
  const MetronomeSettings({
    this.bpm = 120,
    this.meter = const MetronomeMeter(4, 4),
    this.subdivision = MetronomeSubdivision.quarter,
    this.accents = const [
      MetronomeAccentLevel.strong,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
    ],
    this.countInBars = 1,
    this.haptics = true,
  });

  final int bpm;
  final MetronomeMeter meter;
  final MetronomeSubdivision subdivision;
  final List<MetronomeAccentLevel> accents;
  final int countInBars;
  final bool haptics;

  MetronomeSettings copyWith({
    int? bpm,
    MetronomeMeter? meter,
    MetronomeSubdivision? subdivision,
    List<MetronomeAccentLevel>? accents,
    int? countInBars,
    bool? haptics,
  }) {
    return MetronomeSettings(
      bpm: bpm ?? this.bpm,
      meter: meter ?? this.meter,
      subdivision: subdivision ?? this.subdivision,
      accents: accents ?? this.accents,
      countInBars: countInBars ?? this.countInBars,
      haptics: haptics ?? this.haptics,
    );
  }

  Map<String, Object> toJson() => {
    'bpm': bpm,
    'num': meter.numerator,
    'den': meter.denominator,
    'sub': subdivision.name,
    'accents': accents.map((a) => a.index).toList(),
    'countIn': countInBars,
    'haptics': haptics,
  };

  static MetronomeSettings fromJson(Map<String, Object?> json) {
    final accentsRaw = json['accents'];
    final accents = accentsRaw is List
        ? accentsRaw
              .whereType<num>()
              .where((value) => value.isFinite)
              .map(
                (value) =>
                    MetronomeAccentLevel.values[value
                        .toInt()
                        .clamp(0, MetronomeAccentLevel.values.length - 1)
                        .toInt()],
              )
              .toList()
        : const MetronomeSettings().accents;
    final subName = json['sub'] is String ? json['sub'] as String : null;
    final subdivision = MetronomeSubdivision.values.firstWhere(
      (value) => value.name == subName,
      orElse: () => MetronomeSubdivision.quarter,
    );
    final meter = MetronomeMeter(
      _intOr(json['num'], 4).clamp(1, 12),
      _intOr(json['den'], 4).clamp(1, 16),
    );
    final padded = List.generate(
      meter.numerator,
      (index) =>
          index < accents.length ? accents[index] : MetronomeAccentLevel.normal,
    );
    return MetronomeSettings(
      bpm: _intOr(json['bpm'], 120).clamp(40, 240),
      meter: meter,
      subdivision: subdivision,
      accents: padded,
      countInBars: normalizeMetronomeCountInBars(
        _intOr(json['countIn'], const MetronomeSettings().countInBars),
      ),
      haptics: json['haptics'] is bool ? json['haptics'] as bool : true,
    );
  }
}

class MetronomeSettingsController extends Notifier<MetronomeSettings> {
  @override
  MetronomeSettings build() {
    _load();
    return const MetronomeSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        state = MetronomeSettings.fromJson(decoded.cast<String, Object?>());
      }
    } on Object catch (_) {
      // Keep defaults when prefs are corrupt.
    }
  }

  Future<void> update(MetronomeSettings settings) async {
    state = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(settings.toJson()));
  }

  Future<void> patch({
    int? bpm,
    MetronomeMeter? meter,
    MetronomeSubdivision? subdivision,
    List<MetronomeAccentLevel>? accents,
    int? countInBars,
    bool? haptics,
  }) {
    return update(
      state.copyWith(
        bpm: bpm,
        meter: meter,
        subdivision: subdivision,
        accents: accents,
        countInBars: countInBars,
        haptics: haptics,
      ),
    );
  }
}

final metronomeSettingsProvider =
    NotifierProvider<MetronomeSettingsController, MetronomeSettings>(
      MetronomeSettingsController.new,
    );
