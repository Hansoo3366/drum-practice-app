import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';

void main() {
  test('MusicXML encodes into flutter_notemus Score and MIDI', () {
    final bytes = File(
      'assets/scores/fantaisie-impromptu-in-c-minor-chopin.mxl',
    ).readAsBytesSync();
    final score = const MusicXmlCodec().decode(
      Uint8List.fromList(bytes),
      fileName: 'fantaisie.mxl',
    );
    final out = utf8.decode(const MusicXmlCodec().encodeMusicXml(score));
    final engraved = nm.MusicXMLParser.scoreFromMusicXML(out);
    final midi = nm.MidiMapper.fromScore(engraved);

    expect(score.measureCount, greaterThan(0));
    expect(engraved.allStaves, isNotEmpty);
    expect(midi.totalTicks, greaterThan(0));
  });
}
