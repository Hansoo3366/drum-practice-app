part of 'three_staff_arrangement.dart';

// How each instrument plays a bar of a lead sheet, section by section: the
// idiom of a worship-band keyboard, organ, string pad, synth pad and horn
// section, written as rules over the chord symbols.

/// What is carried from bar to bar while a part is written.
class _PartState {
  /// Top note of the last chord, so the next one lies near it.
  int? previousTop;
}

/// Where a bar stands in its section: bars from its first bar, bars to its
/// last (0 on the last bar).
typedef _Place = ({int fromStart, int toEnd});

_Place _placeOf(Map<int, SectionRole> roles, int index, int bars) {
  var start = 0;
  var next = bars;
  for (final key in roles.keys) {
    if (key <= index && key > start) start = key;
    if (key > index && key < next) next = key;
  }
  return (fromStart: index - start, toEnd: next - 1 - index);
}

/// The dynamic written where a part enters a section, or null for none.
String? _dynamicsFor(AccompanimentInstrument instrument, SectionRole role) {
  return switch (instrument) {
    AccompanimentInstrument.piano => switch (role) {
      SectionRole.preChorus ||
      SectionRole.interlude ||
      SectionRole.solo => 'mf',
      SectionRole.chorus => 'f',
      SectionRole.unknown => null,
      _ => 'mp',
    },
    AccompanimentInstrument.organ => switch (role) {
      SectionRole.preChorus ||
      SectionRole.interlude ||
      SectionRole.solo => 'mp',
      SectionRole.chorus => 'mf',
      SectionRole.unknown => null,
      _ => 'p',
    },
    AccompanimentInstrument.strings => switch (role) {
      SectionRole.preChorus => 'mp',
      SectionRole.interlude || SectionRole.solo => 'mf',
      SectionRole.chorus => 'f',
      SectionRole.unknown => null,
      _ => 'p',
    },
    AccompanimentInstrument.pad => switch (role) {
      SectionRole.preChorus || SectionRole.interlude || SectionRole.solo => 'p',
      SectionRole.chorus => 'mp',
      SectionRole.unknown => null,
      _ => 'pp',
    },
    AccompanimentInstrument.brass => switch (role) {
      SectionRole.preChorus ||
      SectionRole.interlude ||
      SectionRole.solo => 'mf',
      SectionRole.chorus || SectionRole.outro => 'f',
      _ => null,
    },
  };
}

/// The piano's pattern for a section when the user leaves it to the song.
AccompanimentPattern _autoPattern(SectionRole role) => switch (role) {
  SectionRole.verse || SectionRole.interlude => AccompanimentPattern.broken,
  SectionRole.preChorus || SectionRole.chorus => AccompanimentPattern.beats,
  _ => AccompanimentPattern.held,
};

