part of 'xml_measure_editor.dart';

// The finer points of a score a notation program lets a hand reach:
// fingerings, the other spelling of a note, the slash of a grace note, a
// pickup bar, beams, how many bars stand on a line, a chord tone by its
// pitch, and a run of notes copied to another place. Pure like the rest of
// [XmlMeasureEditor]: a [FormatException] carries the message for an edit
// that cannot be made.

/// A run of notes taken with [XmlMeasureTouches.copyNotes]: each note,
/// chord or rest with its value, in order.
class NoteClip {
  const NoteClip._(this._events);

  final List<({List<MusicPitch> pitches, String type, int dots})> _events;

  /// How many notes, chords and rests it holds.
  int get length => _events.length;
}

extension XmlMeasureTouches on XmlMeasureEditor {
  /// Writes the finger (1 to 5) a note is played with, in place of one
  /// already there; null takes it away. Each note of a chord has its own.
  XmlEditResult setFingering(String xml, XmlNoteRef ref, int? finger) {
    if (finger != null && (finger < 1 || finger > 5)) {
      throw const FormatException('손가락 번호는 1부터 5까지입니다.');
    }
    final doc = _ScoreDoc(xml);
    final info = doc.measure(ref).note(ref.noteIndex);
    if (info.isRest) {
      throw const FormatException('쉼표에는 손가락 번호를 붙일 수 없습니다.');
    }
    if (info.isGrace || info.isCue) {
      throw const FormatException('꾸밈음에는 손가락 번호를 붙일 수 없습니다.');
    }
    final notations = _notationsOf(info.element);
    var technical = notations.getElement('technical');
    final written = technical?.findElements('fingering').toList() ?? const [];
    if (finger == null && written.isEmpty) {
      if (notations.childElements.isEmpty) _remove(notations);
      throw const FormatException('지울 손가락 번호가 없습니다.');
    }
    written.forEach(_remove);
    if (finger != null) {
      if (technical == null) {
        technical = XmlElement(XmlName('technical'));
        notations.children.add(technical);
      }
      technical.children.add(
        XmlElement(XmlName('fingering'), [], [XmlText('$finger')]),
      );
    }
    if (technical != null && technical.childElements.isEmpty) {
      _remove(technical);
    }
    if (notations.childElements.isEmpty) _remove(notations);
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Writes the selected note the other way it can be spelled: F sharp as
  /// G flat and back, E as F flat, C as B sharp. It sounds as before.
  XmlEditResult respell(String xml, XmlNoteRef ref) {
    return _editPitch(xml, ref, (doc, measure, info) {
      final pitch = info.pitch!;
      MusicPitch by(int steps) {
        final number = pitch.octave * 7 + pitch.step.index + steps;
        final step = PitchStep.values[number % 7];
        final octave = number ~/ 7;
        return MusicPitch(
          step: step,
          octave: octave,
          alter:
              pitch.midi -
              MusicPitch(step: step, octave: octave, alter: 0).midi,
        );
      }

      final up = by(1);
      final down = by(-1);
      // A sharp is the flat of the note above, a flat the sharp of the
      // note below; a plain note takes the neighbour a half step away.
      final next = pitch.alter > 0
          ? up
          : pitch.alter < 0
          ? down
          : (up.alter.abs() <= down.alter.abs() ? up : down);
      if (next.alter.abs() > 2) {
        throw const FormatException('다르게 적을 수 없는 음입니다.');
      }
      return next;
    });
  }

  /// Puts the slash through a grace note's stem, or takes it off: with it
  /// the note is played short before the beat, without it it leans on the
  /// note it leads to.
  XmlEditResult toggleGraceSlash(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    final info = doc.measure(ref).note(ref.noteIndex);
    final grace = info.element.getElement('grace');
    if (grace == null) throw const FormatException('꾸밈음이 아닙니다.');
    if (grace.getAttribute('slash') == 'yes') {
      grace.removeAttribute('slash');
    } else {
      grace.setAttribute('slash', 'yes');
    }
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Says that a bar is shorter than its time on purpose (a pickup, or a
  /// bar split over a line or a repeat), or that it is an ordinary bar
  /// again. In every part.
  XmlEditResult setPickup(
    String xml,
    int partIndex,
    int measureIndex, {
    required bool pickup,
  }) {
    final doc = _ScoreDoc(xml);
    doc.measureAt(partIndex, measureIndex);
    for (final (index, _) in doc.parts.indexed) {
      final measures = doc._measures(index);
      if (measureIndex >= measures.length) continue;
      if (pickup) {
        measures[measureIndex].setAttribute('implicit', 'yes');
      } else {
        measures[measureIndex].removeAttribute('implicit');
      }
    }
    return XmlEditResult(doc.toXml(), _barRef(partIndex, measureIndex));
  }

  /// Joins the notes [notes] of a bar (by note index) under one beam, or
  /// with [join] false takes their beams off, so each has its own flag.
  /// Notes with a flag only: eighths and shorter.
  XmlEditResult setBeam(
    String xml,
    int partIndex,
    int measureIndex,
    List<int> notes, {
    required bool join,
  }) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measureAt(partIndex, measureIndex);
    final heads = <_NoteInfo>[];
    for (final index in notes) {
      final head = measure.groupOf(measure.note(index)).first;
      if (heads.any((other) => identical(other, head))) continue;
      if (head.isRest || head.isGrace || head.isCue) continue;
      final quarters = _typeQuarters[head.type];
      if (quarters == null || quarters >= 1) continue;
      heads.add(head);
    }
    if (heads.length < (join ? 2 : 1)) {
      throw FormatException(
        join ? '빔으로 묶을 8분음표 이하의 음을 둘 이상 고르세요.' : '빔이 있는 음을 고르세요.',
      );
    }
    heads.sort((a, b) => a.onset.compareTo(b.onset));
    if (heads.any((head) => head.voice != heads.first.voice)) {
      throw const FormatException('한 성부의 음만 묶을 수 있습니다.');
    }
    void write(_NoteInfo head, String? value) {
      for (final member in measure.groupOf(head)) {
        member.element.findElements('beam').toList().forEach(_remove);
      }
      if (value == null) return;
      _insertOrdered(
        head.element,
        XmlElement(
          XmlName('beam'),
          [XmlAttribute(XmlName('number'), '1')],
          [XmlText(value)],
        ),
        _noteOrder,
      );
    }

    // The notes of the voice in order, with what each one's beam says now.
    final voice = [
      for (final group in measure.voiceGroups(heads.first.voice))
        if (!group.first.isGrace) group.first,
    ];
    final state = {
      for (final head in voice)
        head: head.element
            .findElements('beam')
            .where((beam) => (beam.getAttribute('number') ?? '1') == '1')
            .firstOrNull
            ?.innerText
            .trim(),
    };
    final picked = {for (final head in heads) head};
    if (join) {
      final first = voice.indexOf(heads.first);
      final last = voice.indexOf(heads.last);
      for (var i = first; i <= last; i++) {
        final head = voice[i];
        final quarters = _typeQuarters[head.type];
        if (head.isRest || quarters == null || quarters >= 1) {
          throw const FormatException('사이에 빔으로 묶을 수 없는 음이나 쉼표가 있습니다.');
        }
        picked.add(head);
      }
    }
    // Beams as runs of notes: the picked ones leave the runs they were in,
    // and when joining make one of their own.
    final runs = <List<_NoteInfo>>[];
    List<_NoteInfo>? run;
    for (final head in voice) {
      final value = state[head];
      if (value == null || picked.contains(head)) {
        run = null;
        continue;
      }
      // What is left of a beam after a picked note is a beam of its own.
      if (value == 'begin' || run == null) {
        run = [head];
        runs.add(run);
      } else {
        run.add(head);
      }
      if (value == 'end') run = null;
    }
    if (join) {
      runs.add([
        for (final head in voice)
          if (picked.contains(head)) head,
      ]);
    }
    for (final head in voice) {
      write(head, null);
    }
    for (final run in runs) {
      if (run.length < 2) continue;
      for (final (index, head) in run.indexed) {
        write(
          head,
          index == 0 ? 'begin' : (index == run.length - 1 ? 'end' : 'continue'),
        );
      }
    }
    return XmlEditResult(
      doc.toXml(),
      XmlNoteRef(
        partIndex: partIndex,
        measureIndex: measureIndex,
        noteIndex: notes.first,
      ),
    );
  }

  /// Makes the notes [notes] of a bar (by note index) a tuplet: three of
  /// one value are played in the time of two, five, six or seven in the
  /// time of four. They must follow one another in one voice. What comes
  /// after them comes that much earlier; a bar that was full is filled up
  /// at the end of the voice with rests, a bar that was too long (three
  /// eighths read where a triplet was written) is made right by it.
  XmlEditResult groupTuplet(
    String xml,
    int partIndex,
    int measureIndex,
    List<int> notes, {
    int? inTimeOf,
  }) {
    final doc = _ScoreDoc(xml);
    var measure = doc.measureAt(partIndex, measureIndex);
    // The picked notes by their place among the notes of the bar: scaling
    // the bar reads it anew.
    final picked = <int>{};
    for (final index in notes) {
      final head = measure.groupOf(measure.note(index)).first;
      picked.add(measure.notes.indexWhere((n) => identical(n, head)));
    }
    List<_NoteInfo> headsOf(_MeasureView view) =>
        [for (final index in picked) view.notes[index]]
          ..sort((a, b) => a.onset.compareTo(b.onset));
    var heads = headsOf(measure);
    final actual = heads.length;
    // In the time of how many: two play in the time of three, three in
    // the time of two, four in three, five to seven in four, nine and
    // more in eight; or what [inTimeOf] says.
    final normal =
        inTimeOf ??
        switch (actual) {
          2 => 3,
          3 => 2,
          4 => 3,
          >= 5 && <= 7 => 4,
          >= 9 && <= 15 => 8,
          _ => 0,
        };
    if (actual < 2 || normal < 1 || normal == actual || normal > 16) {
      throw const FormatException('이 수의 음은 잇단음표로 묶을 수 없습니다.');
    }
    final first = heads.first;
    final type = first.type;
    if (type == null || first.dots != 0) {
      throw const FormatException('점이 없는 같은 음가의 음을 고르세요.');
    }
    for (final head in heads) {
      if (head.isGrace || head.isCue) {
        throw const FormatException('꾸밈음은 잇단음표로 묶을 수 없습니다.');
      }
      if (head.voice != first.voice ||
          head.type != type ||
          head.dots != 0 ||
          head.duration != first.duration) {
        throw const FormatException('한 성부의, 점이 없는 같은 음가의 음을 고르세요.');
      }
      if (head.element.getElement('time-modification') != null) {
        throw const FormatException('이미 잇단음표인 음이 있습니다.');
      }
    }
    final voice = first.voice;
    var groups = [
      for (final group in measure.voiceGroups(voice))
        if (!group.first.isGrace) group,
    ];
    measure.requireSimpleVoice(groups);
    final places = [
      for (final head in heads)
        groups.indexWhere((group) => identical(group.first, head)),
    ];
    for (var i = 1; i < places.length; i++) {
      if (places[i] != places[i - 1] + 1) {
        throw const FormatException('잇달아 있는 음을 고르세요.');
      }
    }
    final whole = first.duration * normal;
    if (whole % actual != 0) {
      doc.scaleDivisions(
        partIndex,
        measureIndex,
        actual ~/ _gcd(whole, actual),
      );
      measure = doc.measureAt(partIndex, measureIndex);
      heads = headsOf(measure);
      groups = [
        for (final group in measure.voiceGroups(voice))
          if (!group.first.isGrace) group,
      ];
    }
    final was = heads.first.duration;
    final each = was * normal ~/ actual;
    final before = groups.fold<int>(0, (sum, g) => sum + g.first.duration);
    final capacity = measure.capacity;
    final modification = XmlElement(XmlName('time-modification'), [], [
      XmlElement(XmlName('actual-notes'), [], [XmlText('$actual')]),
      XmlElement(XmlName('normal-notes'), [], [XmlText('$normal')]),
    ]);
    for (final head in heads) {
      for (final member in measure.groupOf(head)) {
        _writeLength(member.element, each, type, 0);
        member.element.getElement('rest')?.removeAttribute('measure');
        _insertOrdered(member.element, modification.copy(), _noteOrder);
      }
    }
    _notationsOf(heads.first.element).children.add(
      XmlElement(XmlName('tuplet'), [
        XmlAttribute(XmlName('type'), 'start'),
        XmlAttribute(XmlName('bracket'), 'yes'),
      ]),
    );
    _notationsOf(heads.last.element).children.add(
      XmlElement(XmlName('tuplet'), [XmlAttribute(XmlName('type'), 'stop')]),
    );
    final freed = (was - each) * actual;
    final after = before - freed;
    // The voice ends where it ended, as far as the bar's time goes.
    final pad = before >= capacity && after < capacity
        ? math.min(freed, capacity - after)
        : 0;
    var last = groups.last.last.element;
    if (pad > 0) {
      final head = groups.last.first.element;
      for (final spelled in _spellGap(
        after,
        pad,
        doc.measureAt(partIndex, measureIndex),
      )) {
        final rest = _restElement(
          duration: spelled.duration,
          type: spelled.type,
          dots: spelled.dots,
          voice: head.getElement('voice')?.innerText,
          staff: head.getElement('staff')?.innerText,
        );
        last.parent!.children.insert(
          last.parent!.children.indexOf(last) + 1,
          rest,
        );
        last = rest;
      }
    }
    // What is written after the voice goes back to the start of the bar
    // by the voice's length: that is shorter now.
    final shorter = freed - pad;
    if (shorter > 0) {
      final siblings = last.parent!.children;
      for (var i = siblings.indexOf(last) + 1; i < siblings.length; i++) {
        final next = siblings[i];
        if (next is! XmlElement) continue;
        if (next.name.local == 'backup') {
          final length = _duration(next);
          if (length > shorter) {
            _setChild(next, 'duration', '${length - shorter}', const [
              'duration',
            ]);
          } else {
            _remove(next);
          }
        }
        if (const {'backup', 'forward', 'note'}.contains(next.name.local)) {
          break;
        }
      }
    }
    final start = heads.first.onset;
    doc
        .measureAt(partIndex, measureIndex)
        .rebeamRange(voice, start, start + each * actual);
    doc.measureAt(partIndex, measureIndex).fixOrphanBeams(voice);
    final rebuilt = doc.measureAt(partIndex, measureIndex);
    return XmlEditResult(
      doc.toXml(),
      XmlNoteRef(
        partIndex: partIndex,
        measureIndex: measureIndex,
        noteIndex: rebuilt.notes.indexWhere(
          (note) => identical(note.element, heads.first.element),
        ),
      ),
    );
  }

  /// Breaks the lines of the part every [bars] bars, in place of the line
  /// and page breaks it had; with [bars] null the breaks go and the lines
  /// are whatever fits the page.
  XmlEditResult setBarsPerLine(String xml, int partIndex, int? bars) {
    if (bars != null && (bars < 1 || bars > 16)) {
      throw const FormatException('한 줄에 1마디에서 16마디까지 둘 수 있습니다.');
    }
    final doc = _ScoreDoc(xml);
    for (final (index, _) in doc.parts.indexed) {
      for (final (at, measure) in doc._measures(index).indexed) {
        for (final print in measure.findElements('print').toList()) {
          print
            ..removeAttribute('new-system')
            ..removeAttribute('new-page');
          if (print.attributes.isEmpty && print.childElements.isEmpty) {
            _remove(print);
          }
        }
        if (bars == null || index != partIndex || at == 0 || at % bars != 0) {
          continue;
        }
        var print = measure.getElement('print');
        if (print == null) {
          print = XmlElement(XmlName('print'));
          measure.children.insert(0, print);
        }
        print.setAttribute('new-system', 'yes');
      }
    }
    return XmlEditResult(doc.toXml(), _barRef(partIndex, 0));
  }

  /// Adds the pitch [midi] to the selected note's chord, spelled as the key
  /// writes it.
  XmlEditResult addChordPitch(String xml, XmlNoteRef ref, int midi) {
    if (midi < 12 || midi > 127) {
      throw const FormatException('음역을 벗어났습니다.');
    }
    final doc = _ScoreDoc(xml);
    final fifths = doc.measure(ref).context.fifths;
    doc.keep(xml);
    final pitch = parseSpelledPitch(spellMidi(midi, fifths));
    if (pitch == null) throw const FormatException('음높이를 읽을 수 없습니다.');
    return addChordNote(xml, ref, at: pitch);
  }

  /// Takes the notes, chords and rests at [refs] (in order) to be written
  /// elsewhere with [pasteNotes]. A chord is taken once, whichever of its
  /// notes was picked; ornament notes are left.
  NoteClip copyNotes(String xml, List<XmlNoteRef> refs) {
    final doc = _ScoreDoc(xml);
    final events = <({List<MusicPitch> pitches, String type, int dots})>[];
    final seen = <XmlElement>{};
    for (final ref in refs) {
      final measure = doc.measure(ref);
      final info = measure.note(ref.noteIndex);
      if (info.isGrace || info.isCue) continue;
      final group = measure.groupOf(info);
      if (!seen.add(group.first.element)) continue;
      final head = group.first;
      var type = head.type;
      var dots = head.dots;
      if (type == null) {
        final spelled = _spellSingle(head.duration, measure.divisions);
        if (spelled == null) continue;
        type = spelled.type;
        dots = spelled.dots;
      }
      events.add((
        pitches: [
          for (final note in group)
            if (note.pitch case final pitch?) pitch,
        ],
        type: type,
        dots: dots,
      ));
    }
    doc.keep(xml);
    if (events.isEmpty) throw const FormatException('복사할 음이 없습니다.');
    return NoteClip._(events);
  }

  /// Writes [clip] over the notes and rests from the selected one on, one
  /// for one, into the next bars where the bar ends: each takes the pitch
  /// (or becomes the rest) and, where it fits its bar, the value of the
  /// copied one. Stops where the part ends. The selection moves to the
  /// last one written.
  XmlEditResult pasteNotes(String xml, XmlNoteRef ref, NoteClip clip) {
    var current = xml;
    XmlNoteRef? at = ref;
    var last = ref;
    var written = 0;
    for (final event in clip._events) {
      if (at == null) break;
      // The value first: it may put rests behind the note, which the next
      // copied note then takes.
      try {
        current = setDuration(current, at, event.type, event.dots).xml;
      } on FormatException {
        // Already that value, or no room for it: the note keeps its own.
      }
      // One note of the right kind at the place.
      while (describe(current, at).chordSize > 1) {
        final summary = describe(current, at);
        final doc = _ScoreDoc(current);
        final measure = doc.measure(at);
        final group = measure.groupOf(measure.note(at.noteIndex));
        final extra = measure.notes.indexWhere(
          (note) => identical(note, group.last),
        );
        doc.keep(current);
        if (summary.chordSize <= 1 || extra < 0) break;
        current = removeNote(current, at.withNote(extra)).xml;
      }
      final now = describe(current, at);
      if (event.pitches.isEmpty) {
        if (!now.isRest) current = deleteNote(current, at).xml;
      } else {
        if (now.isRest) current = restToNote(current, at).xml;
        final first = event.pitches.first;
        if (describe(current, at).pitch?.midi != first.midi ||
            describe(current, at).pitch?.step != first.step) {
          current = _editPitch(current, at, (_, _, _) => first).xml;
        }
        for (final pitch in event.pitches.skip(1)) {
          try {
            current = addChordNote(current, at, at: pitch).xml;
          } on FormatException {
            // A pitch the chord already has.
          }
        }
      }
      written++;
      last = at;
      at = _eventAfter(current, at);
    }
    if (written == 0) throw const FormatException('붙여넣을 자리가 없습니다.');
    return XmlEditResult(current, last);
  }

  /// Writes [clip] from the selected note on as a notation program pastes:
  /// each copied note keeps its length, wherever in the bar it comes to
  /// stand. A note that runs over a barline is cut there and tied over,
  /// and what the copied notes cover gives way to them. After the last of
  /// them the bar goes on as it was (a note cut into leaves a rest).
  ///
  /// For a melody: a part of one staff and one voice, without tuplets,
  /// and a run of single notes and rests. Anything else throws, and
  /// [pasteNotes] writes note for note instead.
  XmlEditResult pasteNotesFlowing(String xml, XmlNoteRef ref, NoteClip clip) {
    // Lengths in 96ths of a quarter: a thirty-second is 12, and every
    // dotted value down to it is a whole number.
    const quarter = 96;
    int ticksOf(String type, int dots) {
      final quarters = _typeQuarters[type];
      if (quarters == null) throw const FormatException('지원하지 않는 음가입니다.');
      final ticks = quarters * (2 - 1 / math.pow(2, dots)) * quarter;
      if (ticks != ticks.roundToDouble()) {
        throw const FormatException('이 음가는 흘려 붙일 수 없습니다.');
      }
      return ticks.round();
    }

    final copied = <({MusicPitch? pitch, int ticks})>[
      for (final event in clip._events)
        if (event.pitches.length > 1)
          throw const FormatException('화음은 흘려 붙일 수 없습니다.')
        else
          (
            pitch: event.pitches.firstOrNull,
            ticks: ticksOf(event.type, event.dots),
          ),
    ];
    if (copied.isEmpty) throw const FormatException('복사한 음이 없습니다.');
    final doc = _ScoreDoc(xml);
    final count = doc.measureCount(ref.partIndex);
    final start = doc.measure(ref);
    final first = start.groupOf(start.note(ref.noteIndex)).first;

    // The notes and rests of a bar as (onset, length, pitch, tied on), in
    // ticks; throws where the bar is not a plain melody.
    ({
      int capacity,
      List<({int onset, int ticks, MusicPitch? pitch, bool tied})> events,
    })
    read(int bar) {
      final measure = doc.measureAt(ref.partIndex, bar);
      if (measure.context.staves > 1) {
        throw const FormatException('보표가 둘인 파트에는 흘려 붙일 수 없습니다.');
      }
      final divisions = measure.divisions;
      int ticks(int value) {
        if (value * quarter % divisions != 0) {
          throw const FormatException('이 마디의 음가는 흘려 붙일 수 없습니다.');
        }
        return value * quarter ~/ divisions;
      }

      final voices = {for (final note in measure.notes) note.voice};
      if (voices.length > 1) {
        throw const FormatException('성부가 둘 이상인 마디에는 흘려 붙일 수 없습니다.');
      }
      final events = <({int onset, int ticks, MusicPitch? pitch, bool tied})>[];
      for (final note in measure.notes) {
        if (note.isGrace || note.isCue) {
          throw const FormatException('꾸밈음이 있는 마디에는 흘려 붙일 수 없습니다.');
        }
        if (note.element.getElement('time-modification') != null) {
          throw const FormatException('잇단음표가 있는 마디에는 흘려 붙일 수 없습니다.');
        }
        if (measure.groupOf(note).length > 1) {
          throw const FormatException('화음이 있는 마디에는 흘려 붙일 수 없습니다.');
        }
        events.add((
          onset: ticks(note.onset),
          ticks: ticks(note.duration),
          pitch: note.pitch,
          tied: note.tieStart,
        ));
      }
      return (capacity: ticks(measure.capacity), events: events);
    }

    // What each bar holds afterwards.
    final written = <int, List<({int ticks, MusicPitch? pitch, bool tied})>>{};
    var next = 0;
    var left = copied.first.ticks;
    var firstPasted = -1;
    for (
      var bar = ref.measureIndex;
      bar < count && next < copied.length;
      bar++
    ) {
      final was = read(bar);
      final content = <({int ticks, MusicPitch? pitch, bool tied})>[];
      var cursor = 0;
      if (bar == ref.measureIndex) {
        // What stands before the place in its bar stays.
        final at = _ticksOf(first.onset, start.divisions, quarter);
        for (final event in was.events) {
          if (event.onset >= at) break;
          if (event.onset > cursor) {
            content.add((
              ticks: event.onset - cursor,
              pitch: null,
              tied: false,
            ));
          }
          content.add((
            ticks: event.ticks,
            pitch: event.pitch,
            tied: event.tied,
          ));
          cursor = event.onset + event.ticks;
        }
        if (cursor < at) {
          content.add((ticks: at - cursor, pitch: null, tied: false));
        }
        cursor = at;
        firstPasted = content.length;
      }
      while (cursor < was.capacity && next < copied.length) {
        final take = math.min(left, was.capacity - cursor);
        final event = copied[next];
        content.add((
          ticks: take,
          pitch: event.pitch,
          // Cut at the barline: tied over to what is left of it.
          tied: event.pitch != null && left > take,
        ));
        cursor += take;
        left -= take;
        if (left == 0) {
          next++;
          if (next < copied.length) left = copied[next].ticks;
        }
      }
      // After the last copied note the bar goes on as it was.
      for (final event in was.events) {
        final end = event.onset + event.ticks;
        if (end <= cursor) continue;
        if (event.onset >= cursor) {
          if (event.onset > cursor) {
            content.add((
              ticks: event.onset - cursor,
              pitch: null,
              tied: false,
            ));
          }
          content.add((
            ticks: event.ticks,
            pitch: event.pitch,
            tied: event.tied,
          ));
        } else {
          content.add((ticks: end - cursor, pitch: null, tied: false));
        }
        cursor = end;
      }
      if (cursor < was.capacity) {
        content.add((ticks: was.capacity - cursor, pitch: null, tied: false));
      } else if (cursor > was.capacity) {
        throw const FormatException('박자보다 긴 마디에는 흘려 붙일 수 없습니다.');
      }
      written[bar] = content;
    }
    doc.keep(xml);

    // Each length as note values, the largest first; more than one for a
    // length no single value has, tied together.
    const values = [
      ('w', 384),
      ('h.', 288),
      ('h', 192),
      ('q.', 144),
      ('q', 96),
      ('8.', 72),
      ('8', 48),
      ('16.', 36),
      ('16', 24),
      ('32.', 18),
      ('32', 12),
    ];
    String name(MusicPitch pitch) =>
        '${pitch.step.name.toUpperCase()}${switch (pitch.alter) {
          2 => 'x',
          1 => '#',
          -1 => 'b',
          -2 => 'bb',
          _ => '',
        }}${pitch.octave}';
    var current = xml;
    final ties = <XmlNoteRef>[];
    XmlNoteRef? selection;
    for (final MapEntry(key: bar, value: content) in written.entries) {
      final tokens = <String>[];
      for (final (index, piece) in content.indexed) {
        var rest = piece.ticks;
        if (bar == ref.measureIndex && index == firstPasted) {
          selection = ref.inBar(bar, tokens.length);
        }
        while (rest > 0) {
          final value = values.where((v) => v.$2 <= rest).firstOrNull;
          if (value == null) {
            throw const FormatException('이 길이는 음표로 적을 수 없습니다.');
          }
          rest -= value.$2;
          final pitch = piece.pitch;
          if (pitch != null && (rest > 0 || piece.tied)) {
            ties.add(ref.inBar(bar, tokens.length));
          }
          tokens.add('${pitch == null ? 'rest' : name(pitch)} ${value.$1}');
        }
      }
      current = replaceMelody(
        current,
        ref.partIndex,
        bar,
        tokens.join(', '),
      ).xml;
    }
    for (final tie in ties) {
      try {
        current = toggleTie(current, tie).xml;
      } on FormatException {
        // What it was tied to is no longer the same note.
      }
    }
    return XmlEditResult(current, selection ?? ref);
  }

