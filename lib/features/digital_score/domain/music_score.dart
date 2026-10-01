enum PitchStep { c, d, e, f, g, a, b }

extension PitchStepMusicXml on PitchStep {
  String get musicXmlName => name.toUpperCase();

  int get naturalSemitone => switch (this) {
    PitchStep.c => 0,
    PitchStep.d => 2,
    PitchStep.e => 4,
    PitchStep.f => 5,
    PitchStep.g => 7,
    PitchStep.a => 9,
    PitchStep.b => 11,
  };

  static PitchStep parse(String value) {
    return switch (value.trim().toUpperCase()) {
      'C' => PitchStep.c,
      'D' => PitchStep.d,
      'E' => PitchStep.e,
      'F' => PitchStep.f,
      'G' => PitchStep.g,
      'A' => PitchStep.a,
      'B' => PitchStep.b,
      _ => throw FormatException('Invalid pitch step: $value'),
    };
  }
}

class MusicScore {
  MusicScore({
    required List<MusicPart> parts,
    this.title,
    this.composer,
    this.tempoBpm,
    this.musicXmlVersion = '4.0',
  }) : parts = List.unmodifiable(parts) {
    if (parts.isEmpty) {
      throw const FormatException('A score must contain at least one part.');
    }
    if (tempoBpm != null && tempoBpm! <= 0) {
      throw const FormatException('Tempo must be greater than zero.');
    }
  }

  final String? title;
  final String? composer;
  final double? tempoBpm;
  final String musicXmlVersion;
  final List<MusicPart> parts;

  MusicScore copyWith({
    List<MusicPart>? parts,
    String? title,
    String? composer,
    double? tempoBpm,
    String? musicXmlVersion,
  }) {
    return MusicScore(
      parts: parts ?? this.parts,
      title: title ?? this.title,
      composer: composer ?? this.composer,
      tempoBpm: tempoBpm ?? this.tempoBpm,
      musicXmlVersion: musicXmlVersion ?? this.musicXmlVersion,
    );
  }

  int get measureCount => parts.fold<int>(
    0,
    (maximum, part) =>
        part.measures.length > maximum ? part.measures.length : maximum,
  );

  int get noteCount => parts.fold<int>(
    0,
    (sum, part) =>
        sum +
        part.measures.fold<int>(
          0,
          (measureSum, measure) => measureSum + measure.notes.length,
        ),
  );
}

class MusicPart {
  MusicPart({
    required this.id,
    required this.name,
    required List<MusicMeasure> measures,
  }) : measures = List.unmodifiable(measures) {
    if (id.trim().isEmpty) {
      throw const FormatException('A part id is required.');
    }
    if (measures.isEmpty) {
      throw const FormatException('A part must contain at least one measure.');
    }
  }

  final String id;
  final String name;
  final List<MusicMeasure> measures;

  MusicPart copyWith({String? id, String? name, List<MusicMeasure>? measures}) {
    return MusicPart(
      id: id ?? this.id,
      name: name ?? this.name,
      measures: measures ?? this.measures,
    );
  }
}

class MusicMeasure {
  MusicMeasure({
    required this.number,
    required this.attributes,
    required List<MusicEvent> events,
    this.implicit = false,
    List<MusicBarline> barlines = const [],
  }) : events = List.unmodifiable(events),
       barlines = List.unmodifiable(barlines) {
    if (number.trim().isEmpty) {
      throw const FormatException('A measure number is required.');
    }
  }

  final String number;
  final MusicAttributes attributes;
  final List<MusicEvent> events;
  final bool implicit;

  /// Written `<barline>` elements (repeats, endings, double bars), kept so
  /// saving through the codec does not drop them.
  final List<MusicBarline> barlines;

  MusicMeasure copyWith({
    String? number,
    MusicAttributes? attributes,
    List<MusicEvent>? events,
    bool? implicit,
    List<MusicBarline>? barlines,
  }) {
    return MusicMeasure(
      number: number ?? this.number,
      attributes: attributes ?? this.attributes,
      events: events ?? this.events,
      implicit: implicit ?? this.implicit,
      barlines: barlines ?? this.barlines,
    );
  }

  /// Jump marks written in this bar (segno, D.S., To Coda, Fine, ...).
  Set<MusicNavigation> get navigation => {
    for (final direction in events.whereType<MusicDirection>())
      if (direction.navigation case final mark?) mark,
  };

