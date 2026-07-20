import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AzureFoundryService {
  static String? _getValue(String key, {String? fallbackKey}) {
    final fromDotEnv = dotenv.env[key];
    if (fromDotEnv != null && fromDotEnv.trim().isNotEmpty) {
      return fromDotEnv.trim();
    }
    if (fallbackKey != null) {
      final fallback = dotenv.env[fallbackKey];
      if (fallback != null && fallback.trim().isNotEmpty) {
        return fallback.trim();
      }
    }
    return null;
  }

  static String? get endpoint => _getValue(
        'AZURE_AI_FOUNDRY_ENDPOINT',
        fallbackKey: 'AZURE_OPENAI_ENDPOINT',
      );

  static String? get apiKey => _getValue(
        'AZURE_AI_FOUNDRY_API_KEY',
        fallbackKey: 'AZURE_OPENAI_API_KEY',
      );

  static String? get deployment => _getValue(
        'AZURE_AI_FOUNDRY_DEPLOYMENT',
        fallbackKey: 'AZURE_OPENAI_DEPLOYMENT',
      );

  static String get apiVersion => _getValue(
        'AZURE_AI_FOUNDRY_API_VERSION',
        fallbackKey: 'AZURE_OPENAI_API_VERSION',
      ) ??
      '2024-02-01';

  static bool isConfigured([Map<String, String>? env]) {
    final values = env ?? dotenv.env;
    final endpointValue = values['AZURE_AI_FOUNDRY_ENDPOINT'] ?? values['AZURE_OPENAI_ENDPOINT'];
    final apiKeyValue = values['AZURE_AI_FOUNDRY_API_KEY'] ?? values['AZURE_OPENAI_API_KEY'];
    final deploymentValue = values['AZURE_AI_FOUNDRY_DEPLOYMENT'] ?? values['AZURE_OPENAI_DEPLOYMENT'];

    return (endpointValue?.isNotEmpty ?? false) &&
        (apiKeyValue?.isNotEmpty ?? false) &&
        (deploymentValue?.isNotEmpty ?? false);
  }

  static Future<String> getReply(String prompt) async {
    final currentEndpoint = endpoint;
    final currentApiKey = apiKey;
    final currentDeployment = deployment;

    if (currentEndpoint == null || currentApiKey == null || currentDeployment == null) {
      return 'No tengo configurado tu recurso de Azure Foundry. Añade las variables de entorno en .env y reinicia la app.';
    }

    final normalizedEndpoint = currentEndpoint.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse(
      '$normalizedEndpoint/openai/deployments/$currentDeployment/chat/completions?api-version=$apiVersion',
    );

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'api-key': currentApiKey,
          },
          body: jsonEncode({
            'messages': [
              {
                'role': 'system',
                'content':
                    'Eres un asistente útil para una app de movilidad urbana en La Paz. Responde breve, claro y práctico.',
              },
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.7,
            'max_tokens': 220,
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode >= 400) {
      throw Exception('Azure Foundry respondió ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Azure Foundry no devolvió mensajes válidos.');
    }

    final firstChoice = choices.first as Map<String, dynamic>?;
    final message = firstChoice?['message'] as Map<String, dynamic>?;
    final content = message?['content'];
    if (content is String && content.trim().isNotEmpty) {
      return content.trim();
    }

    throw Exception('Azure Foundry devolvió una respuesta vacía.');
  }
}
