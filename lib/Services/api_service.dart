import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/mood_entry.dart';
import '../models/mood_analysis.dart';
import '../models/sobriety_clock.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? currentUserId;

  String get _baseUrl {
    final url = dotenv.env['API_URL'];
    if (url == null) {
      if (Platform.isAndroid) return "http://10.0.2.2:8888";
      return "http://127.0.0.1:8888";
    }
    return url;
  }

  // --- AUTH ---

  Future<bool> registerUser(
    String email,
    String username,
    String password,
  ) async {
    final url = Uri.parse('$_baseUrl/auth/register');
    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "email": email,
              "username": username, // <--- WYSYŁAMY USERNAME
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print("Błąd rejestracji: $e");
      return false;
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    final url = Uri.parse('$_baseUrl/auth/forgot-password');
    // Using x-www-form-urlencoded as backend expects Form(...)
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "email": email,
        },
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print("Błąd żądania resetu hasła: $e");
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
            body: jsonEncode({
              "email": email,
              "username": "",
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentUserId = data['user_id'].toString();
        print("Zalogowano ID: $currentUserId");
        return true;
      } else if (response.statusCode == 403) {
        throw "EmailNotVerified";
      } else {
        throw "LoginFailed"; // 400 or others
      }
    } catch (e) {
      print("Błąd logowania: $e");
      rethrow;
    }
  }

  // --- USER PROFILE ---

  Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUserId == null) return null;
    final url = Uri.parse('$_baseUrl/users/$currentUserId');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      print("Błąd pobierania profilu: $e");
    }
    return null;
  }

  Future<bool> updateUserProfile({
    String? name,
    String? surname,
    String? username,
    String? birthDate,
    String? email,
    String? profileImagePath,
    bool? isDarkMode,
    String? password,
    String? oldPassword,
    String? customAssistantName,
  }) async {
    if (currentUserId == null) return false;
    final url = Uri.parse('$_baseUrl/users/$currentUserId');

    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name;
    if (surname != null) body['surname'] = surname;
    if (username != null) body['username'] = username;
    if (birthDate != null) body['birth_date'] = birthDate;
    if (email != null) body['email'] = email;
    if (profileImagePath != null) body['profile_image_path'] = profileImagePath;
    if (isDarkMode != null) body['is_dark_mode'] = isDarkMode;
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
      if (oldPassword != null) body['old_password'] = oldPassword;
    }
    if (customAssistantName != null) body['custom_assistant_name'] = customAssistantName;

    try {
      final response = await http
          .put(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print("Błąd aktualizacji profilu: $e");
      return false;
    }
  }

  Future<bool> deleteUserAccount() async {
    if (currentUserId == null) return false;
    final url = Uri.parse('$_baseUrl/users/$currentUserId');
    try {
      final response = await http.delete(url).timeout(const Duration(seconds: 10));
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print("Błąd usuwania konta: $e");
      return false;
    }
  }

  // --- WPISY (ENTRIES) ---

  Future<int?> createEntry(MoodEntry entry) async {
    if (currentUserId == null) {
      print("Błąd: Nie zalogowano użytkownika!");
      return null;
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
              "date": entry.date.toIso8601String(),
              "conversation": entry.conversation,
              "ai_analysis": entry.aiAnalysis,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print("Wpis zapisany na serwerze! ID: ${data['id']}");
        return data['id'] as int?;
      } else {
        print("Błąd zapisu wpisu: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Błąd połączenia przy zapisie: $e");
      return null;
    }
  }

  Future<bool> updateEntry(MoodEntry entry) async {
    if (currentUserId == null || entry.backendId == null) {
        print("Cannot update entry: Missing UserId or BackendId");
        return false;
    }
    final url = Uri.parse('$_baseUrl/entries/${entry.backendId}');
    try {
      final response = await http
          .put(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "text": entry.text,
              "mood_rating": entry.moodRating, // Required by schema but ignored/overwritten usually
              "category": entry.category,
              "image_paths": entry.imagePaths,
              "date": entry.date.toIso8601String(),
              "conversation": entry.conversation,
              "ai_analysis": entry.aiAnalysis,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print("Wpis zaktualizowany na serwerze! ID: ${entry.backendId}");
        return true;
      } else {
        print("Błąd aktualizacji wpisu: ${response.statusCode} ${response.body}");
        return false;
      }
    } catch (e) {
      print("Błąd połączenia (aktualizacja): $e");
      return false;
    }
  }

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
            ownerId: item['owner_id'].toString(),
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

  Future<bool> deleteEntry(int entryId) async {
    if (currentUserId == null) return false;
    final url = Uri.parse('$_baseUrl/entries/$entryId');
    try {
      final response = await http
          .delete(url)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 204 || response.statusCode == 200) {
        print("Wpis usunięty z serwera!");
        return true;
      } else {
        print("Błąd usuwania wpisu: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Błąd połączenia (usuwanie): $e");
      return false;
    }
  }

  // Robust deletion fallback - Server Side
  Future<bool> deleteEntryByContent(DateTime date, String text) async {
    if (currentUserId == null) return false;
    final url = Uri.parse('$_baseUrl/entries/delete_by_content');
    
    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "user_id": currentUserId,
              "text": text,
              "date": date.toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print("Usunięto wpis(y) poprzez dopasowanie zawartości.");
        return true;
      } else {
        print("Nie znaleziono wpisu do usunięcia (fallback): ${response.body}");
        return false;
      }
    } catch (e) {
      print("Błąd deleteEntryByContent: $e");
      return false;
    }
  }

  // --- ANALIZA AI ---
  Future<MoodAnalysis?> getMoodAnalysis(String rangeType, String languageCode) async {
    // ... (existing code) ...
    if (currentUserId == null) return null;

    final url = Uri.parse('$_baseUrl/ai/weekly_summary/$currentUserId');
    DateTime now = DateTime.now();
    DateTime startDate = now;

    // Mapowanie zakresów (teraz spójne klucze)
    switch (rangeType) {
      case 'day':
        startDate = now;
        break;
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case 'year':
        startDate = now.subtract(const Duration(days: 365));
        break;
      default:
        // Fallback - domyślnie tydzień
        startDate = now.subtract(const Duration(days: 7));
    }

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "start_date": startDate.toIso8601String(),
              "end_date": now.toIso8601String(),
              "lang": languageCode, // <--- NOWY PARAMETR
            }),
          )
          .timeout(const Duration(seconds: 15));

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

  // --- SOBRIETY CLOCK ---
  Future<bool> createSobrietyClock(String type, DateTime startDate, {String customName = ""}) async {
    if (currentUserId == null) return false;
    final url = Uri.parse('$_baseUrl/sobriety/clocks');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": currentUserId,
          "addiction_type": type,
          "custom_name": customName,
          "start_date": startDate.toIso8601String(),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Błąd tworzenia zegara: $e");
      return false;
    }
  }

  Future<List<SobrietyClock>> getSobrietyClocks() async {
    if (currentUserId == null) return [];
    final url = Uri.parse('$_baseUrl/sobriety/clocks/$currentUserId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((e) => SobrietyClock.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("Błąd pobierania zegarów: $e");
      return [];
    }
  }

  Future<bool> resetSobrietyClock(int clockId, DateTime newDate) async {
    final url = Uri.parse('$_baseUrl/sobriety/clocks/$clockId/reset');
    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"new_date": newDate.toIso8601String()}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Błąd resetowania zegara: $e");
      return false;
    }
  }

  Future<bool> deleteSobrietyClock(int clockId) async {
    final url = Uri.parse('$_baseUrl/sobriety/clocks/$clockId');
    try {
      final response = await http.delete(url);
      return response.statusCode == 200;
    } catch (e) {
      print("Błąd usuwania zegara: $e");
      return false;
    }
  }
}