  /// Writes the notes at [refs] once more, over what follows the last of
  /// them.
  XmlEditResult duplicateNotes(String xml, List<XmlNoteRef> refs) {
    if (refs.isEmpty) throw const FormatException('복제할 음이 없습니다.');
    final clip = copyNotes(xml, refs);
    final after = _eventAfter(xml, refs.last);
    if (after == null) throw const FormatException('붙여넣을 자리가 없습니다.');
    return pasteNotes(xml, after, clip);
  }

  /// The note, chord or rest after the one at [ref] in its voice, in the
  /// next bar where the bar ends; null at the end of the part.
  XmlNoteRef? _eventAfter(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    try {
      final measure = doc.measure(ref);
      final info = measure.note(ref.noteIndex);
      final head = measure.groupOf(info).first;
      final groups = [
        for (final group in measure.voiceGroups(head.voice))
          if (!group.first.isGrace) group.first,
      ];
      final index = groups.indexWhere((note) => identical(note, head));
      if (index >= 0 && index + 1 < groups.length) {
        return ref.withNote(
          measure.notes.indexWhere(
            (note) => identical(note, groups[index + 1]),
          ),
        );
      }
      final count = doc._measures(ref.partIndex).length;
      for (var bar = ref.measureIndex + 1; bar < count; bar++) {
        final next = doc.measureAt(ref.partIndex, bar);
        final first = next.notes.indexWhere(
          (note) =>
              !note.isGrace &&
              !note.isCue &&
              note.staff == info.staff &&
              identical(next.groupOf(note).first, note),
        );
        if (first >= 0) return ref.inBar(bar, first);
      }
      return null;
    } finally {
      doc.keep(xml);
    }
  }
}

/// [value] divisions as ticks of [quarter] to the quarter note.
int _ticksOf(int value, int divisions, int quarter) {
  if (value * quarter % divisions != 0) {
    throw const FormatException('이 마디의 음가는 흘려 붙일 수 없습니다.');
  }
  return value * quarter ~/ divisions;
}
