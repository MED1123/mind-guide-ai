import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
// Upewnij się, że ten plik istnieje w folderze lib/Services/
import 'Services/gpt_service.dart';

// --- KONFIGURACJA KOLORÓW ---
class AppColors {
  static const Color primaryBlue = Color(0xFF0D47A1);
  static const Color backgroundWhite = Color(0xFFF5F6F8);
  static const Color textDark = Color(0xFF1E1E1E);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color cardBlue = Color(0xFF42A5F5);
  static const Color cardRed = Color(0xFFEF5350);
}

// --- MODEL DANYCH ---
class MoodEntry {
  final DateTime date;
  final String text;
  final double moodRating;
  final String category;
  final String aiAnalysis;

  MoodEntry({
    required this.date,
    required this.text,
    required this.moodRating,
    required this.category,
    required this.aiAnalysis,
  });
}

// Globalna lista przechowująca wpisy w pamięci (zniknie po restarcie aplikacji)
List<MoodEntry> globalMoodHistory = [];

// --- START APLIKACJI ---
Future<void> main() async {
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("INFO: Brak pliku .env, AI nie zadziała, ale UI się uruchomi.");
  }
  runApp(const MoodJournalApp());
}

class MoodJournalApp extends StatelessWidget {
  const MoodJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mood Journal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.backgroundWhite,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryBlue),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32),
          headlineMedium: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 24),
          bodyMedium: TextStyle(color: AppColors.textGrey, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// --- EKRAN 1: LOGOWANIE ---
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(Icons.auto_awesome, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                "Mood Journal",
                style: TextStyle(
                  fontFamily: 'Serif',
                  fontSize: 40,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Zrozum swoje emocje\nz pomocą sztucznej inteligencji",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryBlue,
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MainAppScaffold()),
                    );
                  },
                  child: const Text("Rozpocznij podróż", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// --- GŁÓWNY SZKIELET Z NAWIGACJĄ ---
class MainAppScaffold extends StatefulWidget {
  const MainAppScaffold({super.key});

  @override
  State<MainAppScaffold> createState() => _MainAppScaffoldState();
}

class _MainAppScaffoldState extends State<MainAppScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreenUI(),
    const PlaceholderScreen(title: "Kalendarz"),
    const PlaceholderScreen(title: "Profil"),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Chowanie klawiatury
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        body: _pages[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: const Offset(0, -5))],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_filled, 0),
                _buildNavItem(Icons.calendar_month, 1),
                _buildNavItem(Icons.person, 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    bool isSelected = _currentIndex == index;
    return IconButton(
      icon: Icon(icon, size: 28),
      color: isSelected ? AppColors.primaryBlue : Colors.grey.shade400,
      onPressed: () => setState(() => _currentIndex = index),
    );
  }
}

// --- EKRAN GŁÓWNY UI ---
class HomeScreenUI extends StatefulWidget {
  const HomeScreenUI({super.key});

  @override
  State<HomeScreenUI> createState() => _HomeScreenUIState();
}

class _HomeScreenUIState extends State<HomeScreenUI> {
  final TextEditingController _textController = TextEditingController();
  String _selectedCategory = "Spokój";
  final List<String> _categories = ["Spokój", "Radość", "Stres", "Smutek", "Zmęczenie"];

  // --- LOGIKA IKON I KOLORÓW ---
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "Radość": return Icons.sentiment_very_satisfied;
      case "Stres": return Icons.bolt;
      case "Smutek": return Icons.cloud; // lub beach_access
      case "Zmęczenie": return Icons.bedtime;
      case "Spokój":
      default: return Icons.self_improvement;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case "Radość": return Colors.orange;
      case "Stres": return AppColors.cardRed;
      case "Smutek": return Colors.blueGrey;
      case "Zmęczenie": return Colors.purpleAccent;
      case "Spokój":
      default: return AppColors.cardBlue;
    }
  }

  // --- LOGIKA ZAPISYWANIA ---
  void _handleSend() {
    if (_textController.text.isEmpty) return;
    
    // Tworzymy nowy wpis
    final newEntry = MoodEntry(
      date: DateTime.now(),
      text: _textController.text,
      moodRating: 3.0, // Domyślna ocena, dopóki nie dodamy suwaka
      category: _selectedCategory,
      aiAnalysis: "Analiza pojawi się tutaj...", // Placeholder na Etap 3
    );

    // Dodajemy do listy i odświeżamy ekran
    setState(() {
      globalMoodHistory.add(newEntry);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Dodano nowy wpis!"),
        backgroundColor: AppColors.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    
    _textController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // Odwracamy listę, żeby najnowsze wpisy były na górze (lub po lewej)
    final recentEntries = globalMoodHistory.reversed.toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Nagłówek
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Cześć, Ty 👋", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    Text("Jak się dzisiaj czujesz?", style: TextStyle(fontSize: 16, color: AppColors.textGrey)),
                  ],
                ),
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, color: Colors.white),
                )
              ],
            ),
            const SizedBox(height: 30),

            // 2. Pole Tekstowe
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: TextField(
                controller: _textController,
                maxLines: null, 
                enabled: true, 
                decoration: InputDecoration(
                  icon: const Icon(Icons.edit, color: AppColors.textGrey),
                  hintText: "Napisz, co Cię spotkało...",
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primaryBlue),
                    onPressed: _handleSend,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 3. Wybór Kategorii
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Twój nastrój", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(_selectedCategory, style: TextStyle(color: _getCategoryColor(_selectedCategory), fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 15),

            // Chipsy
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((category) {
                  final bool isActive = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.textDark : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: isActive ? null : Border.all(color: Colors.grey.shade200),
                        boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0,4))] : [],
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isActive ? Colors.white : AppColors.textGrey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 30),

            // 4. Sekcja "Twoje Ostatnie Wpisy" (Dynamiczna)
            const Text("Twoje ostatnie wpisy", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            if (recentEntries.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text("Twój dziennik jest pusty.\nDodaj pierwszy wpis powyżej!", 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textGrey.withOpacity(0.5))),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true, // Ważne: pozwala liście być wewnątrz ScrollView
                physics: const NeverScrollableScrollPhysics(), // Przewijanie obsłuży główny ekran
                itemCount: recentEntries.length,
                itemBuilder: (context, index) {
                  final entry = recentEntries[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _buildMoodCard(
                      title: entry.category,
                      subtitle: entry.text,
                      color: _getCategoryColor(entry.category),
                      icon: _getCategoryIcon(entry.category),
                      date: entry.date,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodCard({
    required String title, 
    required String subtitle, 
    required Color color, 
    required IconData icon,
    required DateTime date,
  }) {
    return Container(
      height: 180, // Nieco mniejsza wysokość dla listy
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.8)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: Colors.white),
              ),
              Text(DateFormat('HH:mm').format(date), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                subtitle, 
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          )
        ],
      ),
    );
  }
}

// --- POMOCNICZY EKRAN ---
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text(title, style: const TextStyle(fontSize: 24, color: AppColors.textGrey)));
  }
}