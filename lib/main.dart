import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';

import 'Services/database_service.dart';
import 'models/mood_entry.dart';
import 'screens/calendar_screen.dart' show CalendarScreen, CalendarScreenState;
import 'screens/home_screen.dart' show HomeScreenUI, HomeScreenUIState;
import 'screens/chat_screen.dart';
import 'widgets/edit_entry_screen.dart';
import 'widgets/mood_card.dart';

// ... AppColors, AppSettings, main(), MoodJournalApp, LoginScreen (BEZ ZMIAN) ...

// Wklejam od AppColors do MainAppScaffold, bo tam są zmiany:

class AppColors {
  static const Color primaryBlue = Color(0xFF0D47A1);
  static const Color backgroundWhite = Color(0xFFF5F6F8);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color textDark = Color(0xFF1E1E1E);
  static const Color textLight = Color(0xFFEEEEEE);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color cardBlue = Color(0xFF42A5F5);
  static const Color cardRed = Color(0xFFEF5350);
  static const Color chatBubbleUser = Color(0xFF0D47A1);
  static const Color chatBubbleAI = Color(0xFFFFFFFF);
  static const Color chatBubbleAIDark = Color(0xFF2C2C2C);
  static const Color angerRed = Color(0xFFD32F2F);
}

class AppSettings extends ChangeNotifier {
  double fontSize = 14.0;
  bool isAiFemale = false;
  bool isDarkMode = false;

  void setFontSizeSmall() {
    fontSize = 12.0;
    notifyListeners();
  }

  void setFontSizeMedium() {
    fontSize = 14.0;
    notifyListeners();
  }

  void setFontSizeLarge() {
    fontSize = 16.0;
    notifyListeners();
  }

  void toggleGender(bool value) {
    isAiFemale = value;
    notifyListeners();
  }

  void toggleTheme(bool value) {
    isDarkMode = value;
    notifyListeners();
  }
}

final AppSettings appSettings = AppSettings();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('pl_PL', null);
  Intl.defaultLocale = 'pl_PL';

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
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: AnimatedBuilder(
        animation: appSettings,
        builder: (context, child) {
          return MaterialApp(
            title: 'Mood Journal',
            debugShowCheckedModeBanner: false,
            themeMode: appSettings.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,

            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: AppColors.backgroundWhite,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryBlue,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.backgroundWhite,
                surfaceTintColor: Colors.transparent,
                iconTheme: IconThemeData(color: AppColors.textDark),
              ),
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
            ),

            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: AppColors.backgroundDark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryBlue,
                brightness: Brightness.dark,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.backgroundDark,
                surfaceTintColor: Colors.transparent,
                iconTheme: IconThemeData(color: AppColors.textLight),
              ),
              textTheme: TextTheme(
                bodyMedium: TextStyle(
                  fontSize: appSettings.fontSize,
                  color: AppColors.textLight,
                ),
                bodyLarge: TextStyle(
                  fontSize: appSettings.fontSize + 2,
                  color: AppColors.textLight,
                ),
                headlineMedium: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textLight,
                ),
              ),
              drawerTheme: const DrawerThemeData(
                backgroundColor: Color(0xFF1E1E1E),
              ),
            ),
            home: const LoginScreen(),
          );
        },
      ),
    );
  }
}

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

              Bounceable(
                scaleFactor: 0.85,
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await Future.delayed(const Duration(milliseconds: 50));

                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MainAppScaffold(),
                      ),
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "Rozpocznij podróż",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
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
      // ZMIANA: Czyścimy aktywny czat przy przejściu
      _activeChatEntry = null;
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

            Bounceable(
              scaleFactor: 0.85,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                _openChatWithEntry(entry);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat, color: Colors.white),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        entry.conversation.isNotEmpty
                            ? "Kontynuuj rozmowę"
                            : "Rozpocznij rozmowę z AI",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Bounceable(
              scaleFactor: 0.9,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                _openEditScreen(entry);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.primaryBlue),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit, color: AppColors.primaryBlue),
                    SizedBox(width: 8),
                    Text(
                      "Edytuj treść",
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Bounceable(
              scaleFactor: 0.9,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                _confirmDelete(entry);
              },
              child: Container(
                padding: const EdgeInsets.all(8.0),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      "Usuń wpis",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
              HapticFeedback.mediumImpact();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Rozmowa z Asystentem",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),
            Bounceable(
              scaleFactor: 0.9,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
              child: ListTile(
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
                title: Text("Nowy wpis", style: TextStyle(color: textColor)),
                subtitle: Text(
                  "Opisz jak się teraz czujesz",
                  style: TextStyle(color: subTextColor),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Bounceable(
              scaleFactor: 0.9,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                _showEntryPicker(context);
              },
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.history, color: Colors.orange),
                ),
                title: Text(
                  "Wpis z historii",
                  style: TextStyle(color: textColor),
                ),
                subtitle: Text(
                  "Porozmawiaj o przeszłości",
                  style: TextStyle(color: subTextColor),
                ),
              ),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              "Wybierz wpis",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: textColor,
              ),
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
        bottomNavigationBar: SafeArea(
          child: Container(
            height: 85,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
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
        return ChatScreen(
          entry: _activeChatEntry!,
          onBack: _backToHome,
          // ZMIANA: Przekazujemy callback do ChatScreen
          onGoToCalendar: _goToCalendar,
        );
      case 3:
        return const PlaceholderScreen(title: "Profil");
      default:
        return HomeScreenUI(key: _homeKey);
    }
  }

  Widget _buildChatButton(int index, String label) {
    bool isSelected = _currentIndex == index;
    return Bounceable(
      onTap: _handleChatTabTap,
      scaleFactor: 0.8,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
              size: 26,
              color: isSelected ? AppColors.primaryBlue : Colors.grey.shade400,
            ),
            const SizedBox(height: 2),
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
    return Bounceable(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
      },
      scaleFactor: 0.8,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? AppColors.primaryBlue : Colors.grey.shade400,
            ),
            const SizedBox(height: 2),
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
