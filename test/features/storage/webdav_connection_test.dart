import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/library/domain/score_file_filter.dart';
import 'package:page_a_diddle/features/storage/data/webdav_connection.dart';

void main() {
  const credentials = WebDavCredentials(
    url: 'https://example.com/webdav',
    username: 'drummer',
    password: 'secret',
  );

  test('WebDAV Multi-Status 응답을 연결 성공으로 처리한다', () async {
    final connection = WebDavConnection(
      request: (uri, username, password, depth) async {
        expect(uri, Uri.parse(credentials.url));
        expect(username, credentials.username);
        expect(password, credentials.password);
        expect(depth, 0);
        return const WebDavResponse(207);
      },
    );

    await connection.test(credentials);
  });

  test('인증 실패를 사용자 오류로 변환한다', () async {
    final connection = WebDavConnection(
      request: (_, _, _, _) async => const WebDavResponse(401),
    );

    expect(
      () => connection.test(credentials),
      throwsA(
        isA<WebDavConnectionException>().having(
          (error) => error.message,
          'message',
          '계정 정보를 확인하세요.',
        ),
      ),
    );
  });

  test('HTTPS 외의 서버 주소를 거부한다', () async {
    final connection = WebDavConnection(
      request: (_, _, _, _) async => const WebDavResponse(207),
    );

    expect(
      () => connection.test(
        const WebDavCredentials(
          url: 'http://example.com',
          username: '',
          password: '',
        ),
      ),
      throwsA(isA<WebDavConnectionException>()),
    );
  });

  test('폴더를 먼저 정렬하고 PDF만 반환한다', () async {
    final connection = WebDavConnection(
      request: (uri, username, password, depth) async {
        expect(depth, 1);
        return const WebDavResponse(207, '''
          <d:multistatus xmlns:d="DAV:">
            <d:response>
              <d:href>/webdav/</d:href>
              <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat>
            </d:response>
            <d:response>
              <d:href>/webdav/Zeta.pdf</d:href>
              <d:propstat><d:prop>
                <d:displayname>Zeta.pdf</d:displayname>
                <d:getcontentlength>2048</d:getcontentlength>
              </d:prop></d:propstat>
            </d:response>
            <d:response>
              <d:href>/webdav/Practice/</d:href>
              <d:propstat><d:prop>
                <d:displayname>Practice</d:displayname>
                <d:resourcetype><d:collection/></d:resourcetype>
              </d:prop></d:propstat>
            </d:response>
            <d:response>
              <d:href>/webdav/audio.mp3</d:href>
              <d:propstat><d:prop><d:displayname>audio.mp3</d:displayname></d:prop></d:propstat>
            </d:response>
          </d:multistatus>
        ''');
      },
    );

    final entries = await connection.list(
      credentials,
      Uri.parse(credentials.url),
    );

    expect(entries.map((entry) => entry.name), ['Practice', 'Zeta.pdf']);
    expect(entries.first.isDirectory, isTrue);
    expect(entries.last.size, 2048);
  });

  test('MusicXML 가져오기에서는 MXL만 반환한다', () async {
    final connection = WebDavConnection(
      request: (_, _, _, _) async => const WebDavResponse(207, '''
        <d:multistatus xmlns:d="DAV:">
          <d:response>
            <d:href>/webdav/song.mxl</d:href>
            <d:propstat><d:prop><d:displayname>song.mxl</d:displayname></d:prop></d:propstat>
          </d:response>
          <d:response>
            <d:href>/webdav/Zeta.pdf</d:href>
            <d:propstat><d:prop><d:displayname>Zeta.pdf</d:displayname></d:prop></d:propstat>
          </d:response>
        </d:multistatus>
      '''),
    );

    final entries = await connection.list(
      credentials,
      Uri.parse(credentials.url),
      filter: ScoreFileFilter.musicXml,
    );

    expect(entries.map((entry) => entry.name), ['song.mxl']);
  });

  test('다른 서버를 가리키는 응답 항목은 제외한다', () async {
    final connection = WebDavConnection(
      request: (_, _, _, _) async => const WebDavResponse(207, '''
        <multistatus xmlns="DAV:">
          <response>
            <href>https://other.example/score.pdf</href>
            <propstat><prop><displayname>score.pdf</displayname></prop></propstat>
          </response>
        </multistatus>
      '''),
    );

    final entries = await connection.list(
      credentials,
      Uri.parse(credentials.url),
    );

    expect(entries, isEmpty);
  });

  test('다른 서버의 PDF에는 인증 정보를 보내지 않는다', () async {
    var downloaded = false;
    final connection = WebDavConnection(
      download: (_, _, _) async {
        downloaded = true;
        return WebDavDownloadResult(bytes: Uint8List(0));
      },
    );

    expect(
      () => connection.downloadPdf(
        credentials,
        Uri.parse('https://other.example/score.pdf'),
      ),
      throwsA(isA<WebDavConnectionException>()),
    );
    expect(downloaded, isFalse);
  });
}
