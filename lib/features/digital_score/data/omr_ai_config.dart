class OmrAiConfig {
  const OmrAiConfig({
    this.apiKey = OmrAiConfig.defaultApiKey,
    this.baseUrl = 'https://api.x.ai/v1',
    this.model = 'grok-4.7',
  });

  static const defaultApiKey = String.fromEnvironment('XAI_API_KEY');

  final String apiKey;
  final String baseUrl;
  final String model;

  bool get isConfigured => apiKey.trim().isNotEmpty;
}
