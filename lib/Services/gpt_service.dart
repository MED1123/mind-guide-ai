import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GptService {
  static Future<String> chatWithAI(
    String userInput,
    String history,
    bool isFemale, {
    List<String>? imagePaths,
  }) async {
    // 1. Inicjalizacja zmiennych środowiskowych
    if (!dotenv.isInitialized) {
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        return "BŁĄD: Nie znaleziono pliku .env.";
      }
    }

    final apiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return "BŁĄD: Brak klucza API w pliku .env.";
    }

    final url = Uri.parse("https://openrouter.ai/api/v1/chat/completions");

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://github.com/twoje-repo/mood-journal',
      'X-Title': 'Mood Journal App',
    };

    String systemPrompt = isFemale
        ? "Jesteś ciepłą, empatyczną i troskliwą asystentką psychologiczną. Twoje odpowiedzi są bardzo kobiece, pełne zrozumienia i wsparcia emocjonalnego. Używaj form żeńskich (np. 'zrozumiałam', 'chciałabym'). Jeśli to początek rozmowy, przedstaw się krótko i ciepło. Jeśli użytkownik prześle zdjęcie, zinterpretuj je emocjonalnie."
        : "Jesteś konkretnym, rzeczowym i profesjonalnym asystentem psychologicznym. Twoje odpowiedzi są logiczne, wspierające i skupione na rozwiązaniach. Używaj form męskich. Jeśli użytkownik prześle zdjęcie, zinterpretuj je w kontekście emocjonalnym.";

    List<Map<String, dynamic>> messages = [
      {"role": "system", "content": systemPrompt},
    ];

    if (history.isNotEmpty) {
      final historyParts = history.split('|');
      for (var part in historyParts) {
        if (part.startsWith("User: ")) {
          String content = part.substring(6);
          if (!content.startsWith("[IMG:")) {
            messages.add({"role": "user", "content": content});
          }
        } else if (part.startsWith("AI: ")) {
          messages.add({"role": "assistant", "content": part.substring(4)});
        }
      }
    }

    if (imagePaths != null && imagePaths.isNotEmpty) {
      List<Map<String, dynamic>> contentList = [];

      if (userInput.isNotEmpty) {
        contentList.add({"type": "text", "text": userInput});
      } else {
        contentList.add({
          "type": "text",
          "text": "Przesyłam zdjęcie do analizy.",
        });
      }

      for (String path in imagePaths) {
        try {
          final bytes = await File(path).readAsBytes();
          final base64Image = base64Encode(bytes);
          contentList.add({
            "type": "image_url",
            "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
          });
        } catch (e) {
          print("Błąd ładowania zdjęcia: $e");
        }
      }
      messages.add({"role": "user", "content": contentList});
    } else {
      messages.add({"role": "user", "content": userInput});
    }

    if (messages.length >= 3 &&
        messages.last['content'].toString() ==
            messages[messages.length - 2]['content'].toString()) {
      messages.removeAt(messages.length - 1);
    }

    final body = jsonEncode({
      "model": "x-ai/grok-4.1-fast:free",
      "messages": messages,
      "temperature": 0.7,
      "max_tokens": 1000,
    });

    try {
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'].trim();
        } else {
          return "AI nie zwróciło odpowiedzi (pusta treść). Może to oznaczać przeciążenie modelu darmowego.";
        }
      } else {
        String errorMsg = "Błąd serwera (Kod: ${response.statusCode})";
        try {
          final errBody = jsonDecode(response.body);
          if (errBody['error'] != null && errBody['error']['message'] != null) {
            errorMsg += ": ${errBody['error']['message']}";
          }
        } catch (_) {}

        return errorMsg;
      }
    } catch (e) {
      return "Błąd połączenia lub limit czasu: $e";
    }
  }
}
