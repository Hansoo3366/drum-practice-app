/// Where the conversion server is and the app key it expects.
///
/// The key only says "this is the app": each install registers with it once
/// and then uses a secret of its own. Release builds get it from
/// `dart_defines.local.json` (not in the repository); the default here is a
/// placeholder the server does not accept.
class OmrConvertConfig {
  const OmrConvertConfig({
    this.baseUrl = OmrConvertConfig.defaultBaseUrl,
    this.token = OmrConvertConfig.defaultToken,
  });

  static const defaultBaseUrl = String.fromEnvironment(
    'OMR_BASE_URL',
    defaultValue: 'https://34-10-15-222.sslip.io',
  );
  static const defaultToken = String.fromEnvironment(
    'OMR_TOKEN',
    defaultValue: 'set-OMR_TOKEN-in-dart_defines.local.json',
  );

  final String baseUrl;
  final String token;
}
