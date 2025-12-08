import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/mood_entry.dart';
import '../models/mood_analysis.dart'; // Import nowego modelu analizy

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  int? currentUserId;

  String get _baseUrl {
    final url = dotenv.env['API_URL'];
    if (url == null) {
      if (Platform.isAndroid) return "http://10.0.2.2:8000";
      return "http://127.0.0.1:8000";
    }
    return url;
  }

  // --- AUTH ---

  Future<bool> registerUser(String email, String password) async {
    final url = Uri.parse('$_baseUrl/auth/register');
    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print("Błąd rejestracji: $e");
      return false;
    }
  }

  Future<bool> loginUser(String email, String password) async {
    final url = Uri.parse('$_baseUrl/auth/login');
    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentUserId = data['user_id'];
        print("Zalogowano ID: $currentUserId");
        return true;
      }
      return false;
    } catch (e) {
      print("Błąd logowania: $e");
      return false;
    }
  }

  // --- WPISY (ENTRIES) ---

  // 1. Wysyłanie wpisu na serwer
  Future<bool> createEntry(MoodEntry entry) async {
    if (currentUserId == null) {
      print("Błąd: Nie zalogowano użytkownika!");
      return false;
    }

    final url = Uri.parse('$_baseUrl/entries/$currentUserId');
    print("Wysyłanie wpisu na: $url");

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "text": entry.text,
              "mood_rating": entry.moodRating,
              "category": entry.category,
              "image_paths": entry.imagePaths,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print("Wpis zapisany na serwerze!");
        return true;
      } else {
        print("Błąd zapisu wpisu: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Błąd połączenia przy zapisie: $e");
      return false;
    }
  }

  // 2. Pobieranie wpisów z serwera (do Kalendarza)
  Future<List<MoodEntry>> getEntries() async {
    if (currentUserId == null) return [];

    final url = Uri.parse('$_baseUrl/entries/$currentUserId');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));

        List<MoodEntry> entries = body.map((dynamic item) {
          return MoodEntry(
            id: item['id'],
            date: DateTime.parse(item['date']),
            text: item['text'],
            moodRating: (item['mood_rating'] as num).toDouble(),
            category: item['category'],
            aiAnalysis: item['ai_analysis'] ?? "",
            conversation: item['conversation'] ?? "",
            imagePaths: List<String>.from(item['image_paths'] ?? []),
            ownerId: item['owner_id'],
          );
        }).toList();

        return entries;
      } else {
        print("Błąd pobierania wpisów: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Błąd połączenia (pobieranie): $e");
      return [];
    }
  }

  // --- ANALIZA AI (NOWA METODA) ---
  Future<MoodAnalysis?> getMoodAnalysis(String rangeType) async {
    if (currentUserId == null) return null;

    final url = Uri.parse('$_baseUrl/ai/weekly_summary/$currentUserId');

    // Obliczamy daty na podstawie wybranego zakresu
    DateTime now = DateTime.now();
    DateTime startDate = now;

    switch (rangeType) {
      case 'Dzień':
        startDate = now;
        break;
      case 'Tydzień':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Miesiąc':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case 'Rok':
        startDate = now.subtract(const Duration(days: 365));
        break;
    }

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "start_date": startDate.toIso8601String(),
              "end_date": now.toIso8601String(),
            }),
          )
          .timeout(
            const Duration(seconds: 15),
          ); // Dłuższy timeout dla analizy AI

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return MoodAnalysis.fromJson(data);
      } else {
        print("Błąd analizy API: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Błąd połączenia (analiza): $e");
      return null;
    }
  }
}
