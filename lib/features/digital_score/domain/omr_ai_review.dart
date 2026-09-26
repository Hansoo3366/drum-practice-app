import 'dart:convert';

class OmrAiCorrection {
  const OmrAiCorrection({
    required this.property,
    required this.currentValue,
    required this.suggestedValue,
    required this.confidence,
    this.elementId,
  });

  factory OmrAiCorrection.fromJson(Map<String, Object?> json) {
    return OmrAiCorrection(
      elementId: json['elementId']?.toString(),
      property: json['property']?.toString() ?? 'unknown',
      currentValue: json['currentValue']?.toString() ?? '',
      suggestedValue: json['suggestedValue']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  final String? elementId;
  final String property;
  final String currentValue;
  final String suggestedValue;
  final double confidence;

  Map<String, Object?> toJson() => {
    if (elementId != null) 'elementId': elementId,
    'property': property,
    'currentValue': currentValue,
    'suggestedValue': suggestedValue,
    'confidence': confidence,
  };
}

class OmrAiReview {
  const OmrAiReview({
    required this.hasError,
    required this.corrections,
    required this.overallConfidence,
  });

  factory OmrAiReview.fromJson(Map<String, Object?> json) {
    final raw = json['corrections'];
    return OmrAiReview(
      hasError: json['hasError'] == true,
      overallConfidence: (json['overallConfidence'] as num?)?.toDouble() ?? 0,
      corrections: [
        if (raw is List)
          for (final item in raw)
            if (item is Map)
              OmrAiCorrection.fromJson(Map<String, Object?>.from(item)),
      ],
    );
  }

  factory OmrAiReview.parseModelText(String raw) {
    final trimmed = raw.trim();
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return const OmrAiReview(
        hasError: false,
        corrections: [],
        overallConfidence: 0,
      );
    }
    try {
      final decoded = jsonDecode(trimmed.substring(start, end + 1));
      if (decoded is! Map) {
        return const OmrAiReview(
          hasError: false,
          corrections: [],
          overallConfidence: 0,
        );
      }
      return OmrAiReview.fromJson(Map<String, Object?>.from(decoded));
    } on Object {
      return const OmrAiReview(
        hasError: false,
        corrections: [],
        overallConfidence: 0,
      );
    }
  }

  final bool hasError;
  final List<OmrAiCorrection> corrections;
  final double overallConfidence;

  Map<String, Object?> toJson() => {
    'hasError': hasError,
    'overallConfidence': overallConfidence,
    'corrections': [for (final item in corrections) item.toJson()],
  };
}