/// The chords and basses of one bar of [instrument].
({List<_Strike> chords, List<_Strike> basses}) _writeBar(
  AccompanimentInstrument instrument,
  _Bar bar,
  List<_Segment> segments, {
  required SectionRole role,
  required _Place place,
  required AccompanimentStyle style,
  required _PartState state,
  AccompanimentDensity density = AccompanimentDensity.normal,
  int? splitPoint,
}) {
  final spec = _specs[instrument]!;
  final beat = bar.beatLength;
  final chords = <_Strike>[];
  final basses = <_Strike>[];

  // How many voices, where, and whether the top is doubled an octave up.
  var tones = spec.tones;
  var voices = spec.tones;
  var range = spec.range;
  var octaveTop = false;
  switch (instrument) {
    case AccompanimentInstrument.piano:
      if (style.register == AccompanimentRegister.low ||
          (style.pattern == AccompanimentPattern.auto &&
              role == SectionRole.bridge)) {
        range = _pianoLow;
      }
      // The right hand stays on or above the split point.
      if (splitPoint != null) {
        range = (
          lowestTop: math.max(range.lowestTop, splitPoint),
          highestTop: math.max(range.highestTop, splitPoint + 14),
          lowestBottom: splitPoint,
          target: math.max(range.target, splitPoint + 7),
        );
      }
    case AccompanimentInstrument.organ:
      // Three voices over the bass, four as the song builds; the top
      // doubled in the chorus.
      tones = switch (role) {
        SectionRole.intro ||
        SectionRole.verse ||
        SectionRole.bridge ||
        SectionRole.outro => 3,
        _ => 4,
      };
      voices = tones;
      octaveTop = role == SectionRole.chorus;
    case AccompanimentInstrument.strings:
      // A single held line in the verse, more voices as the song opens up.
      voices = switch (role) {
        SectionRole.intro || SectionRole.verse => 1,
        SectionRole.preChorus || SectionRole.bridge || SectionRole.outro => 2,
        SectionRole.interlude || SectionRole.solo => 3,
        _ => 4,
      };
      if (role == SectionRole.bridge) range = _pianoLow;
      octaveTop = role == SectionRole.chorus;
    case AccompanimentInstrument.pad:
    case AccompanimentInstrument.brass:
      break;
  }
  final pattern = style.pattern == AccompanimentPattern.auto
      ? _autoPattern(role)
      : style.pattern;
  // Light: three notes at most and nothing doubled. Full: every chord tone
  // (up to four) and the octave on top wherever the part holds chords.
  final full = density == AccompanimentDensity.full;
  if (density == AccompanimentDensity.light) {
    tones = math.min(tones, 3);
    voices = math.min(voices, 3);
    octaveTop = false;
  } else if (full) {
    switch (instrument) {
      case AccompanimentInstrument.organ:
        tones = 4;
        voices = 4;
        octaveTop = true;
      case AccompanimentInstrument.strings:
        voices = math.min(4, voices + 1);
        octaveTop = voices >= 3;
      case AccompanimentInstrument.piano:
      case AccompanimentInstrument.pad:
      case AccompanimentInstrument.brass:
        break;
    }
  }

  // Brass rests through the quiet sections and comes in for the last bar,
  // leading into the next.
  final brassRests = switch (role) {
    SectionRole.intro ||
    SectionRole.verse ||
    SectionRole.bridge => place.toEnd > 0,
    _ => false,
  };

  // Strings and pads follow the broad harmony: a chord of under two beats
  // is passed over, so the part moves with the phrase and not with every
  // symbol.
  final played =
      instrument == AccompanimentInstrument.strings ||
          instrument == AccompanimentInstrument.pad
      ? _broadHarmony(segments, 2 * beat, bar.length)
      : segments;
  // The bass of an organ or of strings stays where it is while it still
  // carries the chord (see [_carries]).
  final holdsBass =
      instrument == AccompanimentInstrument.organ ||
      instrument == AccompanimentInstrument.strings;
  _Pitch? heldBass;

  for (final segment in played) {
    final start = segment.start;
    final end = segment.end;
    final chord = segment.chord;
    List<_Pitch> upper = const [];
    _Pitch? bass;
    if (chord != null) {
      if (instrument == AccompanimentInstrument.pad) {
        upper = _padVoicing(chord, role);
        // Light: the open fifth and octave. Full: always with the third.
        if (density == AccompanimentDensity.light && upper.length > 3) {
          upper = upper.sublist(0, 3);
        } else if (full && upper.length == 3) {
          upper = _padVoicing(chord, SectionRole.chorus);
        }
      } else {
        upper = _voiceSegment(
          chord,
          bar,
          start,
          end,
          range: range,
          tones: tones,
          state: state,
        );
        if (upper.length > voices) {
          upper = upper.sublist(upper.length - voices);
        }
        if (octaveTop && upper.isNotEmpty) {
          final top = upper.last;
          final above = _Pitch(top.step, top.alter, top.octave + 1);
          if (above.midi <= 84) upper = [...upper, above];
        }
      }
      bass = _bass(chord);
      final held = heldBass;
      if (holdsBass && held != null && _carries(held, chord)) bass = held;
    }
    heldBass = bass;

    switch (instrument) {
      case AccompanimentInstrument.piano:
        // The left hand plays octaves under a driving chorus, and
        // throughout a full part; never in a light one.
        final octaves =
            density != AccompanimentDensity.light &&
            (full ||
                (role == SectionRole.chorus &&
                    pattern == AccompanimentPattern.beats));
        final low = bass;
        basses.add(
          _Strike(start, end, [
            if (low != null) ...[
              low,
              if (octaves) _Pitch(low.step, low.alter, low.octave + 1),
            ],
          ], restated: segment.restated),
        );
        chords.addAll(
          _pattern(pattern, start, end, upper, bar: bar, beat: beat),
        );
      case AccompanimentInstrument.organ:
      case AccompanimentInstrument.strings:
        basses.add(
          _Strike(start, end, [
            if (bass != null) bass,
          ], restated: segment.restated),
        );
        chords.add(_Strike(start, end, upper, restated: segment.restated));
      case AccompanimentInstrument.pad:
        chords.add(_Strike(start, end, upper, restated: segment.restated));
      case AccompanimentInstrument.brass:
        if (upper.isEmpty || brassRests) {
          chords.add(_Strike(start, end, const []));
          continue;
        }
        if (role == SectionRole.outro && place.toEnd == 0) {
          // The last chord of the song is held.
          chords.add(_Strike(start, end, upper));
          continue;
        }
        chords.addAll(
          _hits(
            _brassOnsets(role, place, start, end, beat),
            start,
            end,
            beat,
            upper,
          ),
        );
    }
  }
  return (chords: chords, basses: basses);
}

/// Whether the bass note [held] can stay under [chord]: it is its root or
/// its third. Under "G/B" after "G" the G stays, and the bass does not walk
/// with every slash chord; under a new root (a fifth away, a step away) it
/// moves, so the harmony is heard to change.
bool _carries(_Pitch held, _Chord chord) {
  final root = chord.rootStep.naturalSemitone + chord.rootAlter;
  final above = ((held.midi - root) % 12 + 12) % 12;
  if (above == 0) return true;
  return chord.tones.any(
    (tone) => tone.letters == 2 && tone.semitones % 12 == above,
  );
}

