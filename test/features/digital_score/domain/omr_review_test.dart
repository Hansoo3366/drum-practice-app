import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_quality.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_review.dart';

final _validation = jsonEncode({
  'issues': [
    {
      'rule': 'V006',
      'severity': 'low',
      'part': 0,
      'measureIndex': 7,
      'measure': '8',
      'detail': 'pitch 84 is 14 semitones from its neighbours',
      'image': 'p1-s2-m4.png',
    },
    {
      'rule': 'V001',
      'severity': 'high',
      'part': 0,
      'measureIndex': 3,
      'measure': '4',
      'detail': 'measure lasts 3.5 quarters, time signature wants 4',
      'image': 'p1-s1-m4.png',
      'focus': [0.25, 0.5],
    },
    {
      'rule': 'A001',
      'severity': 'medium',
      'part': 0,
      'measureIndex': 7,
      'measure': '8',
      'detail': 'a colour annotation lay over the measure',
      'image': 'p1-s2-m4.png',
    },
    {
      'rule': 'L001',
      'severity': 'low',
      'part': 0,
      'measureIndex': 3,
      'measure': '4',
      'detail': "leftover text 'x2'",
    },
    // Not tied to a measure: nothing to show.
    {'rule': 'S001', 'severity': 'high', 'detail': 'whole page'},
  ],
});

final _ai = jsonEncode({
  'applied': [
    {
      'measureIndex': 3,
      'measure': '4',
      'field': 'chords',
      'before': 'G',
      'after': 'G/B',
    },
  ],
  'suggestions': [
    {
      'measureIndex': 3,
      'measure': '4',
      'corrections': [
        {
          'measure': '4',
          'field': 'chords',
          'verse': null,
          'note': null,
          'current': "['G']",
          'suggested': '["G/B", "D7"]',
          'confidence': 0.92,
        },
        {
          'measure': '4',
          'field': 'pitch',
          'verse': null,
          'note': 2,
          'current': 'A4',
          'suggested': 'B4',
          'confidence': 0.6,
          'status': 'notes',
        },
        {
          'measure': '4',
          'field': 'lyrics',
          'verse': '1',
          'note': null,
          'current': '예 수',
          'suggested': '예수님',
          'confidence': 0.7,
          'status': 'low_confidence',
        },
      ],
      'uncertain': <Object?>[],
    },
    {
      'measureIndex': 11,
      'measure': '12',
      'corrections': <Object?>[],
      'uncertain': [
        {'measure': '12', 'reason': '필기에 가려 가사가 보이지 않습니다'},
      ],
    },
  ],
});

