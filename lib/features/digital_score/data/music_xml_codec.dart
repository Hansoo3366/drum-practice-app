import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:xml/xml.dart';

enum MusicXmlFileFormat { musicXml, mxl }

class MusicXmlCodec {
  const MusicXmlCodec();

  static const int maxScoreBytes = 20 * 1024 * 1024;
  static const int maxArchiveBytes = 64 * 1024 * 1024;
  static const int maxArchiveEntries = 256;
  static const String compressedMimeType = 'application/vnd.recordare.musicxml';

  MusicScore decode(Uint8List bytes, {String? fileName}) {
    if (bytes.isEmpty) {
      throw const FormatException('The MusicXML file is empty.');
    }
    if (bytes.length > maxArchiveBytes) {
      throw const FormatException('The score file is too large.');
    }

    final compressed =
        _looksLikeZip(bytes) ||
        (fileName?.toLowerCase().endsWith('.mxl') ?? false);
    final xmlBytes = compressed ? _readMxl(bytes) : bytes;
    return decodeXml(utf8.decode(xmlBytes, allowMalformed: false));
  }

  String xmlString(Uint8List bytes, {String? fileName}) {
    final compressed =
        _looksLikeZip(bytes) ||
        (fileName?.toLowerCase().endsWith('.mxl') ?? false);
    final xmlBytes = compressed ? _readMxl(bytes) : bytes;
    return utf8.decode(xmlBytes, allowMalformed: false);
  }

  MusicScore decodeXml(String source) {
    final document = _parseXml(source, label: 'MusicXML');
    final root = _scorePartwiseOf(document.rootElement);
    if (root == null) {
      throw FormatException(_unsupportedScoreMessage(document.rootElement));
    }

    final partNames = <String, String>{};
    final partList = _firstChild(root, 'part-list');
    if (partList == null) {
      throw const FormatException('MusicXML part-list is required.');
    }
    for (final scorePart in _children(partList, 'score-part')) {
      final id = scorePart.getAttribute('id')?.trim();
      if (id == null || id.isEmpty) continue;
      partNames[id] = _childText(scorePart, 'part-name') ?? id;
    }

    double? firstTempo;
    final parts = <MusicPart>[];
    for (final partElement in _children(root, 'part')) {
      final id = partElement.getAttribute('id')?.trim();
      if (id == null || id.isEmpty) {
        throw const FormatException('Every MusicXML part needs an id.');
      }

      var attributes = MusicAttributes(divisions: 1);
      final measures = <MusicMeasure>[];
      for (final measureElement in _children(partElement, 'measure')) {
        final parsed = _parseMeasure(measureElement, attributes);
        attributes = parsed.attributes;
        firstTempo ??= parsed.firstTempo;
        measures.add(parsed.measure);
      }
      if (measures.isEmpty) {
        throw FormatException('MusicXML part $id has no measures.');
      }
      parts.add(
        MusicPart(
          id: id,
          name: partNames[id] ?? id,
          measures: List.unmodifiable(measures),
        ),
      );
    }

    if (parts.isEmpty) {
      throw const FormatException('MusicXML must contain at least one part.');
    }

    final title = _nonEmpty(
      _childText(root, 'movement-title') ??
          _childText(_firstChild(root, 'work'), 'work-title'),
    );
    final identification = _firstChild(root, 'identification');
    final composer = identification == null
        ? null
        : _children(identification, 'creator')
              .where(
                (element) =>
                    (element.getAttribute('type') ?? '').toLowerCase() ==
                    'composer',
              )
              .map((element) => _nonEmpty(element.innerText))
              .whereType<String>()
              .firstOrNull;

    return MusicScore(
      title: title,
      composer: composer,
      tempoBpm: firstTempo,
      musicXmlVersion: root.getAttribute('version') ?? '1.0',
      parts: List.unmodifiable(parts),
    );
  }