/// [segments] with every chord shorter than [least] passed over, the
/// shortest first: the chord before it is held on, or at the start of the
/// bar the next chord takes its place. A bar too short for two such chords
/// is left as it is.
List<_Segment> _broadHarmony(
  List<_Segment> segments,
  int least,
  int barLength,
) {
  if (barLength < 2 * least) return segments;
  final out = [...segments];
  while (out.length > 1) {
    var shortest = -1;
    for (var i = 0; i < out.length; i++) {
      final length = out[i].end - out[i].start;
      if (length >= least) continue;
      if (shortest < 0 || length < out[shortest].end - out[shortest].start) {
        shortest = i;
      }
    }
    if (shortest < 0) break;
    final segment = out[shortest];
    if (shortest == 0) {
      final next = out[1];
      out
        ..removeAt(0)
        ..[0] = _Segment(
          segment.start,
          next.end,
          next.chord,
          restated: next.restated,
        );
    } else {
      final before = out[shortest - 1];
      out
        ..[shortest - 1] = _Segment(
          before.start,
          segment.end,
          before.chord,
          restated: before.restated,
        )
        ..removeAt(shortest);
    }
  }
  return out;
}

/// Where the brass strikes a chord sounding from [start] to [end].
List<int> _brassOnsets(
  SectionRole role,
  _Place place,
  int start,
  int end,
  int beat,
) {
  if (role == SectionRole.chorus) {
    if (place.toEnd == 0) {
      // The last bar of the chorus drives on every beat.
      return [for (var at = start; at < end; at += beat) at];
    }
    // On the chord, and again on the third beat of a chord that lasts.
    return [start, if (end - start >= 3 * beat) start + 2 * beat];
  }
  return [start];
}

/// Hits of one beat at [onsets], rests between them, over [start]..[end].
List<_Strike> _hits(
  List<int> onsets,
  int start,
  int end,
  int beat,
  List<_Pitch> pitches,
) {
  final strikes = <_Strike>[];
  var position = start;
  for (final onset in onsets) {
    if (onset < position || onset >= end) continue;
    if (onset > position) strikes.add(_Strike(position, onset, const []));
    // To the next beat when the chord comes off the beat.
    final stop = math.min(end, (onset ~/ beat + 1) * beat);
    strikes.add(_Strike(onset, stop, pitches));
    position = stop;
  }
  if (position < end) strikes.add(_Strike(position, end, const []));
  return strikes;
}

/// The chord in close position for the stretch [start]..[end] of [bar],
/// under the melody where that fits and clear of its held notes.
List<_Pitch> _voiceSegment(
  _Chord chord,
  _Bar bar,
  int start,
  int end, {
  required _Range range,
  required int tones,
  required _PartState state,
}) {
  final beat = bar.beatLength;
  int? melodyLow;
  for (final note in bar.melody) {
    if (note.onset < end && note.end > start) {
      melodyLow = math.min(melodyLow ?? note.midi, note.midi);
    }
  }
  var voicing = _voicing(
    chord,
    range: range,
    tones: tones,
    below: melodyLow,
    near: state.previousTop,
  );
  if (voicing.isNotEmpty) state.previousTop = voicing.last.midi;
  // A chord tone a semitone from a melody note held for a beat or more
  // grates against it: the melody has that place.
  final clear = [
    for (final pitch in voicing)
      if (!bar.melody.any(
        (note) =>
            (note.midi - pitch.midi).abs() == 1 &&
            math.min(end, note.end) - math.max(start, note.onset) >= beat,
      ))
        pitch,
  ];
  if (clear.length >= 2) voicing = clear;
  return voicing;
}

/// A synth pad's wide voicing: the root in the small octave, the fifth, the
/// root again, and the third (or the suspended tone) on top once the song
/// opens up. In a bridge only the open fifth.
List<_Pitch> _padVoicing(_Chord chord, SectionRole role) {
  _Pitch root = _Pitch(chord.rootStep, chord.rootAlter, 3);
  if (root.midi < 48) root = _Pitch(root.step, root.alter, 4);
  if (root.midi > 59) root = _Pitch(root.step, root.alter, 2);
  _Tone? find(bool Function(_Tone) test) => chord.tones.where(test).firstOrNull;
  final fifth = find((t) => t.letters == 4) ?? (letters: 4, semitones: 7);
  final third =
      find((t) => t.letters == 2) ??
      find((t) => t.letters == 3) ??
      find((t) => t.letters == 1);
  _Pitch above(_Pitch lower, _Tone tone) {
    final (step, alter) = _spell(chord.rootStep, chord.rootAlter, tone);
    for (var octave = lower.octave; octave <= lower.octave + 2; octave++) {
      final pitch = _Pitch(step, alter, octave);
      if (pitch.midi > lower.midi) return pitch;
    }
    return _Pitch(step, alter, lower.octave + 1);
  }

  final fifthPitch = above(root, fifth);
  if (role == SectionRole.bridge) return [root, fifthPitch];
  final octave = _Pitch(root.step, root.alter, root.octave + 1);
  final extra = switch (role) {
    SectionRole.intro || SectionRole.verse || SectionRole.outro => null,
    _ => third,
  };
  return [root, fifthPitch, octave, if (extra != null) above(octave, extra)];
}