  bool get repeatStart => barlines.any((b) => b.repeat == 'forward');
  bool get repeatEnd => barlines.any((b) => b.repeat == 'backward');

  /// Total passes for a closing repeat (MusicXML `times`, default 2).
  int get repeatTimes {
    for (final barline in barlines) {
      if (barline.repeat == 'backward') return barline.times ?? 2;
    }
    return 1;
  }

  /// Bar lines without repeat signs or ending brackets, for playing a
  /// section exactly as ordered by the user.
  MusicMeasure withoutRepeats() => copyWith(
    barlines: [
      for (final barline in barlines)
        if (barline.repeat == null && barline.endingNumbers.isEmpty) barline,
    ],
  );

  Iterable<MusicNote> get notes => events.whereType<MusicNote>();

  int get durationDivisions => notes.fold<int>(
    0,
    (maximum, note) => note.end > maximum ? note.end : maximum,
  );
}

class MusicAttributes {
  MusicAttributes({
    required this.divisions,
    this.keyFifths = 0,
    this.keyMode,
    this.time,
    this.staves = 1,
    Map<int, MusicClef>? clefs,
  }) : clefs = Map.unmodifiable(clefs ?? const <int, MusicClef>{}) {
    if (divisions <= 0) {
      throw const FormatException('Divisions must be greater than zero.');
    }
    if (staves <= 0) {
      throw const FormatException('Staves must be greater than zero.');
    }
  }

  final int divisions;
  final int keyFifths;
  final String? keyMode;
  final MusicTimeSignature? time;
  final int staves;
  final Map<int, MusicClef> clefs;

  MusicAttributes copyWith({
    int? divisions,
    int? keyFifths,
    String? keyMode,
    MusicTimeSignature? time,
    int? staves,
    Map<int, MusicClef>? clefs,
  }) {
    return MusicAttributes(
      divisions: divisions ?? this.divisions,
      keyFifths: keyFifths ?? this.keyFifths,
      keyMode: keyMode ?? this.keyMode,
      time: time ?? this.time,
      staves: staves ?? this.staves,
      clefs: clefs ?? this.clefs,
    );
  }
}

class MusicTimeSignature {
  const MusicTimeSignature({
    required this.beats,
    required this.beatType,
    this.symbol,
  });

  final int beats;
  final int beatType;
  final MusicTimeSymbol? symbol;
}

enum MusicTimeSymbol { common, cut }

class MusicClef {
  const MusicClef({
    required this.sign,
    required this.line,
    this.octaveChange = 0,
  });

  final String sign;
  final int line;
  final int octaveChange;
}

sealed class MusicEvent {
  const MusicEvent({required this.onset, required this.staff});

  final int onset;
  final int staff;
}

class MusicNote extends MusicEvent {
  MusicNote({
    required super.onset,
    required this.duration,
    required this.voice,
    required super.staff,
    this.pitch,
    this.type,
    this.dots = 0,
    this.isGrace = false,
    this.isChord = false,
    this.tieStart = false,
    this.tieStop = false,
    this.slurStart = false,
    this.slurStop = false,
    this.beams = const [],
    this.lyrics = const [],
  }) {
    if (onset < 0) {
      throw const FormatException('A note onset cannot be negative.');
    }
    if (duration < 0 || (!isGrace && duration == 0)) {
      throw const FormatException('A note duration must be positive.');
    }
    if (voice.trim().isEmpty) {
      throw const FormatException('A note voice is required.');
    }
    if (staff <= 0) {
      throw const FormatException('A note staff must be positive.');
    }
  }

  final int duration;
  final String voice;
  final MusicPitch? pitch;
  final String? type;
  final int dots;
  final bool isGrace;
  final bool isChord;
  final bool tieStart;
  final bool tieStop;
  final bool slurStart;
  final bool slurStop;
  final List<MusicBeam> beams;

  /// Written `<lyric>` elements, kept as-is so saving through the codec does
  /// not drop lyrics.
  final List<String> lyrics;

  bool get isRest => pitch == null;
  int get end => onset + duration;

