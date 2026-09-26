class OmrConvertConfig {
  const OmrConvertConfig({
    this.baseUrl = OmrConvertConfig.defaultBaseUrl,
    this.token = OmrConvertConfig.defaultToken,
  });

  static const defaultBaseUrl = String.fromEnvironment(
    'OMR_BASE_URL',
    defaultValue: 'http://34.10.15.222:8080',
  );
  static const defaultToken = String.fromEnvironment(
    'OMR_TOKEN',
    defaultValue: 'piano-omr-dev',
  );

  final String baseUrl;
  final String token;
}
