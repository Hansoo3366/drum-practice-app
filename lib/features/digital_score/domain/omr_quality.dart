import 'package:page_a_diddle/features/digital_score/domain/omr_ai_review.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_source_match.dart';

enum OmrIssueSeverity { high, medium, low }

class OmrQualityIssue {
  const OmrQualityIssue({
    required this.rule,
    required this.severity,
    required this.message,
    this.measureNumber,
    this.ai,
  });

  factory OmrQualityIssue.fromJson(Map<String, Object?> json) {
    return OmrQualityIssue(
      rule: json['rule']?.toString() ?? '',
      severity:
          OmrIssueSeverity.values.asNameMap()[json['severity']] ??
          OmrIssueSeverity.medium,
      message: json['message']?.toString() ?? '',
      measureNumber: json['measure']?.toString(),
      ai: json['ai'] is Map
          ? OmrAiReview.fromJson(Map<String, Object?>.from(json['ai'] as Map))
          : null,
    );
  }

  final String rule;
  final OmrIssueSeverity severity;
  final String message;
  final String? measureNumber;
  final OmrAiReview? ai;

  Map<String, Object?> toJson() => {
    'rule': rule,
    'severity': severity.name,
    'message': message,
    if (measureNumber != null) 'measure': measureNumber,
    if (ai != null) 'ai': ai!.toJson(),
  };

  OmrQualityIssue copyWith({OmrAiReview? ai}) {
    return OmrQualityIssue(
      rule: rule,
      severity: severity,
      message: message,
      measureNumber: measureNumber,
      ai: ai ?? this.ai,
    );
  }
}

class OmrQualityReport {
  const OmrQualityReport({
    required this.issues,
    required this.score,
    required this.analyzedAt,
    this.version = currentVersion,
    this.sourceMatch,
  });

  factory OmrQualityReport.fromJson(Map<String, Object?> json) {
    final raw = json['issues'];
    return OmrQualityReport(
      issues: [
        if (raw is List)
          for (final item in raw)
            if (item is Map)
              OmrQualityIssue.fromJson(Map<String, Object?>.from(item)),
      ],
      score: (json['score'] as num?)?.round() ?? 0,
      analyzedAt:
          DateTime.tryParse(json['analyzedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      version: (json['version'] as num?)?.round() ?? 1,
      sourceMatch: json['sourceMatch'] is Map
          ? OmrSourceMatch.fromJson(
              Map<String, Object?>.from(json['sourceMatch'] as Map),
            )
          : null,
    );
  }
  static const currentVersion = 3;

  final List<OmrQualityIssue> issues;
  final int score;
  final DateTime analyzedAt;
  final int version;
  final OmrSourceMatch? sourceMatch;

  OmrQualityReport copyWith({
    OmrSourceMatch? sourceMatch,
    List<OmrQualityIssue>? issues,
  }) {
    return OmrQualityReport(
      issues: issues ?? this.issues,
      score: score,
      analyzedAt: analyzedAt,
      version: version,
      sourceMatch: sourceMatch ?? this.sourceMatch,
    );
  }

  int get highCount =>
      issues.where((issue) => issue.severity == OmrIssueSeverity.high).length;

  Map<String, Object?> toJson() => {
    'version': version,
    'score': score,
    'analyzedAt': analyzedAt.toIso8601String(),
    'issues': [for (final issue in issues) issue.toJson()],
    if (sourceMatch != null) 'sourceMatch': sourceMatch!.toJson(),
  };

  Map<String, List<OmrQualityIssue>> get groupedByRule {
    final groups = <String, List<OmrQualityIssue>>{};
    for (final issue in issues) {
      groups.putIfAbsent(issue.rule, () => []).add(issue);
    }
    return groups;
  }
}

String omrRuleHeadline(String rule) {
  return switch (rule) {
    'V001' => '마디 길이가 박자와 다릅니다',
    'V003' => '붙임줄이 닫히지 않았습니다',
    'V005' => '빔이 닫히지 않았습니다',
    'V006' => '음높이가 갑자기 뜁니다',
    'V007' => '음표가 없는 마디입니다',
    'V008' => '조표가 없습니다',
    'V009' => '코드 심벌이 없습니다',
    'V010' => '가사가 없습니다',
    'V011' => '박자표가 없습니다',
    'A001' => '색 필기가 겹친 마디입니다',
    _ => rule,
  };
}
