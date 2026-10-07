part of 'xml_measure_editor.dart';

// What a notation editor puts on a note or a bar beyond its pitch and
// length: rests and splits, tuplets, ties, articulations, dynamics, grace
// notes, and the signs of a bar (key, time, clef, barlines, repeats,
// endings, jumps, rehearsal marks, tempo, text). Every method is pure, like
// those of [XmlMeasureEditor], and throws a [FormatException] whose message
// can be shown to the user when an edit is not supported.

/// Tuplets a note can be made into: [actual] notes in the time of [normal].
const tupletChoices = <({int actual, int normal})>[
  (actual: 3, normal: 2),
  (actual: 5, normal: 4),
  (actual: 6, normal: 4),
  (actual: 7, normal: 4),
];

/// Articulations written at a note, as MusicXML names them.
const articulationNames = [
  'staccato',
  'staccatissimo',
  'tenuto',
  'accent',
  'strong-accent',
];

/// Dynamic marks, softest first.
const dynamicMarks = [
  'ppp',
  'pp',
  'p',
  'mp',
  'mf',
  'f',
  'ff',
  'fff',
  'sfz',
  'fp',
];

/// Right barlines a bar can end with, as MusicXML names them.
const barStyles = ['regular', 'light-light', 'light-heavy'];

/// Signs that send the player elsewhere, or mark where that is. The first
/// two stand at the start of their bar, the others at its end.
enum NavigationSign {
  segno,
  coda,
  toCoda,
  fine,
  dsAlCoda,
  dsAlFine,
  dcAlCoda,
  dcAlFine;

  bool get atStart => this == segno || this == coda;

  /// Whether the sign is a jump: a bar has at most one.
  bool get isJump => index >= NavigationSign.dsAlCoda.index;

  String get words => switch (this) {
    segno => 'Segno',
    coda => 'Coda',
    toCoda => 'To Coda',
    fine => 'Fine',
    dsAlCoda => 'D.S. al Coda',
    dsAlFine => 'D.S. al Fine',
    dcAlCoda => 'D.C. al Coda',
    dcAlFine => 'D.C. al Fine',
  };

  /// The `<sound>` attribute that says what the sign does.
  (String, String) get sound => switch (this) {
    segno => ('segno', 'segno'),
    coda => ('coda', 'coda'),
    toCoda => ('tocoda', 'coda'),
    fine => ('fine', 'yes'),
    dsAlCoda || dsAlFine => ('dalsegno', 'segno'),
    dcAlCoda || dcAlFine => ('dacapo', 'yes'),
  };
}

const _barlineOrder = [
  'bar-style',
  'footnote',
  'level',
  'wavy-line',
  'segno',
  'coda',
  'fermata',
  'ending',
  'repeat',
];

extension XmlMeasureMarks on XmlMeasureEditor {
  // --- Notes ------------------------------------------------------------------

