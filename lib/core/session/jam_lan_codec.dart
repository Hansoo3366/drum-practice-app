import 'dart:convert';

import 'package:page_a_diddle/core/session/jam_session.dart';

class JamLanAnnounce {
  const JamLanAnnounce({
    required this.code,
    required this.port,
    this.title,
    this.participantCount,
  });

  factory JamLanAnnounce.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final port = json['port'];
    if (code is! String || port is! int) {
      throw const FormatException('알림');
    }
    final title = json['title'];
    final participantCount = json['participantCount'];
    return JamLanAnnounce(
      code: code,
      port: port,
      title: title is String && title.trim().isNotEmpty ? title.trim() : null,
      participantCount: participantCount is int && participantCount >= 0
          ? participantCount
          : null,
    );
  }

  final String code;
  final int port;
  final String? title;
  final int? participantCount;

  Map<String, Object?> toJson() {
    return {
      'type': 'announce',
      'code': code,
      'port': port,
      if (title != null) 'title': title,
      if (participantCount != null) 'participantCount': participantCount,
    };
  }
}

class JamLanQuery {
  const JamLanQuery({this.code});

  final String? code;

  Map<String, Object?> toJson() {
    return {'type': 'query', if (code != null) 'code': code};
  }
}

Map<String, dynamic>? decodeJamLanMessage(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(decoded);
  } on Object {
    return null;
  }
}

JamLanAnnounce? announceFromMessage(Map<String, dynamic> json) {
  if (json['type'] != 'announce') {
    return null;
  }
  try {
    return JamLanAnnounce.fromJson(json);
  } on Object {
    return null;
  }
}

String encodeJamLanLine(Map<String, Object?> message) {
  return '${jsonEncode(message)}\n';
}

JamSession? sessionFromMessage(Object? value) {
  if (value is! Map) {
    return null;
  }
  try {
    return JamSession.fromJson(Map<String, dynamic>.from(value));
  } on Object {
    return null;
  }
}
