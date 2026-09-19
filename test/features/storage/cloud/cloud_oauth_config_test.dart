import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/storage/cloud/data/cloud_oauth_config.dart';
import 'package:page_a_diddle/features/storage/cloud/domain/cloud_models.dart';

void main() {
  test('Android release defaults enable configured cloud providers', () {
    expect(
      CloudOAuthConfig.googleServerClientId,
      contains('.apps.googleusercontent.com'),
    );
    expect(CloudOAuthConfig.dropboxClientId, 'usuggo1fabglt8p');
    expect(CloudOAuthConfig.canAttempt(CloudKind.googleDrive), isTrue);
    expect(CloudOAuthConfig.canAttempt(CloudKind.dropbox), isTrue);
  });
}
