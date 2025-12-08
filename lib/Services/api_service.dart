import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/mood_entry.dart'; // Import modelu!

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

  // --- REJESTRACJA ---
  Future<bool> registerUser(String email, String password) async {
    final url = Uri.parse('$_baseUrl/auth/register');
    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print("Błąd rejestracji: $e");
      return false;
    }
  }

  // --- LOGOWANIE ---
  Future<bool> loginUser(String email, String password) async {
    final url = Uri.parse('$_baseUrl/auth/login');
    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 5));

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

  // --- TWORZENIE WPISU (NOWOŚĆ) ---
  Future<bool> createEntry(MoodEntry entry) async {
    if (currentUserId == null) {
      print("Błąd: Nie zalogowano użytkownika!");
      return false;
    }

    // Endpoint: /entries/{user_id}
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
              // Wysyłamy listę ścieżek do zdjęć
              "image_paths": entry.imagePaths,
            }),
          )
          .timeout(const Duration(seconds: 5));

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
}
