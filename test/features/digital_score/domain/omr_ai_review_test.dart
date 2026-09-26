import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_ai_review.dart';

void main() {
  test('parses spec-shaped correction JSON from model text', () {
    const raw = '''
Here is the result
{
  "hasError": true,
  "corrections": [
    {
      "elementId": "note_4",
      "property": "duration",
      "currentValue": "eighth",
      "suggestedValue": "quarter",
      "confidence": 0.97
    }
  ],
  "overallConfidence": 0.95
}
''';
    final review = OmrAiReview.parseModelText(raw);
    expect(review.hasError, isTrue);
    expect(review.corrections, hasLength(1));
    expect(review.corrections.single.property, 'duration');
    expect(review.corrections.single.suggestedValue, 'quarter');
    expect(review.overallConfidence, 0.95);
  });
}