void main() {
  test('lists the doubted measures in score order with their reasons', () {
    final bars = omrReviewBars(validationJson: _validation);

    expect(bars.map((bar) => bar.measure), ['4', '8']);
    expect(bars[0].key, '0:3');
    expect(bars[0].severity, OmrIssueSeverity.high);
    expect(bars[0].image, 'p1-s1-m4.png');
    expect(bars[0].focus, (0.25, 0.5));
    // An older report has no focus.
    expect(bars[1].focus, isNull);
    expect(bars[0].issues.map((issue) => issue.text), [
      '마디 길이가 4분음표 3.5개인데 박자표는 4개입니다.',
      '읽다 남은 글자가 있습니다: x2',
    ]);
    expect(bars[1].severity, OmrIssueSeverity.medium);
    expect(bars[1].issues.map((issue) => issue.rule), ['V006', 'A001']);
    expect(bars[1].issues.first.text, '주변 음에서 14반음 떨어진 음이 있습니다.');
  });

  test('says in words what two readers did not agree on', () {
    String text(String rule, String detail) => OmrReviewIssue(
      rule: rule,
      severity: OmrIssueSeverity.medium,
      detail: detail,
    ).text;

    expect(
      text('N001', 'the two readers differ; the other read C4 D4+F4 G6'),
      '두 판독기가 이 마디의 음을 다르게 읽었습니다. 다른 쪽이 읽은 음: C4 D4+F4 G6',
    );
    expect(
      text('N002', 'only one reader read these notes (the other read 3)'),
      '이 마디의 음은 한 판독기만 읽어 견줄 것이 없습니다. 음을 확인하세요.',
    );
    expect(
      text(
        'K001',
        'key signature read as -6 here, as -2 by the other reader, in 28 lines',
      ),
      '두 판독기가 조표를 다르게 읽었습니다(여기는 플랫 6개, 다른 쪽은 플랫 2개).',
    );
    expect(
      text(
        'K002',
        'key 0 fits 62% of 13 chord roots; key 3 fits 100%',
      ),
      '조표(조표 없음)가 코드와 맞지 않습니다. 코드는 샤프 3개에 맞습니다.',
    );
    // A report worded otherwise still says what is the matter.
    expect(text('K001', ''), '두 판독기가 조표를 다르게 읽었습니다.');
  });

  test('adds what the AI review says, applied or advice only', () {
    final bars = omrReviewBars(validationJson: _validation, aiReviewJson: _ai);

    expect(bars.map((bar) => bar.measure), ['4', '8', '12']);
    final [chords, pitch, lyrics] = bars[0].suggestions;
    expect(chords.label, '코드');
    // Chord lists read as chords, not as the model's JSON.
    expect((chords.current, chords.suggested), ('G', 'G/B D7'));
    expect(chords.confidence, 0.92);
    expect(chords.applied, isTrue);
    // An older report without statuses: applied when the applied list says so.
    expect(chords.advice, '악보에 반영됨');
    expect(pitch.label, '2번째 음 높이');
    expect(pitch.applied, isFalse);
    expect(pitch.advice, '음표는 자동으로 넣지 않음 · 확인 후 넣기');
    expect(lyrics.applied, isFalse);
    expect(lyrics.advice, '확신이 낮아 반영하지 않음 · 검토 권장');
    // A bar only the AI doubts is listed too.
    expect(bars[2].issues, isEmpty);
    expect(bars[2].uncertain, ['필기에 가려 가사가 보이지 않습니다']);
  });

  test('has nothing to review without reports, or with unreadable ones', () {
    expect(omrReviewBars(), isEmpty);
    expect(
      omrReviewBars(validationJson: 'not json', aiReviewJson: '[]'),
      isEmpty,
    );
    expect(omrSuspectImageNames('not json'), isEmpty);
  });

  test('names each crop once', () {
    expect(omrSuspectImageNames(_validation), {'p1-s2-m4.png', 'p1-s1-m4.png'});
  });

  test('reads the separated annotations', () {
    final items = omrAnnotations(
      jsonEncode({
        'items': [
          {'page': 1, 'type': 'ink', 'color': 'red', 'text': '도돌이 무시'},
          {'page': 2, 'type': 'highlight', 'color': 'yellow', 'text': null},
        ],
      }),
    );

    expect(items.map((item) => item.label), ['빨간 펜', '노란 형광펜']);
    expect(items.map((item) => item.text), ['도돌이 무시', null]);
    expect(items[1].page, 2);
    expect(omrAnnotations(null), isEmpty);
  });

  test('reads where each measure is on the original', () {
    final layout = jsonEncode({
      'parts': [
        [
          {
            'image': 'p1-s1.jpg',
            'focus': [0.01, 0.34],
          },
          {
            'image': 'p1-s1.jpg',
            'focus': [0.34, 0.99],
          },
          null,
          {
            'image': 'p1-s2.jpg',
            'focus': [0.5, 0.2],
          },
          {
            'image': '',
            'focus': [0, 1],
          },
        ],
        [
          {
            'image': 'p1-s1-part2.jpg',
            'focus': [0, 1],
          },
        ],
      ],
    });

    final places = omrLayout(layout);

    expect(places, hasLength(2));
    expect(places[0][0], (image: 'p1-s1.jpg', focus: (0.01, 0.34)));
    expect(places[0][1]!.focus, (0.34, 0.99));
    // Not placed, or a place that makes no sense.
    expect(places[0].skip(2), [null, null, null]);
    expect(places[1].single, (image: 'p1-s1-part2.jpg', focus: (0.0, 1.0)));
    expect(omrSystemImageNames(layout), {'p1-s1.jpg', 'p1-s1-part2.jpg'});
    expect(omrLayout(null), isEmpty);
    expect(omrLayout('{"parts": 3}'), isEmpty);
  });

  test('keeps which measures were accepted', () {
    final json = omrReviewStateJson({'0:7', '0:3'});

    expect(omrReviewChecked(json), {'0:3', '0:7'});
    expect(omrReviewChecked(null), isEmpty);
    expect(omrReviewChecked('{"checked": 3}'), isEmpty);
  });
}
