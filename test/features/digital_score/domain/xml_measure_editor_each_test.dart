import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';

// An edit made to each of many notes in one go must come to the very score
// that making it note by note comes to, whatever the edit and however many
// of the notes refuse it.

const _editor = XmlMeasureEditor();
const _codec = MusicXmlCodec();

String _clair() {
  const path = 'assets/scores/clair-de-lune-claude-debussy.mxl';
  return _codec.xmlString(
    Uint8List.fromList(File(path).readAsBytesSync()),
    fileName: path,
  );
}

List<XmlNoteRef> _refs(String xml, {int? bars}) {
  final measures = _codec.decodeXml(xml).parts.first.measures;
  return [
    for (final (bar, measure) in measures.indexed)
      if (bars == null || bar < bars)
        for (var note = 0; note < measure.notes.length; note++)
          XmlNoteRef(partIndex: 0, measureIndex: bar, noteIndex: note),
  ];
}

/// Note by note, each edit writing the score out: what [editEach] spares.
String _oneByOne(
  String xml,
  Iterable<XmlNoteRef> refs,
  XmlEditResult? Function(String xml, XmlNoteRef ref) edit,
) {
  var current = xml;
  for (final ref in refs) {
    try {
      current = edit(current, ref)?.xml ?? current;
    } on FormatException {
      // passed over
    }
  }
  return current;
}

void main() {
  final edits = <String, XmlEditResult? Function(String, XmlNoteRef)>{
    'a staccato': (xml, ref) =>
        _editor.toggleArticulation(xml, ref, 'staccato'),
    'an octave up': (xml, ref) => _editor.shiftOctave(xml, ref, 1),
    'a step down': (xml, ref) => _editor.moveDiatonic(xml, ref, -1),
    // Refused by most notes of a bar that is full.
    'a longer value': (xml, ref) => _editor.setDuration(xml, ref, 'half', 0),
    'a shorter value': (xml, ref) => _editor.setDuration(xml, ref, '16th', 0),
    'a tie': _editor.toggleTie,
    'a syllable': (xml, ref) => _editor.setLyric(xml, ref, '가', verse: 1),
    'a fingering': (xml, ref) => _editor.setFingering(xml, ref, 3),
    'hidden': _editor.toggleHidden,
    // Every other note is left alone.
    'every other note': (xml, ref) => ref.noteIndex.isOdd
        ? null
        : _editor.toggleArticulation(xml, ref, 'accent'),
  };

  for (final MapEntry(key: name, value: edit) in edits.entries) {
    test('$name on every note of twelve bars, at once as one by one', () {
      final xml = _clair();
      final refs = _refs(xml, bars: 12);
      expect(refs.length, greaterThan(100));
      final atOnce = _editor.editEach(xml, refs, edit);
      expect(atOnce.xml == _oneByOne(xml, refs, edit), isTrue);
      // What it wrote is a score.
      _codec.decodeXml(atOnce.xml);
    });
  }

  test('notes taken out from the last to the first, at once as one by one', () {
    final xml = _clair();
    final refs = _refs(xml, bars: 8).reversed.toList();
    XmlEditResult? edit(String xml, XmlNoteRef ref) =>
        _editor.deleteNote(xml, ref);
    final atOnce = _editor.editEach(xml, refs, edit);
    expect(atOnce.xml == _oneByOne(xml, refs, edit), isTrue);
    expect(atOnce.done, greaterThan(50));
  });

  test('a whole piano piece is not written out once per note', () {
    final xml = _clair();
    final refs = _refs(xml);
    expect(refs.length, greaterThan(1500));
    final watch = Stopwatch()..start();
    final result = _editor.editEach(
      xml,
      refs,
      (xml, ref) => _editor.toggleArticulation(xml, ref, 'staccato'),
    );
    final atOnce = watch.elapsedMilliseconds;
    expect(result.done, greaterThan(1000));
    // One by one, on a part of it, to compare like with like.
    final part = refs.take(200).toList();
    watch.reset();
    _oneByOne(
      xml,
      part,
      (xml, ref) => _editor.toggleArticulation(xml, ref, 'staccato'),
    );
    final perNote = watch.elapsedMilliseconds / part.length;
    printOnFailure(
      'at once $atOnce ms, one by one ${perNote * refs.length} ms',
    );
    expect(atOnce, lessThan(perNote * refs.length / 2));
  });

  test('few notes are edited the plain way, with the same result', () {
    final xml = _clair();
    final refs = _refs(xml, bars: 1).take(5).toList();
    XmlEditResult? edit(String xml, XmlNoteRef ref) =>
        _editor.shiftOctave(xml, ref, -1);
    expect(
      _editor.editEach(xml, refs, edit).xml == _oneByOne(xml, refs, edit),
      isTrue,
    );
  });
}
