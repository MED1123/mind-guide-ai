import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GptService {
  static Future<String> chatWithAI(
    String userInput,
    String history,
    bool isFemale,
  ) async {
    // 1. ZABEZPIECZENIE: Ładowanie .env jeśli brakuje
    if (!dotenv.isInitialized) {
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        return "BŁĄD: Nie znaleziono pliku .env. Upewnij się, że plik istnieje w głównym folderze.";
      }
    }

    final apiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return "BŁĄD: Klucz API jest pusty. Sprawdź plik .env.";
    }

    final url = Uri.parse("https://openrouter.ai/api/v1/chat/completions");

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'HTTP-Referer': 'http://localhost',
      'X-Title': 'Mood Journal',
    };

    // 2. PROMPT I PERSONA
    String systemPrompt = isFemale
        ? "Jesteś empatyczną asystentką psychologiczną. Twoje odpowiedzi są ciepłe, zrozumiałe i wspierające."
        : "Jesteś konkretnym, ale empatycznym asystentem psychologicznym. Twoje odpowiedzi są rzeczowe i wspierające.";

    // Utwórz listę wiadomości, włączając prompt systemowy
    List<Map<String, String>> messages = [
      {"role": "system", "content": systemPrompt},
    ];

    // Dodaj historię rozmowy
    final historyParts = history.split('|');
    for (var part in historyParts) {
      if (part.startsWith("User: ")) {
        messages.add({"role": "user", "content": part.substring(6)});
      } else if (part.startsWith("AI: ")) {
        messages.add({"role": "assistant", "content": part.substring(4)});
      }
    }

    // Dodaj najnowszą wiadomość użytkownika (userInput) jako ostatnią wiadomość
    messages.add({"role": "user", "content": userInput});

    // ZAPOBIEGANIE BŁĘDOWI - jeśli to pierwsza wiadomość, usuwamy duplikat.
    // Zdarza się to, gdy history ma postać "User: ..." i to jest ten sam tekst co userInput
    if (messages.length >= 3 &&
        messages[messages.length - 1]['content'] ==
            messages[messages.length - 2]['content']) {
      messages.removeAt(messages.length - 1);
    }

    final body = jsonEncode({
      "model": "x-ai/grok-4.1-fast", // Wybrany model
      "messages": messages,
      // Dodajemy parametr reasoning, którego wymaga ten model (zgodnie z Twoim przykładem)
      "reasoning": {"enabled": true},
    });

    // 4. WYSŁANIE
    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Próbujemy wyciągnąć treść odpowiedzi
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          // Opcjonalnie: Możesz tu też sprawdzić data['choices'][0]['message']['reasoning_details'] jeśli chcesz widzieć proces myślenia
          return data['choices'][0]['message']['content'].trim();
        } else {
          return "AI nie zwróciło odpowiedzi (pusta treść).";
        }
      } else {
        // Obsługa błędu 402 (Brak płatności) lub 404 (Model niedostępny)
        if (response.statusCode == 402) {
          return "BŁĄD 402: Wygląda na to, że ten model jednak wymaga płatnych kredytów na OpenRouter.";
        }
        return "Błąd serwera (Kod: ${response.statusCode}). Treść: ${response.body}";
      }
    } catch (e) {
      return "Błąd połączenia z internetem: $e";
    }
  }
}
