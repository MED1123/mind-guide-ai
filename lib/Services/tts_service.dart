import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _flutterTts
          .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions
                .interruptSpokenAudioAndMixWithOthers,
          ]);

      await _flutterTts.setLanguage("pl-PL");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      _isInitialized = true;
    } catch (e) {
      print("Błąd inicjalizacji TTS: $e");
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }
}