  Uint8List encode(MusicScore score, MusicXmlFileFormat format) {
    final xmlBytes = encodeMusicXml(score);
    if (format == MusicXmlFileFormat.musicXml) {
      return xmlBytes;
    }

    final archive = Archive();
    final mimeBytes = ascii.encode(compressedMimeType);
    archive.add(
      ArchiveFile.noCompress('mimetype', mimeBytes.length, mimeBytes),
    );
    archive.add(
      ArchiveFile.string(
        'META-INF/container.xml',
        '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<container version="1.0" '
            'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
            '<rootfiles><rootfile full-path="score.musicxml" '
            'media-type="$compressedMimeType+xml"/></rootfiles>'
            '</container>',
      ),
    );
    archive.add(ArchiveFile.bytes('score.musicxml', xmlBytes));
    return ZipEncoder().encodeBytes(archive);
  }

  Uint8List encodeMusicXml(MusicScore score) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'score-partwise',
      attributes: {'version': '4.0'},
      nest: () {
        if (_nonEmpty(score.title) case final title?) {
          builder.element('movement-title', nest: title);
        }
        if (_nonEmpty(score.composer) case final composer?) {
          builder.element(
            'identification',
            nest: () {
              builder.element(
                'creator',
                attributes: {'type': 'composer'},
                nest: composer,
              );
            },
          );
        }
        builder.element(
          'part-list',
          nest: () {
            for (final part in score.parts) {
              builder.element(
                'score-part',
                attributes: {'id': part.id},
                nest: () => builder.element('part-name', nest: part.name),
              );
            }
          },
        );
        for (var partIndex = 0; partIndex < score.parts.length; partIndex++) {
          final part = score.parts[partIndex];
          builder.element(
            'part',
            attributes: {'id': part.id},
            nest: () {
              MusicAttributes? previousAttributes;
              for (
                var measureIndex = 0;
                measureIndex < part.measures.length;
                measureIndex++
              ) {
                final measure = part.measures[measureIndex];
                builder.element(
                  'measure',
                  attributes: {
                    'number': measure.number,
                    if (measure.implicit) 'implicit': 'yes',
                  },
                  nest: () => _writeMeasure(
                    builder,
                    measure,
                    partIndex: partIndex,
                    measureIndex: measureIndex,
                    previousAttributes: previousAttributes,
                    fallbackTempo: partIndex == 0 && measureIndex == 0
                        ? score.tempoBpm
                        : null,
                  ),
                );
                previousAttributes = measure.attributes;
              }
            },
          );
        }
      },
    );
    return Uint8List.fromList(
      utf8.encode(builder.buildDocument().toXmlString(pretty: true)),
    );
  }

  _ParsedMeasure _parseMeasure(
    XmlElement measureElement,
    MusicAttributes inherited,
  ) {
    var attributes = inherited;
    var cursor = 0;
    var previousNoteOnset = 0;
    double? firstTempo;
    final events = <MusicEvent>[];
    final barlines = <MusicBarline>[];

    for (final child in measureElement.childElements) {
      switch (child.name.local) {
        case 'attributes':
          attributes = _parseAttributes(child, attributes);
        case 'backup':
          // A backup longer than what came before it (a recogniser leaves
          // such bars) goes to the start of the bar; the score still opens.
          cursor = math.max(
            0,
            cursor - _requiredPositiveInt(child, 'duration'),
          );
        case 'forward':
          cursor += _requiredPositiveInt(child, 'duration');
        case 'note':
          if (_firstChild(child, 'unpitched') != null) {
            throw const FormatException(
              'Unpitched notes are not supported in a piano score.',
            );
          }
          final isGrace = _firstChild(child, 'grace') != null;
          final isChord = _firstChild(child, 'chord') != null;
          final duration = isGrace
              ? 0
              : _requiredPositiveInt(child, 'duration');
          final onset = isChord ? previousNoteOnset : cursor;
          final pitchElement = _firstChild(child, 'pitch');
          MusicPitch? pitch;
          if (pitchElement != null) {
            pitch = MusicPitch(
              step: PitchStepMusicXml.parse(
                _requiredChildText(pitchElement, 'step'),
              ),
              alter: _intText(pitchElement, 'alter') ?? 0,
              octave: _requiredInt(pitchElement, 'octave'),
            );
          } else if (_firstChild(child, 'rest') == null) {
            throw const FormatException('A note needs pitch or rest data.');
          }
          final ties = _children(
            child,
            'tie',
          ).map((element) => element.getAttribute('type')).toSet();
          final notations = _firstChild(child, 'notations');
          final tied = notations == null
              ? const <String>{}
              : _children(
                  notations,
                  'tied',
                ).map((element) => element.getAttribute('type')).toSet();
          final slurs = notations == null
              ? const <String>{}
              : _children(
                  notations,
                  'slur',
                ).map((element) => element.getAttribute('type')).toSet();
          final beams = _children(child, 'beam')
              .map(
                (element) => MusicBeam(
                  number:
                      int.tryParse(element.getAttribute('number') ?? '') ?? 1,
                  value: element.innerText.trim(),
                ),
              )
              .where((beam) => beam.value.isNotEmpty)
              .toList(growable: false);
          events.add(
            MusicNote(
              onset: onset,
              duration: duration,
              voice: _childText(child, 'voice') ?? '1',
              staff: _intText(child, 'staff') ?? 1,
              pitch: pitch,
              type: _nonEmpty(_childText(child, 'type')),
              dots: _children(child, 'dot').length,
              isGrace: isGrace,
              isChord: isChord,
              tieStart: ties.contains('start') || tied.contains('start'),
              tieStop: ties.contains('stop') || tied.contains('stop'),
              slurStart: slurs.contains('start'),
              slurStop: slurs.contains('stop'),
              beams: beams,
              lyrics: [
                for (final lyric in _children(child, 'lyric'))
                  lyric.toXmlString(),
              ],
            ),
          );
          previousNoteOnset = onset;
          if (!isGrace) {
            final noteEnd = onset + duration;
            if (!isChord || noteEnd > cursor) cursor = noteEnd;
          }
        case 'direction':
          final direction = _parseDirection(child, cursor);
          if (direction != null) {
            events.add(direction);
            firstTempo ??= direction.tempoBpm;
          }
        case 'sound':
          final tempo = _plausibleTempo(_doubleAttribute(child, 'tempo'));
          final navigation = _soundNavigation(child);
          if ((tempo != null && tempo > 0) || navigation != null) {
            events.add(
              MusicDirection(
                onset: cursor,
                staff: 1,
                tempoBpm: tempo != null && tempo > 0 ? tempo : null,
                navigation: navigation,
              ),
            );
            if (tempo != null && tempo > 0) firstTempo ??= tempo;
          }
        case 'harmony':
          events.add(_parseHarmony(child, cursor));
        case 'barline':
          barlines.add(_parseBarline(child));
      }
    }

    final number = measureElement.getAttribute('number')?.trim();
    final measure = MusicMeasure(
      number: number == null || number.isEmpty ? '1' : number,
      attributes: attributes,
      events: List.unmodifiable(events),
      implicit: measureElement.getAttribute('implicit') == 'yes',
      barlines: barlines,
    );
    return _ParsedMeasure(
      measure: measure,
      attributes: attributes,
      firstTempo: firstTempo,
    );
  }

  MusicAttributes _parseAttributes(
    XmlElement element,
    MusicAttributes inherited,
  ) {
    var clefs = inherited.clefs;
    final clefElements = _children(element, 'clef');
    if (clefElements.isNotEmpty) {
      final next = <int, MusicClef>{...inherited.clefs};
      for (final clefElement in clefElements) {
        final staff =
            int.tryParse(clefElement.getAttribute('number') ?? '') ?? 1;
        next[staff] = MusicClef(
          sign: _requiredChildText(clefElement, 'sign'),
          line: _requiredInt(clefElement, 'line'),
          octaveChange: _intText(clefElement, 'clef-octave-change') ?? 0,
        );
      }
      clefs = next;
    }

    final timeElement = _firstChild(element, 'time');
    final time = timeElement == null
        ? inherited.time
        : MusicTimeSignature(
            beats: _requiredInt(timeElement, 'beats'),
            beatType: _requiredInt(timeElement, 'beat-type'),
            symbol: switch (timeElement.getAttribute('symbol')) {
              'common' => MusicTimeSymbol.common,
              'cut' => MusicTimeSymbol.cut,
              _ => null,
            },
          );
    final keyElement = _firstChild(element, 'key');
    return MusicAttributes(
      divisions: _intText(element, 'divisions') ?? inherited.divisions,
      keyFifths: keyElement == null
          ? inherited.keyFifths
          : (_intText(keyElement, 'fifths') ?? inherited.keyFifths),
      keyMode: keyElement == null
          ? inherited.keyMode
          : (_childText(keyElement, 'mode') ?? inherited.keyMode),
      time: time,
      staves: _intText(element, 'staves') ?? inherited.staves,
      clefs: clefs,
    );
  }

  MusicDirection? _parseDirection(XmlElement element, int cursor) {
    final directionTypes = _children(element, 'direction-type');
    final rehearsal = directionTypes
        .map((type) => _childText(type, 'rehearsal'))
        .whereType<String>()
        .map(_nonEmpty)
        .whereType<String>()
        .firstOrNull;
    final words = directionTypes
        .map((type) => _childText(type, 'words'))
        .whereType<String>()
        .map(_nonEmpty)
        .whereType<String>()
        .firstOrNull;
    final sound = _firstChild(element, 'sound');
    final navigation =
        _soundNavigation(sound) ??
        (directionTypes.any((type) => _firstChild(type, 'segno') != null)
            ? MusicNavigation.segno
            : directionTypes.any((type) => _firstChild(type, 'coda') != null)
            ? MusicNavigation.coda
            : null);
    var tempo = _plausibleTempo(
      sound == null ? null : _doubleAttribute(sound, 'tempo'),
    );
    if (tempo == null) {
      for (final type in directionTypes) {
        final metronome = _firstChild(type, 'metronome');
        if (metronome != null) {
          tempo = _plausibleTempo(
            double.tryParse(_childText(metronome, 'per-minute') ?? ''),
          );
          if (tempo != null) break;
        }
      }
    }
    if (rehearsal == null &&
        words == null &&
        tempo == null &&
        navigation == null) {
      return null;
    }
    final offset = _intText(element, 'offset') ?? 0;
    return MusicDirection(
      onset: cursor + offset,
      staff: _intText(element, 'staff') ?? 1,
      rehearsal: rehearsal,
      words: words,
      tempoBpm: tempo != null && tempo > 0 ? tempo : null,
      navigation: navigation,
    );
  }

  /// A tempo a player could use; OMR reads stray text as metronome marks
  /// ("1cz" → 1 BPM, 9484 BPM), which would stretch playback to hours.
  static double? _plausibleTempo(double? bpm) =>
      bpm != null && bpm >= 20 && bpm <= 400 ? bpm : null;

  /// The jump a `<sound>` asks for. Jumps outrank the signs they point to.
  MusicNavigation? _soundNavigation(XmlElement? sound) {
    if (sound == null) return null;
    bool has(String name) => _nonEmpty(sound.getAttribute(name)) != null;
    if (has('dalsegno')) return MusicNavigation.dalSegno;
    if (has('dacapo') && sound.getAttribute('dacapo') != 'no') {
      return MusicNavigation.daCapo;
    }
    if (has('tocoda')) return MusicNavigation.toCoda;
    if (has('fine')) return MusicNavigation.fine;
    if (has('segno')) return MusicNavigation.segno;
    if (has('coda')) return MusicNavigation.coda;
    return null;
  }

  MusicHarmony _parseHarmony(XmlElement element, int cursor) {
    final root = _firstChild(element, 'root');
    if (root == null) {
      throw const FormatException('Harmony root is required.');
    }
    final bass = _firstChild(element, 'bass');
    final kindElement = _firstChild(element, 'kind');
    return MusicHarmony(
      onset: cursor + (_intText(element, 'offset') ?? 0),
      staff: _intText(element, 'staff') ?? 1,
      rootStep: PitchStepMusicXml.parse(_requiredChildText(root, 'root-step')),
      rootAlter: _intText(root, 'root-alter') ?? 0,
      kind: _nonEmpty(kindElement?.innerText) ?? 'none',
      kindText: _nonEmpty(kindElement?.getAttribute('text')),
      bassStep: bass == null
          ? null
          : PitchStepMusicXml.parse(_requiredChildText(bass, 'bass-step')),
      bassAlter: bass == null ? 0 : (_intText(bass, 'bass-alter') ?? 0),
    );
  }

  void _writeMeasure(
    XmlBuilder builder,
    MusicMeasure measure, {
    required int partIndex,
    required int measureIndex,
    MusicAttributes? previousAttributes,
    double? fallbackTempo,
  }) {
    for (final barline in measure.barlines) {
      if (barline.location == 'left') builder.xml(barline.xml);
    }
    _writeAttributes(builder, measure.attributes, previous: previousAttributes);

    final directions = measure.events.whereType<MusicDirection>().toList();
    if (fallbackTempo != null &&
        !directions.any((direction) => direction.tempoBpm != null)) {
      directions.insert(
        0,
        MusicDirection(onset: 0, staff: 1, tempoBpm: fallbackTempo),
      );
    }
    for (final direction in directions) {
      _writeDirection(builder, direction);
    }
    for (final harmony in measure.events.whereType<MusicHarmony>()) {
      _writeHarmony(builder, harmony);
    }

    final notes = <({int eventIndex, MusicNote note})>[
      for (var eventIndex = 0; eventIndex < measure.events.length; eventIndex++)
        if (measure.events[eventIndex] case final MusicNote note)
          (eventIndex: eventIndex, note: note),
    ];
    final voices = <String>[];
    for (final entry in notes) {
      if (!voices.contains(entry.note.voice)) voices.add(entry.note.voice);
    }
    for (var voiceIndex = 0; voiceIndex < voices.length; voiceIndex++) {
      final voice = voices[voiceIndex];
      final voiceNotes =
          notes.where((entry) => entry.note.voice == voice).toList()
            ..sort((a, b) {
              final onsetOrder = a.note.onset.compareTo(b.note.onset);
              if (onsetOrder != 0) return onsetOrder;
              final staffOrder = a.note.staff.compareTo(b.note.staff);
              return staffOrder == 0
                  ? a.eventIndex.compareTo(b.eventIndex)
                  : staffOrder;
            });
      var cursor = 0;
      for (var index = 0; index < voiceNotes.length;) {
        final onset = voiceNotes[index].note.onset;
        if (onset > cursor) {
          _writeForward(
            builder,
            onset - cursor,
            voice,
            voiceNotes[index].note.staff,
          );
          cursor = onset;
        }
        final simultaneous = <({int eventIndex, MusicNote note})>[];
        while (index < voiceNotes.length &&
            voiceNotes[index].note.onset == onset) {
          simultaneous.add(voiceNotes[index]);
          index++;
        }
        for (
          var chordIndex = 0;
          chordIndex < simultaneous.length;
          chordIndex++
        ) {
          _writeNote(
            builder,
            simultaneous[chordIndex].note,
            id: _noteXmlId(
              partIndex: partIndex,
              measureIndex: measureIndex,
              eventIndex: simultaneous[chordIndex].eventIndex,
            ),
            chordContinuation: simultaneous[chordIndex].note.isChord,
          );
        }
        final end = simultaneous.fold<int>(
          cursor,
          (maximum, entry) =>
              entry.note.end > maximum ? entry.note.end : maximum,
        );
        cursor = end;
      }
      if (voiceIndex < voices.length - 1 && cursor > 0) {
        builder.element(
          'backup',
          nest: () => builder.element('duration', nest: cursor.toString()),
        );
      }
    }
    for (final barline in measure.barlines) {
      if (barline.location != 'left') builder.xml(barline.xml);
    }
  }

  MusicBarline _parseBarline(XmlElement element) {
    final repeat = _firstChild(element, 'repeat');
    final ending = _firstChild(element, 'ending');
    return MusicBarline(
      location: element.getAttribute('location') ?? 'right',
      xml: element.toXmlString(),
      repeat: repeat?.getAttribute('direction'),
      times: int.tryParse(repeat?.getAttribute('times') ?? ''),
      endingNumbers: [
        for (final part in (ending?.getAttribute('number') ?? '').split(
          RegExp(r'[,\s]+'),
        ))
          if (int.tryParse(part) case final number?) number,
      ],
      endingType: ending?.getAttribute('type'),
    );
  }

  void _writeAttributes(
    XmlBuilder builder,
    MusicAttributes attributes, {
    MusicAttributes? previous,
  }) {
    final writeDivisions =
        previous == null || previous.divisions != attributes.divisions;
    final writeKey =
        previous == null ||
        previous.keyFifths != attributes.keyFifths ||
        previous.keyMode != attributes.keyMode;
    final writeTime =
        previous == null || !_sameTime(previous.time, attributes.time);
    final writeStaves =
        previous == null || previous.staves != attributes.staves;
    final writeClefs =
        previous == null || !_sameClefs(previous.clefs, attributes.clefs);
    if (!writeDivisions &&
        !writeKey &&
        !writeTime &&
        !writeStaves &&
        !writeClefs) {
      return;
    }

    builder.element(
      'attributes',
      nest: () {
        if (writeDivisions) {
          builder.element('divisions', nest: attributes.divisions.toString());
        }
        if (writeKey) {
          builder.element(
            'key',
            nest: () {
              builder.element('fifths', nest: attributes.keyFifths.toString());
              if (_nonEmpty(attributes.keyMode) case final mode?) {
                builder.element('mode', nest: mode);
              }
            },
          );
        }
        if (writeTime) {
          if (attributes.time case final time?) {
            builder.element(
              'time',
              attributes: {
                if (time.symbol case final symbol?) 'symbol': symbol.name,
              },
              nest: () {
                builder.element('beats', nest: time.beats.toString());
                builder.element('beat-type', nest: time.beatType.toString());
              },
            );
          }
        }
        if (writeStaves && attributes.staves > 1) {
          builder.element('staves', nest: attributes.staves.toString());
        }
        if (writeClefs) {
          for (final entry in attributes.clefs.entries) {
            builder.element(
              'clef',
              attributes: {if (attributes.staves > 1) 'number': '${entry.key}'},
              nest: () {
                builder.element('sign', nest: entry.value.sign);
                builder.element('line', nest: entry.value.line.toString());
                if (entry.value.octaveChange != 0) {
                  builder.element(
                    'clef-octave-change',
                    nest: entry.value.octaveChange.toString(),
                  );
                }
              },
            );
          }
        }
      },
    );
  }

  bool _sameTime(MusicTimeSignature? a, MusicTimeSignature? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    return a.beats == b.beats &&
        a.beatType == b.beatType &&
        a.symbol == b.symbol;
  }

  bool _sameClefs(Map<int, MusicClef> a, Map<int, MusicClef> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null ||
          other.sign != entry.value.sign ||
          other.line != entry.value.line ||
          other.octaveChange != entry.value.octaveChange) {
        return false;
      }
    }
    return true;
  }

  void _writeDirection(XmlBuilder builder, MusicDirection direction) {
    builder.element(
      'direction',
      attributes: const {'placement': 'above'},
      nest: () {
        if (_nonEmpty(direction.rehearsal) case final rehearsal?) {
          builder.element(
            'direction-type',
            nest: () {
              builder.element(
                'rehearsal',
                attributes: const {'enclosure': 'square'},
                nest: rehearsal,
              );
            },
          );
        }
        final words =
            _nonEmpty(direction.words) ??
            switch (direction.navigation) {
              // A jump needs a printed label; a direction needs a type.
              MusicNavigation.dalSegno => 'D.S.',
              MusicNavigation.daCapo => 'D.C.',
              MusicNavigation.toCoda => 'To Coda',
              MusicNavigation.fine => 'Fine',
              _ => null,
            };
        if (words != null) {
          builder.element(
            'direction-type',
            nest: () {
              builder.element('words', nest: words);
            },
          );
        }
        if (direction.navigation
            case MusicNavigation.segno || MusicNavigation.coda) {
          builder.element(
            'direction-type',
            nest: () {
              builder.element(
                direction.navigation == MusicNavigation.segno
                    ? 'segno'
                    : 'coda',
              );
            },
          );
        }
        if (direction.tempoBpm case final tempo?) {
          builder.element(
            'direction-type',
            nest: () {
              builder.element(
                'metronome',
                nest: () {
                  builder.element('beat-unit', nest: 'quarter');
                  builder.element('per-minute', nest: _number(tempo));
                },
              );
            },
          );
        }
        if (direction.onset != 0) {
          builder.element('offset', nest: direction.onset.toString());
        }
        if (direction.staff != 1) {
          builder.element('staff', nest: direction.staff.toString());
        }
        final sound = <String, String>{
          if (direction.tempoBpm case final tempo?) 'tempo': _number(tempo),
          ...switch (direction.navigation) {
            MusicNavigation.segno => {'segno': 'segno'},
            MusicNavigation.coda => {'coda': 'coda'},
            MusicNavigation.dalSegno => {'dalsegno': 'segno'},
            MusicNavigation.daCapo => {'dacapo': 'yes'},
            MusicNavigation.toCoda => {'tocoda': 'coda'},
            MusicNavigation.fine => {'fine': 'yes'},
            null => const <String, String>{},
          },
        };
        if (sound.isNotEmpty) builder.element('sound', attributes: sound);
      },
    );
  }

  void _writeHarmony(XmlBuilder builder, MusicHarmony harmony) {
    builder.element(
      'harmony',
      nest: () {
        builder.element(
          'root',
          nest: () {
            builder.element('root-step', nest: harmony.rootStep.musicXmlName);
            if (harmony.rootAlter != 0) {
              builder.element('root-alter', nest: '${harmony.rootAlter}');
            }
          },
        );
        builder.element(
          'kind',
          attributes: {
            if (_nonEmpty(harmony.kindText) case final text?) 'text': text,
          },
          nest: harmony.kind,
        );
        if (harmony.bassStep case final bassStep?) {
          builder.element(
            'bass',
            nest: () {
              builder.element('bass-step', nest: bassStep.musicXmlName);
              if (harmony.bassAlter != 0) {
                builder.element('bass-alter', nest: '${harmony.bassAlter}');
              }
            },
          );
        }
        if (harmony.onset != 0) {
          builder.element('offset', nest: harmony.onset.toString());
        }
        if (harmony.staff != 1) {
          builder.element('staff', nest: harmony.staff.toString());
        }
      },
    );
  }

  void _writeForward(
    XmlBuilder builder,
    int duration,
    String voice,
    int staff,
  ) {
    builder.element(
      'forward',
      nest: () {
        builder.element('duration', nest: duration.toString());
        builder.element('voice', nest: voice);
        if (staff != 1) builder.element('staff', nest: staff.toString());
      },
    );
  }

  void _writeNote(
    XmlBuilder builder,
    MusicNote note, {
    required String id,
    required bool chordContinuation,
  }) {
    builder.element(
      'note',
      attributes: {'id': id},
      nest: () {
        if (note.isGrace) builder.element('grace');
        if (chordContinuation) builder.element('chord');
        if (note.pitch case final pitch?) {
          builder.element(
            'pitch',
            nest: () {
              builder.element('step', nest: pitch.step.musicXmlName);
              if (pitch.alter != 0) {
                builder.element('alter', nest: pitch.alter.toString());
              }
              builder.element('octave', nest: pitch.octave.toString());
            },
          );
        } else {
          builder.element('rest');
        }
        if (!note.isGrace) {
          builder.element('duration', nest: note.duration.toString());
        }
        if (note.tieStop) {
          builder.element('tie', attributes: {'type': 'stop'});
        }
        if (note.tieStart) {
          builder.element('tie', attributes: {'type': 'start'});
        }
        builder.element('voice', nest: note.voice);
        if (_nonEmpty(note.type) case final type?) {
          builder.element('type', nest: type);
        }
        for (var index = 0; index < note.dots; index++) {
          builder.element('dot');
        }
        builder.element('staff', nest: note.staff.toString());
        for (final beam in note.beams) {
          builder.element(
            'beam',
            attributes: {'number': '${beam.number}'},
            nest: beam.value,
          );
        }
        if (note.tieStart || note.tieStop || note.slurStart || note.slurStop) {
          builder.element(
            'notations',
            nest: () {
              if (note.tieStop) {
                builder.element('tied', attributes: {'type': 'stop'});
              }
              if (note.tieStart) {
                builder.element('tied', attributes: {'type': 'start'});
              }
              if (note.slurStop) {
                builder.element(
                  'slur',
                  attributes: {'type': 'stop', 'number': '1'},
                );
              }
              if (note.slurStart) {
                builder.element(
                  'slur',
                  attributes: {'type': 'start', 'number': '1'},
                );
              }
            },
          );
        }
        for (final lyric in note.lyrics) {
          builder.xml(lyric);
        }
      },
    );
  }

  String _noteXmlId({
    required int partIndex,
    required int measureIndex,
    required int eventIndex,
  }) => 'p$partIndex-m$measureIndex-e$eventIndex';

  Uint8List _readMxl(Uint8List bytes) {
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } on Object catch (error) {
      throw FormatException('Invalid MXL container: $error');
    }
    if (archive.length > maxArchiveEntries) {
      throw const FormatException('The MXL container has too many entries.');
    }
    var totalBytes = 0;
    final files = <String, ArchiveFile>{};
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final normalized = _safeArchivePath(entry.name);
      totalBytes += entry.size;
      if (entry.size > maxScoreBytes || totalBytes > maxArchiveBytes) {
        throw const FormatException('The MXL container is too large.');
      }
      files[normalized] = entry;
    }

    final container = files['META-INF/container.xml'];
    if (container == null) {
      throw const FormatException('MXL is missing META-INF/container.xml.');
    }
    final containerDocument = _parseXml(
      utf8.decode(container.content, allowMalformed: false),
      label: 'MXL container',
    );
    final rootFile = containerDocument.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'rootfile')
        .firstOrNull;
    final rootPath = rootFile?.getAttribute('full-path');
    if (rootPath == null || rootPath.trim().isEmpty) {
      throw const FormatException('MXL rootfile is missing.');
    }
    final scoreEntry = files[_safeArchivePath(rootPath)];
    if (scoreEntry == null) {
      throw FormatException('MXL rootfile was not found: $rootPath');
    }
    final scoreBytes = scoreEntry.content;
    if (scoreBytes.length > maxScoreBytes) {
      throw const FormatException('The MusicXML score is too large.');
    }
    return scoreBytes;
  }

  XmlElement? _scorePartwiseOf(XmlElement root) {
    if (root.name.local == 'score-partwise') {
      return root;
    }
    return root.descendantElements
        .where((element) => element.name.local == 'score-partwise')
        .firstOrNull;
  }

  String _unsupportedScoreMessage(XmlElement root) {
    if (root.name.local == 'score-timewise') {
      return '이 악보 형식은 열 수 없습니다';
    }
    final namespace = root.namespaceUri ?? '';
    final isOpenLyrics =
        namespace.contains('openlyrics') ||
        (root.name.local == 'song' && _firstChild(root, 'lyrics') != null);
    if (isOpenLyrics) {
      return '가사 파일입니다';
    }
    return '악보가 아닙니다';
  }

  XmlDocument _parseXml(String source, {required String label}) {
    try {
      return XmlDocument.parse(source);
    } on XmlParserException catch (error) {
      throw FormatException('Invalid $label: ${error.message}');
    }
  }

  bool _looksLikeZip(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4b &&
        (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07) &&
        (bytes[3] == 0x04 || bytes[3] == 0x06 || bytes[3] == 0x08);
  }

  String _safeArchivePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    final segments = normalized.split('/');
    if (normalized.startsWith('/') ||
        normalized.contains(':') ||
        segments.any((segment) => segment == '..' || segment.isEmpty)) {
      throw FormatException('Unsafe MXL path: $value');
    }
    return normalized;
  }

  XmlElement? _firstChild(XmlElement? parent, String name) {
    if (parent == null) return null;
    return parent.childElements
        .where((element) => element.name.local == name)
        .firstOrNull;
  }

  Iterable<XmlElement> _children(XmlElement parent, String name) {
    return parent.childElements.where((element) => element.name.local == name);
  }

  String? _childText(XmlElement? parent, String name) {
    return _firstChild(parent, name)?.innerText.trim();
  }

  String _requiredChildText(XmlElement parent, String name) {
    final value = _nonEmpty(_childText(parent, name));
    if (value == null) {
      throw FormatException('MusicXML $name is required.');
    }
    return value;
  }

  int _requiredPositiveInt(XmlElement parent, String name) {
    final value = _requiredInt(parent, name);
    if (value <= 0) {
      throw FormatException('MusicXML $name must be positive.');
    }
    return value;
  }

  int _requiredInt(XmlElement parent, String name) {
    final value = _intText(parent, name);
    if (value == null) {
      throw FormatException('MusicXML $name must be an integer.');
    }
    return value;
  }

  int? _intText(XmlElement parent, String name) {
    return int.tryParse(_childText(parent, name) ?? '');
  }

  double? _doubleAttribute(XmlElement element, String name) {
    return double.tryParse(element.getAttribute(name) ?? '');
  }

  String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String _number(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}

class _ParsedMeasure {
  const _ParsedMeasure({
    required this.measure,
    required this.attributes,
    required this.firstTempo,
  });

  final MusicMeasure measure;
  final MusicAttributes attributes;
  final double? firstTempo;
}
