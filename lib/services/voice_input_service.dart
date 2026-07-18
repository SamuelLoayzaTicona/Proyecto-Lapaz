import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Envuelve speech_to_text para que la pantalla solo tenga que llamar
/// start/stop y recibir el texto final, sin manejar el ciclo de vida del
/// plugin directamente.
class VoiceInputService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    return _isInitialized;
  }

  bool get isListening => _speech.isListening;

  Future<void> startListening({
    required void Function(String text) onResult,
    String localeId = 'es_BO',
  }) async {
    final available = await initialize();
    if (!available) return;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
      localeId: localeId,
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }
}