  MusicNote copyWith({
    int? onset,
    int? duration,
    String? voice,
    int? staff,
    Object? pitch = _notProvided,
    Object? type = _notProvided,
    int? dots,
    bool? isGrace,
    bool? isChord,
    bool? tieStart,
    bool? tieStop,
    bool? slurStart,
    bool? slurStop,
    List<MusicBeam>? beams,
    List<String>? lyrics,
  }) {
    return MusicNote(
      onset: onset ?? this.onset,
      duration: duration ?? this.duration,
      voice: voice ?? this.voice,
      staff: staff ?? this.staff,
      pitch: identical(pitch, _notProvided) ? this.pitch : pitch as MusicPitch?,
      type: identical(type, _notProvided) ? this.type : type as String?,
      dots: dots ?? this.dots,
      isGrace: isGrace ?? this.isGrace,
      isChord: isChord ?? this.isChord,
      tieStart: tieStart ?? this.tieStart,
      tieStop: tieStop ?? this.tieStop,
      slurStart: slurStart ?? this.slurStart,
      slurStop: slurStop ?? this.slurStop,
      beams: beams ?? this.beams,
      lyrics: lyrics ?? this.lyrics,
    );
  }
}

class MusicBeam {
  const MusicBeam({this.number = 1, required this.value});

  final int number;
  final String value;
}

class MusicPitch {
  const MusicPitch({required this.step, required this.octave, this.alter = 0});

  final PitchStep step;
  final int alter;
  final int octave;

  int get midi => (octave + 1) * 12 + step.naturalSemitone + alter;
}

/// Jump marks a player follows: MusicXML `<sound>` attributes, plus the
/// segno and coda signs themselves.
enum MusicNavigation { segno, coda, dalSegno, daCapo, toCoda, fine }

class MusicDirection extends MusicEvent {
  const MusicDirection({
    required super.onset,
    required super.staff,
    this.rehearsal,
    this.words,
    this.tempoBpm,
    this.navigation,
  });

  final String? rehearsal;
  final String? words;
  final double? tempoBpm;
  final MusicNavigation? navigation;

  MusicDirection copyWith({
    int? onset,
    int? staff,
    Object? rehearsal = _notProvided,
    Object? words = _notProvided,
    Object? tempoBpm = _notProvided,
    Object? navigation = _notProvided,
  }) {
    return MusicDirection(
      onset: onset ?? this.onset,
      staff: staff ?? this.staff,
      rehearsal: identical(rehearsal, _notProvided)
          ? this.rehearsal
          : rehearsal as String?,
      words: identical(words, _notProvided) ? this.words : words as String?,
      tempoBpm: identical(tempoBpm, _notProvided)
          ? this.tempoBpm
          : tempoBpm as double?,
      navigation: identical(navigation, _notProvided)
          ? this.navigation
          : navigation as MusicNavigation?,
    );
  }
}

class MusicHarmony extends MusicEvent {
  const MusicHarmony({
    required super.onset,
    required super.staff,
    required this.rootStep,
    this.rootAlter = 0,
    required this.kind,
    this.kindText,
    this.bassStep,
    this.bassAlter = 0,
  });

  final PitchStep rootStep;
  final int rootAlter;
  final String kind;
  final String? kindText;
  final PitchStep? bassStep;
  final int bassAlter;

  MusicHarmony copyWith({
    int? onset,
    int? staff,
    PitchStep? rootStep,
    int? rootAlter,
    String? kind,
    Object? kindText = _notProvided,
    Object? bassStep = _notProvided,
    int? bassAlter,
  }) {
    return MusicHarmony(
      onset: onset ?? this.onset,
      staff: staff ?? this.staff,
      rootStep: rootStep ?? this.rootStep,
      rootAlter: rootAlter ?? this.rootAlter,
      kind: kind ?? this.kind,
      kindText: identical(kindText, _notProvided)
          ? this.kindText
          : kindText as String?,
      bassStep: identical(bassStep, _notProvided)
          ? this.bassStep
          : bassStep as PitchStep?,
      bassAlter: bassAlter ?? this.bassAlter,
    );
  }
}

const Object _notProvided = Object();

/// A MusicXML `<barline>`. [xml] is the element as written; the parsed
/// fields drive playback of repeats and endings.
class MusicBarline {
  const MusicBarline({
    required this.location,
    required this.xml,
    this.repeat,
    this.times,
    this.endingNumbers = const [],
    this.endingType,
  });

  /// `left`, `right` or `middle`.
  final String location;
  final String xml;

  /// `forward` or `backward` for a repeat sign.
  final String? repeat;
  final int? times;

  /// Passes an ending bracket applies to, e.g. [1] or [1, 2].
  final List<int> endingNumbers;

  /// `start`, `stop` or `discontinue`.
  final String? endingType;
}
