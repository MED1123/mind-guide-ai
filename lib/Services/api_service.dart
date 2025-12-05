import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  // Singleton - jedna instancja serwisu na całą aplikację
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Pobieranie adresu URL z pliku .env
  String get _baseUrl {
    final url = dotenv.env['API_URL'];
    if (url == null) {
      // Zabezpieczenie: domyślne adresy dla emulatorów
      if (Platform.isAndroid) return "http://10.0.2.2:8000";
      return "http://127.0.0.1:8000";
    }
    return url;
  }

  // --- REJESTRACJA ---
  Future<bool> registerUser(String email, String password) async {
    final url = Uri.parse('$_baseUrl/auth/register');
    print("Próba rejestracji na adres: $url"); // Logowanie dla debugowania

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (response.statusCode == 200) {
        print("Sukces: ${response.body}");
        return true;
      } else {
        print("Błąd serwera: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("Błąd połączenia: $e");
      return false;
    }
  }
}
