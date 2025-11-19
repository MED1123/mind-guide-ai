// Plik: lib/Services/gpt_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GptService {
  static Future<String> analyzeMood(String userInput) async {
    final apiKey = dotenv.env['OPENROUTER_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("Brak klucza API w pliku .env");
    }

    final url = Uri.parse("https://openrouter.ai/api/v1/chat/completions");

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'HTTP-Referer': 'http://localhost',
      'X-Title': 'Mood Journal GPT',
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      "model": "meta-llama/llama-3.1-8b-instruct:free",
      "messages": [
        {
          "role": "system",
          "content":
          "Jesteś empatycznym doradcą nastroju. Na podstawie wpisu użytkownika analizujesz jego nastrój i dajesz krótką, wspierającą sugestię."
        },
        {
          "role": "user",
          "content": userInput
        }
      ]
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      return content.trim();
    } else {
      final error = jsonDecode(response.body);
      final message = error['error']?['message'] ?? 'Nieznany błąd';
      throw Exception("GPT error: $message");
    }
  }
}