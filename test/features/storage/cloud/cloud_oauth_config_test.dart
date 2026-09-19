import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/storage/cloud/data/cloud_oauth_config.dart';
import 'package:page_a_diddle/features/storage/cloud/domain/cloud_models.dart';

void main() {
  test('Android product defaults enable configured cloud providers', () {
    expect(
      CloudOAuthConfig.googleServerClientId,
      CloudOAuthConfig.googleDefaultServerClientId,
    );
    expect(
      CloudOAuthConfig.dropboxClientId,
      CloudOAuthConfig.dropboxDefaultClientId,
    );
    expect(CloudOAuthConfig.canAttempt(CloudKind.googleDrive), isTrue);
    expect(CloudOAuthConfig.canAttempt(CloudKind.dropbox), isTrue);
  });

  test('dart_defines.json matches the same product cloud OAuth defaults', () {
    final json =
        jsonDecode(File('dart_defines.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(
      json['GOOGLE_SERVER_CLIENT_ID'],
      CloudOAuthConfig.googleDefaultServerClientId,
    );
    expect(json['DROPBOX_CLIENT_ID'], CloudOAuthConfig.dropboxDefaultClientId);
  });
}
