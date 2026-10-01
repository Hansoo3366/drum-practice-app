import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:xml/xml.dart';

const _editor = XmlMeasureEditor();
const _codec = MusicXmlCodec();

typedef _Edit = XmlEditResult Function(String xml, XmlNoteRef ref);

final _edits = <String, _Edit>{
  'up': (xml, ref) => _editor.moveDiatonic(xml, ref, 1),
  'down': (xml, ref) => _editor.moveDiatonic(xml, ref, -1),
  'octave': (xml, ref) => _editor.shiftOctave(xml, ref, -1),
  'sharp': (xml, ref) => _editor.setAlter(xml, ref, 1),
  'natural': (xml, ref) => _editor.setAlter(xml, ref, 0),
  'chord': _editor.addChordNote,
  'delete': _editor.deleteNote,
  'toNote': _editor.restToNote,
  'eighth': (xml, ref) => _editor.setDuration(xml, ref, 'eighth', 0),
  'half': (xml, ref) => _editor.setDuration(xml, ref, 'half', 0),
  'dotted': (xml, ref) => _editor.setDuration(xml, ref, 'quarter', 1),
  'harmony': (xml, ref) => _editor.setHarmony(xml, ref, 'F#m7'),
};

/// Quarter-note length of each voice in a decoded measure.
Map<String, double> _voiceLengths(MusicMeasure measure) {
  final lengths = <String, double>{};
  for (final note in measure.notes) {
    if (note.isGrace) continue;
    final end = note.end / measure.attributes.divisions;
    lengths[note.voice] = (lengths[note.voice] ?? 0) < end
        ? end
        : lengths[note.voice]!;
  }
  return lengths;
}

/// Measure chunks of XML produced by the xml package's serializer. The
/// editor returns `XmlDocument.toXmlString()`, so a textual split is enough to
/// compare untouched measures without re-parsing every result.
List<String> _measureXml(String serialized) =>
    serialized.split(RegExp(r'(?=<measure[ >])')).skip(1).toList();

void _checkCorpus(
  String name,
  String xml, {
  int measureLimit = 4,
  int noteStride = 5,
}) {
  final original = _codec.decodeXml(xml);
  final originalMeasures = _measureXml(XmlDocument.parse(xml).toXmlString());
  final applied = <String, int>{};
  final refused = <String>{};
  for (var partIndex = 0; partIndex < original.parts.length; partIndex++) {
    final part = original.parts[partIndex];
    final limit = part.measures.length < measureLimit
        ? part.measures.length
        : measureLimit;
    for (var measureIndex = 0; measureIndex < limit; measureIndex++) {
      final measure = part.measures[measureIndex];
      final noteCount = measure.notes.length;
      for (
        var noteIndex = measureIndex % noteStride;
        noteIndex < noteCount;
        noteIndex += noteStride
      ) {
        final ref = XmlNoteRef(
          partIndex: partIndex,
          measureIndex: measureIndex,
          noteIndex: noteIndex,
        );
        for (final MapEntry(key: label, value: edit) in _edits.entries) {
          final where =
              '$name p$partIndex m${measureIndex + 1} '
              'n$noteIndex $label';
          XmlEditResult result;
          try {
            result = edit(xml, ref);
          } on FormatException catch (error) {
            expect(error.message, isNotEmpty, reason: where);
            refused.add('$label: ${error.message}');
            continue;
          } on Object catch (error, stack) {
            fail('$where threw ${error.runtimeType}: $error\n$stack');
          }
          applied[label] = (applied[label] ?? 0) + 1;

          final MusicScore edited;
          try {
            edited = _codec.decodeXml(result.xml);
          } on Object catch (error) {
            fail('$where produced unreadable XML: $error');
          }
          final editedPart = edited.parts[partIndex];
          expect(
            editedPart.measures.length,
            part.measures.length,
            reason: where,
          );
          final before = _voiceLengths(measure);
          final after = _voiceLengths(editedPart.measures[measureIndex]);
          final time = measure.attributes.time;
          final bar = time == null ? 4.0 : time.beats * 4 / time.beatType;
          expect(after.keys.toSet(), before.keys.toSet(), reason: where);
          for (final voice in before.keys) {
            // Incomplete converted bars may be filled up to the bar length.
            final grew = after[voice]! > before[voice]!;
            expect(
              grew
                  ? after[voice]! <= bar + 1e-9
                  : after[voice] == before[voice],
              isTrue,
              reason:
                  '$where changed voice $voice length '
                  '${before[voice]} -> ${after[voice]}',
            );
          }
          final editedMeasures = _measureXml(result.xml);
          final measureOffset = original.parts
              .take(partIndex)
              .fold<int>(0, (sum, p) => sum + p.measures.length);
          for (var i = 0; i < editedMeasures.length; i++) {
            final local = i - measureOffset;
            final nearby =
                local >= measureIndex - 1 && local <= measureIndex + 1;
            // Tie chains can reach one bar away, and divisions are restored
            // in the next bar; everything else must be byte-identical.
            if (nearby) continue;
            expect(
              editedMeasures[i],
              originalMeasures[i],
              reason: '$where touched unrelated measure ${i + 1}',
            );
          }
          final selected = result.selection;
          expect(selected.measureIndex, measureIndex, reason: where);
          expect(
            selected.noteIndex,
            inInclusiveRange(
              0,
              editedPart.measures[measureIndex].notes.length - 1,
            ),
            reason: where,
          );
        }
      }
    }
  }
  // Every operation must succeed somewhere in a real score.
  for (final label in _edits.keys) {
    if (label == 'toNote' && !refused.any((r) => r.startsWith('toNote'))) {
      continue;
    }
    expect(
      applied[label] ?? 0,
      greaterThan(0),
      reason: '$name never ran $label',
    );
  }
}

String _asset(String path) {
  final bytes = Uint8List.fromList(File(path).readAsBytesSync());
  return _codec.xmlString(bytes, fileName: path);
}

void main() {
  test(
    'Clair de lune: every edit is readable and keeps bar lengths',
    () {
      _checkCorpus(
        'clair',
        _asset('assets/scores/clair-de-lune-claude-debussy.mxl'),
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'Fantaisie-Impromptu: every edit is readable and keeps bar lengths',
    () {
      _checkCorpus(
        'fantaisie',
        _asset('assets/scores/fantaisie-impromptu-in-c-minor-chopin.mxl'),
        measureLimit: 3,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  final extra = Platform.environment['XML_EDITOR_CORPUS'];
  test(
    'extra corpus from XML_EDITOR_CORPUS',
    () {
      _checkCorpus('extra', _asset(extra!), measureLimit: 120, noteStride: 1);
    },
    skip: extra == null,
    timeout: const Timeout(Duration(minutes: 40)),
  );
}
