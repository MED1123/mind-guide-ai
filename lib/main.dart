import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'Services/database_service.dart';
import 'models/mood_entry.dart';
import 'screens/calendar_screen.dart' show CalendarScreen, CalendarScreenState;
import 'screens/home_screen.dart' show HomeScreenUI, HomeScreenUIState;
import 'screens/chat_screen.dart';
import 'widgets/edit_entry_screen.dart';
import 'widgets/mood_card.dart';

// --- 1. KONFIGURACJA KOLORÓW ---
class AppColors {
  static const Color primaryBlue = Color(0xFF0D47A1);
  static const Color backgroundWhite = Color(0xFFF5F6F8);
  static const Color textDark = Color(0xFF1E1E1E);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color cardBlue = Color(0xFF42A5F5);
  static const Color cardRed = Color(0xFFEF5350);
  static const Color chatBubbleUser = Color(0xFF0D47A1);
  static const Color chatBubbleAI = Color(0xFFFFFFFF);
  static const Color angerRed = Color(0xFFD32F2F);
}

// --- 2. GLOBALNE USTAWIENIA ---
class AppSettings extends ChangeNotifier {
  double fontSize = 14.0;
  bool isAiFemale = false;

  void setFontSize(double size) {
    fontSize = size;
    notifyListeners();
  }

  void toggleGender(bool value) {
    isAiFemale = value;
    notifyListeners();
  }
}

final AppSettings appSettings = AppSettings();

// --- 3. START APLIKACJI ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("INFO: Brak pliku .env");
  }
  runApp(const MoodJournalApp());
}

class MoodJournalApp extends StatelessWidget {
  const MoodJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettings,
      builder: (context, child) {
        return MaterialApp(
          title: 'Mood Journal',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.backgroundWhite,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryBlue),
            textTheme: TextTheme(
              bodyMedium: TextStyle(
                fontSize: appSettings.fontSize,
                color: AppColors.textDark,
              ),
              bodyLarge: TextStyle(
                fontSize: appSettings.fontSize + 2,
                color: AppColors.textDark,
              ),
              headlineMedium: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.backgroundWhite,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: AppColors.textDark),
            ),
          ),
          home: const LoginScreen(),
        );
      },
    );
  }
}

// --- 4. EKRAN LOGOWANIA ---
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                "Mood Journal",
                style: TextStyle(
                  fontSize: 42,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Twój osobisty asystent emocjonalny\nwspierany przez AI",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MainAppScaffold(),
                      ),
                    );
                  },
                  child: const Text(
                    "Rozpocznij podróż",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 5. GŁÓWNY SZKIELET Z NAWIGACJĄ ---
class MainAppScaffold extends StatefulWidget {
  const MainAppScaffold({super.key});

  @override
  State<MainAppScaffold> createState() => _MainAppScaffoldState();
}

class _MainAppScaffoldState extends State<MainAppScaffold> {
  int _currentIndex = 0;
  final GlobalKey<HomeScreenUIState> _homeKey = GlobalKey();
  final GlobalKey<CalendarScreenState> _calendarKey = GlobalKey();

  MoodEntry? _activeChatEntry;

  void _goToCalendar() {
    setState(() {
      _currentIndex = 1;
      Future.delayed(const Duration(milliseconds: 100), () {
        _calendarKey.currentState?.loadEvents();
      });
    });
  }

  void _openChatWithEntry(MoodEntry entry) {
    setState(() {
      _activeChatEntry = entry;
      _currentIndex = 2;
    });
  }

  // --- HOTFIX: ZARZĄDZANIE WPISEM (EDYCJA / USUWANIE) ---
  void _handleEntryTap(MoodEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Zarządzaj wpisem",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Co chcesz zrobić z tym wpisem?",
              style: TextStyle(color: AppColors.textGrey),
            ),
            const SizedBox(height: 20),

            // POPRAWKA: Przycisk czatu jest teraz zawsze widoczny
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openChatWithEntry(entry);
                  },
                  icon: const Icon(Icons.chat),
                  label: Text(
                    entry.conversation.isNotEmpty
                        ? "Kontynuuj rozmowę"
                        : "Rozpocznij rozmowę z AI",
                  ), // Zmienna etykieta
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openEditScreen(entry);
                },
                icon: const Icon(Icons.edit),
                label: const Text("Edytuj treść"),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDelete(entry);
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  "Usuń wpis",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(MoodEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Usuń wpis"),
        content: const Text(
          "Czy na pewno chcesz usunąć ten wpis? Tego nie można cofnąć.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Anuluj"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseService.instance.deleteEntry(entry.id!);
              _refreshAll();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Usunięto wpis")));
            },
            child: const Text(
              "Usuń",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _openEditScreen(MoodEntry entry) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditEntryScreen(entry: entry)),
    );

    if (result != null && result is MoodEntry) {
      _openChatWithEntry(result);
    }

    _refreshAll();
  }

  void _refreshAll() {
    _homeKey.currentState?.refreshEntries();
    _calendarKey.currentState?.loadEvents();
  }

  void _backToHome() {
    setState(() {
      _currentIndex = 0;
      _activeChatEntry = null;
      _refreshAll();
    });
  }

  void _handlePostCreated(MoodEntry entry, bool wantAI) {
    if (wantAI) {
      _openChatWithEntry(entry);
    } else {
      _goToCalendar();
    }
  }

  void _handleChatTabTap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Rozmowa z Asystentem",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_note,
                  color: AppColors.primaryBlue,
                ),
              ),
              title: const Text("Nowy wpis"),
              subtitle: const Text("Opisz jak się teraz czujesz"),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.history, color: Colors.orange),
              ),
              title: const Text("Wpis z historii"),
              subtitle: const Text("Porozmawiaj o przeszłości"),
              onTap: () {
                Navigator.pop(context);
                _showEntryPicker(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEntryPicker(BuildContext context) async {
    final entries = await DatabaseService.instance.readAllEntries();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "Wybierz wpis",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: MoodCard(
                      entry: entry,
                      onTap: () {
                        Navigator.pop(context);
                        _openChatWithEntry(entry);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        body: _buildBody(),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              child: Row(
                children: [
                  _buildNavItem(Icons.home_filled, 0, "Start"),
                  _buildNavItem(Icons.calendar_month, 1, "Kalendarz"),
                  _buildChatButton(2, "Asystent"),
                  _buildNavItem(Icons.person, 3, "Profil"),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return HomeScreenUI(
          key: _homeKey,
          onOpenChat: _handleEntryTap,
          onGoToCalendar: _goToCalendar,
          onPostCreated: _handlePostCreated,
        );
      case 1:
        return CalendarScreen(key: _calendarKey, onOpenChat: _handleEntryTap);
      case 2:
        if (_activeChatEntry == null) {
          return const Center(child: Text("Wybierz temat rozmowy w menu"));
        }
        return ChatScreen(entry: _activeChatEntry!, onBack: _backToHome);
      case 3:
        return const PlaceholderScreen(title: "Profil");
      default:
        return HomeScreenUI(key: _homeKey);
    }
  }

  Widget _buildChatButton(int index, String label) {
    bool isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: _handleChatTabTap,
        behavior: HitTestBehavior.translucent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
              size: 28,
              color: isSelected ? AppColors.primaryBlue : Colors.grey.shade400,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? AppColors.primaryBlue
                    : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, String label) {
    bool isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.translucent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? AppColors.primaryBlue : Colors.grey.shade400,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? AppColors.primaryBlue
                    : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      title,
      style: const TextStyle(color: AppColors.textGrey, fontSize: 18),
    ),
  );
}
