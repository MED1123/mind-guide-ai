import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GptService {
  static Future<String> chatWithAI(
    String userInput,
    String history,
    bool isFemale,
    String languageCode, {
    List<String>? imagePaths,
    String? assistantName, // Nowy parametr
  }) async {
    // ... (env init) ...
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

    String systemPrompt;
    String nameIntro = assistantName != null ? "Your name is $assistantName. " : "";
    String nameIntroPL = assistantName != null ? "Masz na imię $assistantName. " : "";

    if (languageCode == 'en') {
       systemPrompt = isFemale
        ? "You are a warm, empathetic, and caring psychological assistant. ${nameIntro}Your responses are feminine, full of understanding and emotional support. Use female forms. If this is the start of a conversation, introduce yourself briefly and warmly. If the user sends a photo, interpret it emotionally."
        : "You are a concrete, factual, and professional psychological assistant. ${nameIntro}Your responses are logical, supportive, and solution-oriented. Use male forms. If the user sends a photo, interpret it in an emotional context.";
    } else {
       systemPrompt = isFemale
        ? "Jesteś ciepłą, empatyczną i troskliwą asystentką psychologiczną. ${nameIntroPL}Twoje odpowiedzi są bardzo kobiece, pełne zrozumienia i wsparcia emocjonalnego. Używaj form żeńskich (np. 'zrozumiałam', 'chciałabym'). Jeśli to początek rozmowy, przedstaw się krótko i ciepło. Jeśli użytkownik prześle zdjęcie, zinterpretuj je emocjonalnie."
        : "Jesteś konkretnym, rzeczowym i profesjonalnym asystentem psychologicznym. ${nameIntroPL}Twoje odpowiedzi są logiczne, wspierające i skupione na rozwiązaniach. Używaj form męskich. Jeśli użytkownik prześle zdjęcie, zinterpretuj je w kontekście emocjonalnym.";
    }

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

    // Modulo Qwen obsługuje zdjęcia, więc nie blokujemy ich.


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

      for (String path in imagePaths!) {
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

    // Modele do wyboru
    final List<String> visionModels = [
      "google/gemini-2.0-flash-exp:free",
      "qwen/qwen-2-vl-72b-instruct:free", // Qwen VL is very good
      "qwen/qwen-2-vl-7b-instruct:free",
      "meta-llama/llama-3.2-90b-vision-instruct:free", // Alternatywa dla 11b
      "meta-llama/llama-3.2-11b-vision-instruct:free",
    ];

    final List<String> textModels = [
      "google/gemini-2.0-flash-exp:free",
      "meta-llama/llama-3.3-70b-instruct:free",
      "mistralai/mistral-small-3.1-24b-instruct:free",
      "microsoft/phi-3-mini-128k-instruct:free",
      "qwen/qwen-2.5-72b-instruct:free", 
    ];

    // Wybór listy modeli w zależności od zawartości (zdjęcia)
    List<String> modelsToTry = (imagePaths != null && imagePaths.isNotEmpty)
        ? visionModels
        : textModels;

    for (String model in modelsToTry) {
      print("Próba modelu: $model");
      final body = jsonEncode({
        "model": model,
        "messages": messages,
        "temperature": 0.7,
        "max_tokens": 1000,
      });

      try {
        final response = await http
            .post(url, headers: headers, body: body)
            .timeout(const Duration(seconds: 45)); // Krótszy timeout na model

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['choices'] != null && data['choices'].isNotEmpty) {
            return data['choices'][0]['message']['content'].trim();
          }
        } else {
          print("Model $model błąd: ${response.statusCode} - ${response.body}");
          // 404 lub 429 - próbujemy następny
        }
      } catch (e) {
        print("Wyjątek dla modelu $model: $e");
      }
    }

    // Jeśli przeszliśmy przez wszystkie Vision i nic, a mamy zdjęcia
    // Możemy spróbować wysłać zapytanie do Tekstowego modelu (bez zdjęć), 
    // informując, że zdjęcie się nie załadowało? 
    // Decyzja: lepiej zwrócić błąd niż kłamać analizując sam tekst.

    return "Przepraszam, wszystkie serwery AI są obecnie zajęte lub niedostępne. Spróbuj ponownie za chwilę.";
  }
}
