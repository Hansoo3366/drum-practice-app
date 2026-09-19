import 'dart:typed_data';

import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';

class MidiCodec {
  const MidiCodec();

  static const int ticksPerQuarter = 480;

  Uint8List encode(MusicScore score) {
    final tracks = <List<int>>[
      _metaTrack(score),
      for (final part in score.parts) _partTrack(part),
    ];
    final output = BytesBuilder(copy: false);
    output.add('MThd'.codeUnits);
    _writeInt(output, 6, 4);
    _writeInt(output, 1, 2);
    _writeInt(output, tracks.length, 2);
    _writeInt(output, ticksPerQuarter, 2);
    for (final track in tracks) {
      output.add('MTrk'.codeUnits);
      _writeInt(output, track.length, 4);
      output.add(track);
    }
    return output.toBytes();
  }

  List<int> _metaTrack(MusicScore score) {
    final attributes = score.parts.first.measures.first.attributes;
    final time =
        attributes.time ?? const MusicTimeSignature(beats: 4, beatType: 4);
    final tempo = _tempoMicros(score.tempoBpm);
    final events = <_MidiEvent>[
      _MidiEvent(0, [
        0xff,
        0x51,
        0x03,
        (tempo >> 16) & 0xff,
        (tempo >> 8) & 0xff,
        tempo & 0xff,
      ]),
      _MidiEvent(0, [
        0xff,
        0x58,
        0x04,
        time.beats,
        _beatTypeExponent(time.beatType),
        24,
        8,
      ]),
      _MidiEvent(0, [
        0xff,
        0x59,
        0x02,
        attributes.keyFifths & 0xff,
        attributes.keyMode == 'minor' ? 1 : 0,
      ]),
      const _MidiEvent(0, [0xff, 0x2f, 0x00]),
    ];
    return _encodeTrack(events);
  }

  List<int> _partTrack(MusicPart part) {
    final events = <_MidiEvent>[];
    var measureStart = 0;
    for (final measure in part.measures) {
      final divisions = measure.attributes.divisions;
      for (final note in measure.notes) {
        final pitch = note.pitch;
        if (pitch == null || note.isGrace) continue;
        final start = measureStart + _toTicks(note.onset, divisions);
        final end =
            start + _toTicks(note.duration, divisions).clamp(1, 1 << 20);
        final midi = pitch.midi.clamp(0, 127);
        final channel = (note.staff - 1).clamp(0, 15);
        events.add(_MidiEvent(start, [0x90 | channel, midi, 80]));
        events.add(_MidiEvent(end, [0x80 | channel, midi, 0]));
      }
      measureStart += _toTicks(measureCapacity(measure.attributes), divisions);
    }
    events.add(_MidiEvent(measureStart, const [0xff, 0x2f, 0x00]));
    return _encodeTrack(events);
  }

  List<int> _encodeTrack(List<_MidiEvent> events) {
    events.sort((left, right) {
      final tick = left.tick.compareTo(right.tick);
      if (tick != 0) return tick;
      return left.bytes.first.compareTo(right.bytes.first);
    });
    final output = BytesBuilder(copy: false);
    var cursor = 0;
    for (final event in events) {
      output.add(_variableLength(event.tick - cursor));
      output.add(event.bytes);
      cursor = event.tick;
    }
    return output.toBytes();
  }

  int _toTicks(int divisionsValue, int divisions) {
    return ((divisionsValue * ticksPerQuarter) / divisions).round();
  }

  int _tempoMicros(double? bpm) {
    final value = bpm == null || bpm <= 0 ? 120.0 : bpm;
    return (60000000 / value).round().clamp(1, 0xffffff);
  }

  int _beatTypeExponent(int beatType) {
    var exponent = 0;
    var value = beatType;
    while (value > 1) {
      value >>= 1;
      exponent++;
    }
    return exponent;
  }

  void _writeInt(BytesBuilder output, int value, int size) {
    for (var shift = (size - 1) * 8; shift >= 0; shift -= 8) {
      output.addByte((value >> shift) & 0xff);
    }
  }

  List<int> _variableLength(int value) {
    var current = value;
    final bytes = <int>[current & 0x7f];
    current >>= 7;
    while (current > 0) {
      bytes.insert(0, (current & 0x7f) | 0x80);
      current >>= 7;
    }
    return bytes;
  }
}

class _MidiEvent {
  const _MidiEvent(this.tick, this.bytes);

  final int tick;
  final List<int> bytes;
}
