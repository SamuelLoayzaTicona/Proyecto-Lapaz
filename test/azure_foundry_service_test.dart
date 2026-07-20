import 'package:flutter_test/flutter_test.dart';
import 'package:ruta_segura_app/services/azure_foundry_service.dart';

void main() {
  group('AzureFoundryService', () {
    test('isConfigured returns false when required vars are missing', () {
      final env = <String, String>{};
      expect(AzureFoundryService.isConfigured(env), isFalse);
    });

    test('isConfigured returns true when required vars are present', () {
      final env = <String, String>{
        'AZURE_OPENAI_ENDPOINT': 'https://example.openai.azure.com',
        'AZURE_OPENAI_API_KEY': 'test-key',
        'AZURE_OPENAI_DEPLOYMENT': 'gpt-4o',
        'AZURE_OPENAI_API_VERSION': '2024-02-01',
      };

      expect(AzureFoundryService.isConfigured(env), isTrue);
    });
  });
}