  /// Splits a note or rest in two of the same pitch: a quarter into two
  /// eighths, a dotted quarter into a quarter and an eighth. Words stay on
  /// the first half; a tie to the next note leaves from the second.
  XmlEditResult splitNote(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    var measure = doc.measure(ref);
    var info = measure.note(ref.noteIndex);
    _requirePlain(info);
    final type = info.type;
    if (type == null) throw const FormatException('길이를 알 수 없는 음표입니다.');
    final shorter = _shorterType(type);
    if (shorter == null) throw const FormatException('더 짧은 음가가 없습니다.');
    final ({String type, int dots}) first;
    final ({String type, int dots}) second;
    switch (info.dots) {
      case 0:
        first = (type: shorter, dots: 0);
        second = (type: shorter, dots: 0);
      case 1:
        first = (type: type, dots: 0);
        second = (type: shorter, dots: 0);
      default:
        final shortest = _shorterType(shorter);
        if (shortest == null) {
          throw const FormatException('더 짧은 음가가 없습니다.');
        }
        first = (type: type, dots: 1);
        second = (type: shortest, dots: 0);
    }
    measure = _fitDivisions(doc, ref, [
      _quartersOf(first.type, first.dots),
      _quartersOf(second.type, second.dots),
    ]);
    info = measure.note(ref.noteIndex);
    final group = measure.groupOf(info);
    final head = group.first;
    final length1 = (measure.divisions * _quartersOf(first.type, first.dots))
        .round();
    final length2 = (measure.divisions * _quartersOf(second.type, second.dots))
        .round();
    if (length1 + length2 != head.duration) {
      throw const FormatException('이 음표는 둘로 나눌 수 없습니다.');
    }
    final copies = <XmlElement>[];
    for (final member in group) {
      final copy = _bareCopy(member.element, keepTieStart: true);
      _removeTieMarks(member.element, 'start');
      _writeLength(member.element, length1, first.type, first.dots);
      _writeLength(copy, length2, second.type, second.dots);
      copies.add(copy);
    }
    _insertAfter(group.last.element, copies);
    measure = doc.measure(ref);
    measure.rebeamRange(head.voice, head.onset, head.onset + head.duration);
    doc.measure(ref).fixOrphanBeams(head.voice);
    _respell(doc, ref, group);
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Takes a note or rest out of its bar and closes the bar up behind it:
  /// what followed moves earlier, and a bar that was full ends in rests.
  /// ([XmlMeasureEditor.deleteNote] leaves a rest in the note's place.)
  XmlEditResult removeNote(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    var measure = doc.measure(ref);
    var info = measure.note(ref.noteIndex);
    if (info.isGrace) {
      _detachNoteSpans(info.element);
      _remove(info.element);
      final count = doc.measure(ref).notes.length;
      return XmlEditResult(
        doc.toXml(),
        ref.withNote(math.max(0, math.min(ref.noteIndex, count - 1))),
      );
    }
    _requirePlain(info);
    final voice = info.voice;
    final groups = measure.voiceGroups(voice);
    measure.requireSimpleVoice(groups);
    final voiceEnd = groups.last.first.onset + groups.last.first.duration;
    final capacity = measure.capacity;
    final steps = <PitchStep>{};
    for (final member in measure.groupOf(info)) {
      if (member.pitch case final pitch?) steps.add(pitch.step);
      doc.breakTies(ref.measureIndex, member);
    }
    measure = doc.measure(ref);
    info = measure.note(ref.noteIndex);
    final group = measure.groupOf(info);
    final last = measure.voiceGroups(voice).last;
    final wasLast = identical(last.first, group.first);
    final parent = measure.element;
    final removedAt = parent.children.indexOf(group.first.element);
    final removed = group.first.duration;
    // A chord symbol written before the note stays where it is written: it
    // goes with the note that takes this one's place.
    for (final member in group) {
      _detachNoteSpans(member.element);
      _remove(member.element);
    }
    var end = voiceEnd - removed;
    final fill = voiceEnd >= capacity && end < capacity ? capacity - end : 0;
    if (fill > 0) {
      measure = doc.measure(ref);
      final rests = <XmlElement>[];
      var at = end;
      for (final spelled in _spellGap(end, fill, measure)) {
        rests.add(
          _restElement(
            duration: spelled.duration,
            type: spelled.type,
            dots: spelled.dots,
            voice: info.element.getElement('voice')?.innerText,
            staff: info.element.getElement('staff')?.innerText,
          ),
        );
        at += spelled.duration;
      }
      end = at;
      if (wasLast) {
        parent.children.insertAll(removedAt, rests);
      } else {
        _insertAfter(last.last.element, rests);
      }
    }
    _adjustFollowing(doc, ref, voice, end - voiceEnd);
    measure = doc.measure(ref);
    measure.rebeamRange(voice, 0, math.max(capacity, end));
    doc.measure(ref).fixOrphanBeams(voice);
    doc.measure(ref).refreshAccidentals(info.staff, steps);
    final count = doc.measure(ref).notes.length;
    return XmlEditResult(
      doc.toXml(),
      ref.withNote(math.max(0, math.min(ref.noteIndex, count - 1))),
    );
  }

  /// Puts a new note or rest of the selected note's length before or after
  /// it. What follows moves later; rests at the end of the bar give way,
  /// and a bar with no rest left to give throws.
  XmlEditResult insertEvent(
    String xml,
    XmlNoteRef ref, {
    required bool before,
    required bool rest,
  }) {
    final doc = _ScoreDoc(xml);
    var measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    _requirePlain(info);
    final voice = info.voice;
    final groups = measure.voiceGroups(voice);
    measure.requireSimpleVoice(groups);
    final group = measure.groupOf(info);
    final head = group.first;
    var type = head.type;
    var dots = head.dots;
    if (type == null) {
      final spelled = _spellSingle(head.duration, measure.divisions);
      if (spelled == null) {
        throw const FormatException('길이를 알 수 없는 음표입니다.');
      }
      type = spelled.type;
      dots = spelled.dots;
    }
    final length = head.duration;
    final voiceEnd = groups.last.first.onset + groups.last.first.duration;
    final room = math.max(measure.capacity, voiceEnd);
    var need = voiceEnd + length - room;
    var absorbed = 0;
    for (final trailing in groups.reversed) {
      if (need <= 0) break;
      final note = trailing.first;
      if (!note.isRest ||
          trailing.length > 1 ||
          identical(note, head) ||
          note.element.getElement('time-modification') != null) {
        break;
      }
      if (note.duration <= need) {
        _remove(note.element);
        need -= note.duration;
        absorbed += note.duration;
      } else {
        final kept = note.duration - need;
        final rests = [
          for (final spelled in _spellGap(note.onset, kept, measure))
            _restElement(
              duration: spelled.duration,
              type: spelled.type,
              dots: spelled.dots,
              voice: note.element.getElement('voice')?.innerText,
              staff: note.element.getElement('staff')?.innerText,
            ),
        ];
        _insertAfter(note.element, rests);
        _remove(note.element);
        absorbed += need;
        need = 0;
      }
    }
    if (need > 0) {
      throw const FormatException('마디에 자리가 없습니다. 뒤의 쉼표를 지우거나 음표를 줄이세요.');
    }
    final XmlElement created;
    if (rest) {
      created = _restElement(
        duration: length,
        type: type,
        dots: dots,
        voice: head.element.getElement('voice')?.innerText,
        staff: head.element.getElement('staff')?.innerText,
      );
    } else {
      final pitch = head.pitch ?? _middle(measure, head);
      created = XmlElement(XmlName('note'), [], [
        _pitchElement(pitch),
        XmlElement(XmlName('duration'), [], [XmlText('$length')]),
        if (head.element.getElement('voice') case final voice?) voice.copy(),
        XmlElement(XmlName('type'), [], [XmlText(type)]),
        for (var i = 0; i < dots; i++) XmlElement(XmlName('dot')),
        if (head.element.getElement('staff') case final staff?) staff.copy(),
      ]);
    }
    final parent = measure.element;
    if (before) {
      parent.children.insert(parent.children.indexOf(head.element), created);
    } else {
      _insertAfter(group.last.element, [created]);
    }
    _adjustFollowing(doc, ref, voice, length - absorbed);
    measure = doc.measure(ref);
    measure.rebeamRange(
      voice,
      0,
      math.max(measure.capacity, voiceEnd + length),
    );
    doc.measure(ref).fixOrphanBeams(voice);
    if (!rest) {
      doc.measure(ref).refreshAccidentals(head.staff, {
        (head.pitch ?? _middle(measure, head)).step,
      });
    }
    final index = doc
        .measure(ref)
        .notes
        .indexWhere((n) => identical(n.element, created));
    return XmlEditResult(doc.toXml(), ref.withNote(index));
  }

  /// Makes the selected note [actual] equal notes in its time, [normal] of
  /// them being worth the note: a quarter becomes a triplet of eighths. The
  /// new notes have the pitch of the first; their pitches are set after.
  XmlEditResult makeTuplet(String xml, XmlNoteRef ref, int actual, int normal) {
    if (!tupletChoices.any((c) => c.actual == actual && c.normal == normal)) {
      throw const FormatException('지원하지 않는 잇단음표입니다.');
    }
    final doc = _ScoreDoc(xml);
    var measure = doc.measure(ref);
    var info = measure.note(ref.noteIndex);
    _requirePlain(info);
    final type = info.type;
    if (type == null) throw const FormatException('길이를 알 수 없는 음표입니다.');
    final memberType = switch (actual) {
      3 => _shorterType(type),
      _ => _shorterType(_shorterType(type) ?? ''),
    };
    if (memberType == null) {
      throw const FormatException('이 음가는 잇단음표로 만들 수 없습니다.');
    }
    final total = measure.groupOf(info).first.duration;
    if (total % actual != 0) {
      doc.scaleDivisions(
        ref.partIndex,
        ref.measureIndex,
        actual ~/ _gcd(total, actual),
      );
      measure = doc.measure(ref);
      info = measure.note(ref.noteIndex);
    }
    final group = measure.groupOf(info);
    final head = group.first;
    final each = head.duration ~/ actual;
    final dots = head.dots;
    final copies = <List<XmlElement>>[];
    for (var i = 1; i < actual; i++) {
      copies.add([
        for (final member in group)
          _bareCopy(member.element, keepTieStart: i == actual - 1),
      ]);
    }
    for (final member in group) {
      _removeTieMarks(member.element, 'start');
    }
    final modification = XmlElement(XmlName('time-modification'), [], [
      XmlElement(XmlName('actual-notes'), [], [XmlText('$actual')]),
      XmlElement(XmlName('normal-notes'), [], [XmlText('$normal')]),
    ]);
    for (final element in [
      for (final member in group) member.element,
      for (final copy in copies) ...copy,
    ]) {
      _writeLength(element, each, memberType, dots);
      element.findElements('time-modification').toList().forEach(_remove);
      _insertOrdered(element, modification.copy(), _noteOrder);
    }
    _notationsOf(head.element).children.add(
      XmlElement(XmlName('tuplet'), [
        XmlAttribute(XmlName('type'), 'start'),
        XmlAttribute(XmlName('bracket'), 'yes'),
      ]),
    );
    _notationsOf(copies.last.first).children.add(
      XmlElement(XmlName('tuplet'), [XmlAttribute(XmlName('type'), 'stop')]),
    );
    _insertAfter(group.last.element, [for (final copy in copies) ...copy]);
    measure = doc.measure(ref);
    measure.rebeamRange(head.voice, head.onset, head.onset + each * actual);
    doc.measure(ref).fixOrphanBeams(head.voice);
    _respell(doc, ref, group);
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Turns the tuplet the selected note belongs to back into one note of
  /// its whole length, with the first note's pitch.
  XmlEditResult removeTuplet(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    var measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    if (info.isGrace || info.isCue) {
      throw const FormatException('꾸밈음은 잇단음표가 아닙니다.');
    }
    final groups = measure.voiceGroups(info.voice);
    final at = groups.indexWhere((g) => g.contains(info));
    bool modified(List<_NoteInfo> group) =>
        group.first.element.getElement('time-modification') != null;
    bool marked(List<_NoteInfo> group, String type) =>
        group.first.element
            .getElement('notations')
            ?.findElements('tuplet')
            .any((t) => t.getAttribute('type') == type) ??
        false;
    if (at < 0 || !modified(groups[at])) {
      throw const FormatException('잇단음표가 아닙니다.');
    }
    var start = at;
    while (start > 0 &&
        modified(groups[start - 1]) &&
        !marked(groups[start], 'start')) {
      start--;
    }
    var end = at;
    while (!marked(groups[end], 'stop') &&
        end + 1 < groups.length &&
        modified(groups[end + 1])) {
      end++;
    }
    final run = groups.sublist(start, end + 1);
    var total = 0;
    for (final group in run) {
      total += group.first.duration;
    }
    final spelled = _spellSingle(total, measure.divisions);
    if (spelled == null) {
      throw const FormatException('이 잇단음표는 음표 하나로 바꿀 수 없습니다.');
    }
    final first = run.first;
    for (final group in run) {
      for (final member in group) {
        doc.breakTies(ref.measureIndex, member, stop: !identical(group, first));
      }
    }
    measure = doc.measure(ref);
    final head = measure.notes.firstWhere(
      (n) => identical(n.element, first.first.element),
    );
    for (final member in measure.groupOf(head)) {
      _writeLength(member.element, total, spelled.type, spelled.dots);
      member.element
          .findElements('time-modification')
          .toList()
          .forEach(_remove);
      final notations = member.element.getElement('notations');
      if (notations != null) {
        notations.findElements('tuplet').toList().forEach(_remove);
        if (notations.childElements.isEmpty) _remove(notations);
      }
    }
    for (final group in run.skip(1)) {
      for (final member in group) {
        _remove(member.element);
      }
    }
    measure = doc.measure(ref);
    measure.rebeamRange(head.voice, head.onset, head.onset + total);
    doc.measure(ref).fixOrphanBeams(head.voice);
    final index = doc
        .measure(ref)
        .notes
        .indexWhere((n) => identical(n.element, head.element));
    return XmlEditResult(doc.toXml(), ref.withNote(index));
  }

  /// Ties the selected note to the next note of its pitch, or takes such a
  /// tie away.
  XmlEditResult toggleTie(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    final pitch = info.pitch;
    if (pitch == null) throw const FormatException('쉼표에는 붙임줄을 걸 수 없습니다.');
    if (info.isGrace || info.isCue) {
      throw const FormatException('꾸밈음에는 붙임줄을 걸 수 없습니다.');
    }
    if (info.tieStart) {
      doc.breakTies(ref.measureIndex, info, stop: false);
      return XmlEditResult(doc.toXml(), ref);
    }
    final end = info.onset + info.duration;
    bool matches(_NoteInfo candidate, int onset) =>
        !candidate.isGrace &&
        candidate.voice == info.voice &&
        candidate.staff == info.staff &&
        candidate.onset == onset &&
        candidate.pitch?.midi == pitch.midi;
    var partnerMeasure = ref.measureIndex;
    _NoteInfo? partner;
    for (final candidate in measure.notes) {
      if (matches(candidate, end)) {
        partner = candidate;
        break;
      }
    }
    if (partner == null &&
        end >= doc._voiceEnd(measure, info) &&
        ref.measureIndex + 1 < doc.measureCount(ref.partIndex)) {
      partnerMeasure = ref.measureIndex + 1;
      for (final candidate
          in doc.measureAt(ref.partIndex, partnerMeasure).notes) {
        if (matches(candidate, 0)) {
          partner = candidate;
          break;
        }
      }
    }
    if (partner == null) {
      throw const FormatException('다음 음이 같은 높이일 때만 붙임줄을 걸 수 있습니다.');
    }
    _addTieMarks(info.element, 'start');
    _addTieMarks(partner.element, 'stop');
    doc.measureAt(ref.partIndex, partnerMeasure).refreshAccidentals(
      partner.staff,
      {pitch.step},
    );
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Puts an articulation on the selected note's chord, or takes it off.
  /// [name] is one of [articulationNames], `breath-mark` or `fermata`.
  XmlEditResult toggleArticulation(String xml, XmlNoteRef ref, String name) {
    if (name != 'fermata' &&
        name != 'breath-mark' &&
        !articulationNames.contains(name)) {
      throw const FormatException('지원하지 않는 기호입니다.');
    }
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    if (info.isGrace || info.isCue) {
      throw const FormatException('꾸밈음에는 기호를 붙일 수 없습니다.');
    }
    if (info.isRest && name != 'fermata') {
      throw const FormatException('쉼표에는 늘임표만 붙일 수 있습니다.');
    }
    final head = measure.groupOf(info).first.element;
    final notations = _notationsOf(head);
    if (name == 'fermata') {
      final existing = notations.findElements('fermata').toList();
      if (existing.isNotEmpty) {
        existing.forEach(_remove);
      } else {
        notations.children.add(XmlElement(XmlName('fermata')));
      }
    } else {
      var articulations = notations.getElement('articulations');
      final existing = articulations?.findElements(name).toList() ?? const [];
      if (existing.isNotEmpty) {
        existing.forEach(_remove);
      } else {
        if (articulations == null) {
          articulations = XmlElement(XmlName('articulations'));
          notations.children.add(articulations);
        }
        articulations.children.add(XmlElement(XmlName(name)));
      }
      if (articulations != null && articulations.childElements.isEmpty) {
        _remove(articulations);
      }
    }
    if (notations.childElements.isEmpty) _remove(notations);
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Writes a dynamic mark ([dynamicMarks]) at the selected note, in place
  /// of one already there; null takes it away.
  XmlEditResult setDynamic(String xml, XmlNoteRef ref, String? mark) {
    if (mark != null && !dynamicMarks.contains(mark)) {
      throw const FormatException('지원하지 않는 셈여림입니다.');
    }
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    final head = measure.groupOf(info).first.element;
    for (final direction in _directionsBefore(measure.element, head)) {
      if (direction.findAllElements('dynamics').isNotEmpty) _remove(direction);
    }
    if (mark != null) {
      final direction = XmlElement(
        XmlName('direction'),
        [XmlAttribute(XmlName('placement'), 'below')],
        [
          XmlElement(XmlName('direction-type'), [], [
            XmlElement(XmlName('dynamics'), [], [XmlElement(XmlName(mark))]),
          ]),
          if (measure.staves > 1)
            XmlElement(XmlName('staff'), [], [XmlText('${info.staff}')]),
        ],
      );
      final parent = measure.element;
      parent.children.insert(parent.children.indexOf(head), direction);
    }
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Puts a grace note (a short note with a slash, played before the beat)
  /// a step above the selected note.
  XmlEditResult addGraceNote(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    final pitch = info.pitch;
    if (pitch == null) throw const FormatException('쉼표에는 꾸밈음을 붙일 수 없습니다.');
    if (info.isGrace || info.isCue) {
      throw const FormatException('꾸밈음에는 꾸밈음을 붙일 수 없습니다.');
    }
    final head = measure.groupOf(info).first;
    final number = pitch.octave * 7 + pitch.step.index + 1;
    final step = PitchStep.values[number % 7];
    final octave = number ~/ 7;
    final grace = XmlElement(XmlName('note'), [], [
      XmlElement(XmlName('grace'), [XmlAttribute(XmlName('slash'), 'yes')]),
      _pitchElement(
        MusicPitch(
          step: step,
          octave: octave,
          alter: measure.contextAlter(head, step, octave),
        ),
      ),
      if (head.element.getElement('voice') case final voice?) voice.copy(),
      XmlElement(XmlName('type'), [], [XmlText('eighth')]),
      XmlElement(XmlName('stem'), [], [XmlText('up')]),
      if (head.element.getElement('staff') case final staff?) staff.copy(),
    ]);
    final parent = measure.element;
    parent.children.insert(parent.children.indexOf(head.element), grace);
    doc.measure(ref).refreshAccidentals(head.staff, {step});
    final index = doc
        .measure(ref)
        .notes
        .indexWhere((n) => identical(n.element, grace));
    return XmlEditResult(doc.toXml(), ref.withNote(index));
  }

  // --- Bars -------------------------------------------------------------------

  /// Gives the bar a key signature, which holds until the next one. The
  /// accidentals of the bars it reaches are written again for the new key;
  /// the notes themselves keep their pitch.
  XmlEditResult setKeySignature(
    String xml,
    int partIndex,
    int measureIndex,
    int fifths,
  ) {
    if (fifths < -7 || fifths > 7) {
      throw const FormatException('조표는 ♭7개에서 ♯7개까지입니다.');
    }
    final doc = _ScoreDoc(xml);
    final attributes = doc._firstAttributes(_bar(doc, partIndex, measureIndex));
    attributes.findElements('key').toList().forEach(_remove);
    _insertOrdered(
      attributes,
      XmlElement(XmlName('key'), [], [
        XmlElement(XmlName('fifths'), [], [XmlText('$fifths')]),
      ]),
      _attributesOrder,
    );
    final count = doc.measureCount(partIndex);
    for (var i = measureIndex; i < count; i++) {
      final view = doc.measureAt(partIndex, i);
      if (i > measureIndex &&
          view.element
              .findElements('attributes')
              .any((a) => a.getElement('key') != null)) {
        break;
      }
      for (var staff = 1; staff <= view.staves; staff++) {
        view.refreshAccidentals(staff, PitchStep.values.toSet());
      }
    }
    return XmlEditResult(doc.toXml(), _barRef(partIndex, measureIndex));
  }

  /// Gives the bar a time signature, which holds until the next one. The
  /// notes of the bars are not rewritten.
  XmlEditResult setTimeSignature(
    String xml,
    int partIndex,
    int measureIndex,
    int beats,
    int beatType, {
    String? symbol,
  }) {
    if (beats < 1 || beats > 32 || !const {1, 2, 4, 8, 16}.contains(beatType)) {
      throw const FormatException('지원하지 않는 박자표입니다.');
    }
    final doc = _ScoreDoc(xml);
    final attributes = doc._firstAttributes(_bar(doc, partIndex, measureIndex));
    attributes.findElements('time').toList().forEach(_remove);
    _insertOrdered(
      attributes,
      XmlElement(
        XmlName('time'),
        [if (symbol != null) XmlAttribute(XmlName('symbol'), symbol)],
        [
          XmlElement(XmlName('beats'), [], [XmlText('$beats')]),
          XmlElement(XmlName('beat-type'), [], [XmlText('$beatType')]),
        ],
      ),
      _attributesOrder,
    );
    return XmlEditResult(doc.toXml(), _barRef(partIndex, measureIndex));
  }

  /// Gives a staff of the bar a clef, which holds until the next one.
  XmlEditResult setClef(
    String xml,
    int partIndex,
    int measureIndex,
    int staff,
    String sign,
    int line,
  ) {
    if (!const {
      ('G', 2),
      ('F', 4),
      ('C', 3),
      ('C', 4),
    }.contains((sign, line))) {
      throw const FormatException('지원하지 않는 음자리표입니다.');
    }
    final doc = _ScoreDoc(xml);
    final measure = _bar(doc, partIndex, measureIndex);
    final staves = doc.measureAt(partIndex, measureIndex).staves;
    if (staff < 1 || staff > staves) {
      throw const FormatException('없는 보표입니다.');
    }
    final attributes = doc._firstAttributes(measure);
    attributes
        .findElements('clef')
        .where(
          (c) => (int.tryParse(c.getAttribute('number') ?? '') ?? 1) == staff,
        )
        .toList()
        .forEach(_remove);
    _insertOrdered(
      attributes,
      XmlElement(
        XmlName('clef'),
        [if (staves > 1) XmlAttribute(XmlName('number'), '$staff')],
        [
          XmlElement(XmlName('sign'), [], [XmlText(sign)]),
          XmlElement(XmlName('line'), [], [XmlText('$line')]),
        ],
      ),
      _attributesOrder,
    );
    return XmlEditResult(doc.toXml(), _barRef(partIndex, measureIndex));
  }

  /// Opens a repeat at the start of the bar or closes one at its end, or
  /// takes the sign away again.
  XmlEditResult toggleRepeat(
    String xml,
    int partIndex,
    int measureIndex, {
    required bool start,
  }) {
    final doc = _ScoreDoc(xml);
    final measure = _bar(doc, partIndex, measureIndex);
    final location = start ? 'left' : 'right';
    final barline = _barlineOf(measure, location, create: true)!;
    final repeat = barline.getElement('repeat');
    if (repeat != null) {
      _remove(repeat);
      final style = barline.getElement('bar-style');
      if (style != null &&
          style.innerText.trim() == (start ? 'heavy-light' : 'light-heavy')) {
        _remove(style);
      }
    } else {
      _setChild(
        barline,
        'bar-style',
        start ? 'heavy-light' : 'light-heavy',
        _barlineOrder,
      );
      _insertOrdered(
        barline,
        XmlElement(XmlName('repeat'), [
          XmlAttribute(XmlName('direction'), start ? 'forward' : 'backward'),
        ]),
        _barlineOrder,
      );
    }
    _dropEmptyBarline(barline);
    return XmlEditResult(doc.toXml(), _barRef(partIndex, measureIndex));
  }

  /// How the bar ends: a plain, double or final barline ([barStyles]).
  XmlEditResult setBarStyle(
    String xml,
    int partIndex,
    int measureIndex,
    String style,
  ) {
    if (!barStyles.contains(style)) {
      throw const FormatException('지원하지 않는 세로줄입니다.');
    }
    final doc = _ScoreDoc(xml);
    final measure = _bar(doc, partIndex, measureIndex);
    final barline = _barlineOf(measure, 'right', create: true)!;
    if (style == 'regular') {
      // A closing repeat keeps its thick line.
      if (barline.getElement('repeat') == null) {
        barline.findElements('bar-style').toList().forEach(_remove);
      }
    } else {
      _setChild(barline, 'bar-style', style, _barlineOrder);
    }
    _dropEmptyBarline(barline);
    return XmlEditResult(doc.toXml(), _barRef(partIndex, measureIndex));
  }

  /// Begins ending [number] (a "1." or "2." bracket) at the start of the bar
  /// or ends it at the bar's end, or takes that mark away again.
  XmlEditResult toggleEnding(
    String xml,
    int partIndex,
    int measureIndex,
    int number, {
    required bool start,
  }) {
    if (number < 1 || number > 9) {
      throw const FormatException('괄호 번호는 1에서 9까지입니다.');
    }
    final doc = _ScoreDoc(xml);
    final measure = _bar(doc, partIndex, measureIndex);
    final barline = _barlineOf(
      measure,
      start ? 'left' : 'right',
      create: true,
    )!;
    final existing = barline.getElement('ending');
    final same =
        existing != null &&
        (existing.getAttribute('number') ?? '').trim() == '$number';
    existing?.let(_remove);
    if (!same) {
      _insertOrdered(
        barline,
        XmlElement(
          XmlName('ending'),
          [
            XmlAttribute(XmlName('number'), '$number'),
            XmlAttribute(
              XmlName('type'),
              start ? 'start' : (number == 1 ? 'stop' : 'discontinue'),
            ),
          ],
          [if (start) XmlText('$number.')],
        ),
        _barlineOrder,
      );
    }
    _dropEmptyBarline(barline);
    return XmlEditResult(doc.toXml(), _barRef(partIndex, measureIndex));
  }

  /// Writes a navigation sign at the bar, or takes it away. A bar has one
  /// jump at most: a new one replaces it.
  XmlEditResult setNavigationSign(
    String xml,
    int partIndex,
    int measureIndex,
    NavigationSign sign, {
    required bool on,
  }) {
    final doc = _ScoreDoc(xml);
    final measure = _bar(doc, partIndex, measureIndex);
    for (final direction in measure.findElements('direction').toList()) {
      final existing = _signOf(direction);
      if (existing == null) continue;
      if (existing == sign || (sign.isJump && existing.isJump)) {
        _remove(direction);
      }
    }
    if (on) {
      final (attribute, value) = sign.sound;
      final direction = XmlElement(
        XmlName('direction'),
        [XmlAttribute(XmlName('placement'), 'above')],
        [
          XmlElement(XmlName('direction-type'), [], [
            if (sign.atStart)
              XmlElement(XmlName(sign.name))
            else
              XmlElement(
                XmlName('words'),
                [XmlAttribute(XmlName('font-weight'), 'bold')],
                [XmlText(sign.words)],
              ),
          ]),
          XmlElement(XmlName('sound'), [
            XmlAttribute(XmlName(attribute), value),
          ]),
        ],
      );
      if (sign.atStart) {
        _insertAtStart(measure, direction);
      } else {
        _insertAtEnd(measure, direction);
      }
    }
    return XmlEditResult(doc.toXml(), _barRef(partIndex, measureIndex));
  }

  /// Names the bar with a rehearsal mark (a boxed "A" or "Verse"), in place
  /// of one already there; an empty [text] takes it away.
  XmlEditResult setRehearsalMark(
    String xml,
    int partIndex,
    int measureIndex,
    String text,
  ) {
    final doc = _ScoreDoc(xml);
    final measure = _bar(doc, partIndex, measureIndex);
    for (final direction in measure.findElements('direction').toList()) {
      if (direction.findAllElements('rehearsal').isNotEmpty) _remove(direction);
    }
    final name = text.trim();
    if (name.isNotEmpty) {
      if (name.length > 40) throw const FormatException('구간 이름이 너무 깁니다.');
      _insertAtStart(
        measure,
        XmlElement(
          XmlName('direction'),
          [XmlAttribute(XmlName('placement'), 'above')],
          [
            XmlElement(XmlName('direction-type'), [], [
              XmlElement(XmlName('rehearsal'), [], [XmlText(name)]),
            ]),
          ],
        ),
      );
    }
    return XmlEditResult(doc.toXml(), _barRef(partIndex, measureIndex));
  }

  /// Sets the tempo from the bar on (a metronome mark, with [text] such as
  /// "Andante" before it), in place of one already there; a null [bpm]
  /// takes the mark away.
  XmlEditResult setTempo(
    String xml,
    int partIndex,
    int measureIndex,
    int? bpm, {
    String beatUnit = 'quarter',
    String? text,
  }) {
    if (bpm != null && (bpm < 10 || bpm > 400)) {
      throw const FormatException('빠르기는 10에서 400까지입니다.');
    }
    if (!_typeQuarters.containsKey(beatUnit)) {
      throw const FormatException('지원하지 않는 박 단위입니다.');
    }
    final doc = _ScoreDoc(xml);
    final measure = _bar(doc, partIndex, measureIndex);
    for (final direction in measure.findElements('direction').toList()) {
      if (direction.findAllElements('metronome').isNotEmpty ||
          direction.getElement('sound')?.getAttribute('tempo') != null) {
        _remove(direction);
      }
    }
    final words = text?.trim() ?? '';
    if (bpm != null) {
      _insertAtStart(
        measure,
        XmlElement(
          XmlName('direction'),
          [XmlAttribute(XmlName('placement'), 'above')],
          [
            if (words.isNotEmpty)
              XmlElement(XmlName('direction-type'), [], [
                XmlElement(
                  XmlName('words'),
                  [XmlAttribute(XmlName('font-weight'), 'bold')],
                  [XmlText(words)],
                ),
              ]),
            XmlElement(XmlName('direction-type'), [], [
              XmlElement(XmlName('metronome'), [], [
                XmlElement(XmlName('beat-unit'), [], [XmlText(beatUnit)]),
                XmlElement(XmlName('per-minute'), [], [XmlText('$bpm')]),
              ]),
            ]),
            XmlElement(XmlName('sound'), [
              XmlAttribute(
                XmlName('tempo'),
                '${bpm * 4 ~/ (_typeQuarters[beatUnit]! * 4).round()}',
              ),
            ]),
          ],
        ),
      );
    }
    return XmlEditResult(doc.toXml(), _barRef(partIndex, measureIndex));
  }

  /// Writes a text above the start of the bar ("rit.", "with feeling").
  /// [XmlMeasureEditor.rewriteText] and [XmlMeasureEditor.removeText]
  /// change it afterwards.
  XmlEditResult addWords(
    String xml,
    int partIndex,
    int measureIndex,
    String text,
  ) {
    final words = text.trim();
    if (words.isEmpty) throw const FormatException('글자를 입력하세요.');
    if (words.length > 80) throw const FormatException('글자가 너무 깁니다.');
    final doc = _ScoreDoc(xml);
    _insertAtStart(
      _bar(doc, partIndex, measureIndex),
      XmlElement(
        XmlName('direction'),
        [XmlAttribute(XmlName('placement'), 'above')],
        [
          XmlElement(XmlName('direction-type'), [], [
            XmlElement(XmlName('words'), [], [XmlText(words)]),
          ]),
        ],
      ),
    );
    return XmlEditResult(doc.toXml(), _barRef(partIndex, measureIndex));
  }

  /// The signs written at a bar, for the tools to show what is set.
  XmlBarSigns barSigns(String xml, int partIndex, int measureIndex) {
    final doc = _ScoreDoc(xml);
    final measure = _bar(doc, partIndex, measureIndex);
    final signs = <NavigationSign>{};
    String? rehearsal;
    int? bpm;
    for (final direction in measure.findElements('direction')) {
      if (_signOf(direction) case final sign?) signs.add(sign);
      for (final mark in direction.findAllElements('rehearsal')) {
        rehearsal = mark.innerText.trim();
      }
      for (final metronome in direction.findAllElements('metronome')) {
        bpm = int.tryParse(
          metronome.getElement('per-minute')?.innerText.trim() ?? '',
        );
      }
    }
    final left = _barlineOf(measure, 'left', create: false);
    final right = _barlineOf(measure, 'right', create: false);
    doc.keep(xml);
    return XmlBarSigns(
      repeatStart: left?.getElement('repeat') != null,
      repeatEnd: right?.getElement('repeat') != null,
      barStyle: right?.getElement('bar-style')?.innerText.trim() ?? 'regular',
      endingStart: int.tryParse(
        left?.getElement('ending')?.getAttribute('number') ?? '',
      ),
      endingEnd: int.tryParse(
        right?.getElement('ending')?.getAttribute('number') ?? '',
      ),
      navigation: signs,
      rehearsal: rehearsal,
      tempoBpm: bpm,
      lineBreak: measure
          .findElements('print')
          .any((p) => p.getAttribute('new-system') == 'yes'),
      pageBreak: measure
          .findElements('print')
          .any((p) => p.getAttribute('new-page') == 'yes'),
    );
  }
}

/// What [XmlMeasureMarks.barSigns] found at a bar.
class XmlBarSigns {
  const XmlBarSigns({
    required this.repeatStart,
    required this.repeatEnd,
    required this.barStyle,
    required this.endingStart,
    required this.endingEnd,
    required this.navigation,
    required this.rehearsal,
    required this.tempoBpm,
    this.lineBreak = false,
    this.pageBreak = false,
  });

  final bool repeatStart;
  final bool repeatEnd;
  final String barStyle;
  final int? endingStart;
  final int? endingEnd;
  final Set<NavigationSign> navigation;
  final String? rehearsal;
  final int? tempoBpm;

  /// Whether the bar begins a new line, or a new page.
  final bool lineBreak;
  final bool pageBreak;
}

// --- Helpers ------------------------------------------------------------------

extension on XmlElement {
  void let(void Function(XmlNode) action) => action(this);
}

void _requirePlain(_NoteInfo info) {
  if (info.isGrace || info.isCue) {
    throw const FormatException('꾸밈음에는 할 수 없는 편집입니다.');
  }
  if (info.element.getElement('time-modification') != null) {
    throw const FormatException('잇단음표는 먼저 해제하세요.');
  }
}

String? _shorterType(String type) {
  final types = _typeQuarters.keys.toList();
  final at = types.indexOf(type);
  return at < 0 || at + 1 >= types.length ? null : types[at + 1];
}

double _quartersOf(String type, int dots) =>
    _typeQuarters[type]! * (2 - 1 / math.pow(2, dots));

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

/// Scales the bar's divisions until each of [quarters] is a whole number of
/// them, and returns the bar read again.
_MeasureView _fitDivisions(
  _ScoreDoc doc,
  XmlNoteRef ref,
  List<double> quarters,
) {
  var measure = doc.measure(ref);
  var multiplier = 1;
  for (final value in quarters) {
    final exact = measure.divisions * value;
    while (exact * multiplier != (exact * multiplier).roundToDouble()) {
      multiplier *= 2;
      if (multiplier > 64) throw const FormatException('지원하지 않는 음가입니다.');
    }
  }
  if (multiplier > 1) {
    doc.scaleDivisions(ref.partIndex, ref.measureIndex, multiplier);
    measure = doc.measure(ref);
  }
  return measure;
}

void _writeLength(XmlElement note, int duration, String type, int dots) {
  _setChild(note, 'duration', '$duration', _noteOrder);
  _setChild(note, 'type', type, _noteOrder);
  note.findElements('dot').toList().forEach(_remove);
  for (var i = 0; i < dots; i++) {
    _insertOrdered(note, XmlElement(XmlName('dot')), _noteOrder);
  }
  note.getElement('rest')?.removeAttribute('measure');
}

/// A copy of [note] as a new note next to it: no words, beams, accidental
/// or marks of its own, and no tie arriving at it. With [keepTieStart] a tie
/// leaving the original leaves the copy instead.
XmlElement _bareCopy(XmlElement note, {required bool keepTieStart}) {
  final copy = note.copy();
  for (final name in const ['lyric', 'beam', 'accidental', 'notations']) {
    copy.findElements(name).toList().forEach(_remove);
  }
  copy.findElements('tie').toList().forEach(_remove);
  if (keepTieStart && _hasTie(note, 'start')) {
    _addTieMarks(copy, 'start');
  }
  return copy;
}

void _addTieMarks(XmlElement note, String type) {
  if (!note.findElements('tie').any((t) => t.getAttribute('type') == type)) {
    _insertOrdered(
      note,
      XmlElement(XmlName('tie'), [XmlAttribute(XmlName('type'), type)]),
      _noteOrder,
    );
  }
  final notations = _notationsOf(note);
  if (!notations
      .findElements('tied')
      .any((t) => t.getAttribute('type') == type)) {
    notations.children.add(
      XmlElement(XmlName('tied'), [XmlAttribute(XmlName('type'), type)]),
    );
  }
}

XmlElement _notationsOf(XmlElement note) {
  final existing = note.getElement('notations');
  if (existing != null) return existing;
  final notations = XmlElement(XmlName('notations'));
  _insertOrdered(note, notations, _noteOrder);
  return notations;
}

void _insertAfter(XmlElement anchor, List<XmlElement> elements) {
  final children = anchor.parent!.children;
  children.insertAll(children.indexOf(anchor) + 1, elements);
}

MusicPitch _middle(_MeasureView measure, _NoteInfo at) {
  final (step, octave) = measure.middleLine(at.staff);
  return MusicPitch(
    step: step,
    octave: octave,
    alter: measure.contextAlter(at, step, octave),
  );
}

void _respell(_ScoreDoc doc, XmlNoteRef ref, List<_NoteInfo> group) {
  final steps = <int, Set<PitchStep>>{};
  for (final member in group) {
    if (member.pitch case final pitch?) {
      steps.putIfAbsent(member.staff, () => {}).add(pitch.step);
    }
  }
  for (final MapEntry(key: staff, value: set) in steps.entries) {
    doc.measure(ref).refreshAccidentals(staff, set);
  }
}

/// A voice that grew or shrank by [delta] moves the `<backup>` that follows
/// it, so the other voices keep their place. A note of another voice
/// written right after it, with no backup, cannot follow the change.
void _adjustFollowing(_ScoreDoc doc, XmlNoteRef ref, String voice, int delta) {
  if (delta == 0) return;
  final measure = doc.measure(ref);
  final groups = measure.voiceGroups(voice);
  if (groups.isEmpty) return;
  final following = measure.timingAfter(groups.last.last.element);
  if (following == null) return;
  if (following.name.local != 'backup') {
    throw const FormatException('여러 성부가 섞인 마디라 바꿀 수 없습니다.');
  }
  final duration = following.getElement('duration')!;
  duration.innerText = '${math.max(0, _duration(following) + delta)}';
}

List<XmlElement> _directionsBefore(XmlElement measure, XmlElement note) {
  final found = <XmlElement>[];
  final children = measure.childElements.toList();
  for (var i = children.indexOf(note) - 1; i >= 0; i--) {
    final child = children[i];
    switch (child.name.local) {
      case 'direction':
        found.add(child);
      case 'harmony' || 'print' || 'attributes' || 'barline':
        continue;
      default:
        return found;
    }
  }
  return found;
}

XmlElement _bar(_ScoreDoc doc, int partIndex, int measureIndex) {
  final measures = doc._measures(partIndex);
  if (measureIndex < 0 || measureIndex >= measures.length) {
    throw const FormatException('없는 마디입니다.');
  }
  return measures[measureIndex];
}

XmlNoteRef _barRef(int partIndex, int measureIndex) =>
    XmlNoteRef(partIndex: partIndex, measureIndex: measureIndex, noteIndex: 0);

XmlElement? _barlineOf(
  XmlElement measure,
  String location, {
  required bool create,
}) {
  for (final barline in measure.findElements('barline')) {
    final at = barline.getAttribute('location') ?? 'right';
    if (at == location) return barline;
  }
  if (!create) return null;
  final barline = XmlElement(XmlName('barline'), [
    XmlAttribute(XmlName('location'), location),
  ]);
  if (location == 'left') {
    _insertAtStart(measure, barline);
  } else {
    measure.children.add(barline);
  }
  return barline;
}

void _dropEmptyBarline(XmlElement? barline) {
  if (barline != null && barline.childElements.isEmpty) _remove(barline);
}

/// Puts [element] before the first music of the bar, after its print,
/// attributes and left barline.
void _insertAtStart(XmlElement measure, XmlElement element) {
  var at = measure.children.length;
  for (var i = 0; i < measure.children.length; i++) {
    final child = measure.children[i];
    if (child is! XmlElement) continue;
    final name = child.name.local;
    final leading =
        name == 'print' ||
        name == 'attributes' ||
        (name == 'barline' && child.getAttribute('location') == 'left');
    if (!leading) {
      at = i;
      break;
    }
  }
  measure.children.insert(at, element);
}

/// Puts [element] after the last music of the bar, before its right
/// barline.
void _insertAtEnd(XmlElement measure, XmlElement element) {
  var at = measure.children.length;
  for (var i = measure.children.length - 1; i >= 0; i--) {
    final child = measure.children[i];
    if (child is XmlElement &&
        child.name.local == 'barline' &&
        (child.getAttribute('location') ?? 'right') == 'right') {
      at = i;
    } else if (child is XmlElement) {
      break;
    }
  }
  measure.children.insert(at, element);
}

NavigationSign? _signOf(XmlElement direction) {
  final sound = direction.getElement('sound');
  final types = direction.findElements('direction-type');
  final words = types
      .expand((t) => t.findElements('words'))
      .map((w) => w.innerText.trim().toLowerCase())
      .join(' ');
  if (types.any((t) => t.getElement('segno') != null)) {
    return NavigationSign.segno;
  }
  if (types.any((t) => t.getElement('coda') != null)) {
    return NavigationSign.coda;
  }
  if (sound?.getAttribute('dalsegno') != null) {
    return words.contains('fine')
        ? NavigationSign.dsAlFine
        : NavigationSign.dsAlCoda;
  }
  if (sound?.getAttribute('dacapo') != null) {
    return words.contains('coda')
        ? NavigationSign.dcAlCoda
        : NavigationSign.dcAlFine;
  }
  if (sound?.getAttribute('tocoda') != null) return NavigationSign.toCoda;
  if (sound?.getAttribute('fine') != null) return NavigationSign.fine;
  return null;
}
