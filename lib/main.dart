import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';

import 'Services/database_service.dart';
import 'Services/api_service.dart';
import 'models/mood_entry.dart';
import 'screens/calendar_screen.dart' show CalendarScreen, CalendarScreenState;
import 'screens/home_screen.dart' show HomeScreenUI, HomeScreenUIState;
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/edit_entry_screen.dart';
import 'widgets/mood_card.dart';

// --- 1. KONFIGURACJA KOLORÓW ---
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

// --- 2. GLOBALNE USTAWIENIA ---
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

// --- 3. START APLIKACJI ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('pl_PL', null);
  Intl.defaultLocale = 'pl_PL';

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("INFO: Brak pliku .env lub błąd ładowania: $e");
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

            // MOTYW JASNY
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
              textTheme: const TextTheme(
                bodyMedium: TextStyle(
                  fontSize: 14.0,
                  color: AppColors.textDark,
                ),
                bodyLarge: TextStyle(fontSize: 16.0, color: AppColors.textDark),
                headlineMedium: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),

            // MOTYW CIEMNY
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
              textTheme: const TextTheme(
                bodyMedium: TextStyle(
                  fontSize: 14.0,
                  color: AppColors.textLight,
                ),
                bodyLarge: TextStyle(
                  fontSize: 16.0,
                  color: AppColors.textLight,
                ),
                headlineMedium: TextStyle(
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

// --- 4. EKRAN LOGOWANIA / REJESTRACJI ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _isPasswordVisible = false;
  bool _isLoginMode = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Podaj email i hasło")));
      return;
    }

    if (!_isLoginMode && username.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Podaj nazwę użytkownika")));
      return;
    }

    setState(() => _isLoading = true);

    bool success;
    String message = "";

    if (_isLoginMode) {
      success = await ApiService().loginUser(email, password);
      message = success
          ? "Zalogowano pomyślnie!"
          : "Błąd logowania. Sprawdź dane.";
    } else {
      success = await ApiService().registerUser(email, username, password);
      if (success) {
        await ApiService().loginUser(email, password);
        message = "Konto utworzone! Witaj $username.";
      } else {
        message = "Błąd rejestracji. Email może być zajęty.";
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainAppScaffold()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Styl dla pól tekstowych (mniejsza czcionka dla długich maili)
    const inputTextStyle = TextStyle(color: Colors.white, fontSize: 14.0);
    // Padding wewnętrzny (zwiększony komfort pisania, mniejsze marginesy boczne)
    const inputDecorationContentPadding = EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 18,
    );

    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Tytuł
                const Text(
                  "Mood Journal",
                  style: TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),

                // Podtytuł
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _isLoginMode ? "Witaj ponownie!" : "Utwórz nowe konto",
                    key: ValueKey(_isLoginMode),
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 40),

                // Nazwa użytkownika (tylko przy rejestracji)
                if (!_isLoginMode) ...[
                  TextField(
                    controller: _usernameController,
                    focusNode: _usernameFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_emailFocus);
                    },
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: "Nazwa użytkownika",
                      labelStyle: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                      ),
                      prefixIcon: const Icon(
                        Icons.person,
                        color: Colors.white70,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      contentPadding: inputDecorationContentPadding,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Email
                TextField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_passwordFocus);
                  },
                  style: inputTextStyle,
                  decoration: InputDecoration(
                    labelText: "Email",
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                    prefixIcon: const Icon(Icons.email, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    contentPadding: inputDecorationContentPadding,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Hasło
                TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: !_isPasswordVisible,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleSubmit(),
                  style: inputTextStyle,
                  decoration: InputDecoration(
                    labelText: "Hasło",
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                    prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    contentPadding: inputDecorationContentPadding,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Przycisk
                Bounceable(
                  scaleFactor: 0.95,
                  onTap: _isLoading ? () {} : _handleSubmit,
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
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isLoginMode ? "Zaloguj się" : "Zarejestruj się",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Przełącznik trybu
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLoginMode ? "Nie masz konta? " : "Masz już konto? ",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                          _emailController.clear();
                          _passwordController.clear();
                          _usernameController.clear();
                        });
                      },
                      child: Text(
                        _isLoginMode ? "Zarejestruj się" : "Zaloguj się",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
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
      _activeChatEntry = null;
      Future.delayed(const Duration(milliseconds: 100), () {
        _calendarKey.currentState?.loadEvents();
      });
    });
  }

  void _goToProfile() {
    setState(() {
      _currentIndex = 3;
      _activeChatEntry = null;
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Rozmowa z Asystentem",
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 30),
            Bounceable(
              scaleFactor: 0.9,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_note,
                      color: AppColors.primaryBlue,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Nowy wpis",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "Opisz jak się teraz czujesz",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Bounceable(
              scaleFactor: 0.9,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                _showEntryPicker(context);
              },
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history,
                      color: Colors.orange,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Wpis z historii",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "Porozmawiaj o przeszłości",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEntryPicker(BuildContext context) async {
    final currentUserId = ApiService().currentUserId;
    if (currentUserId == null) return;

    final entries = await DatabaseService.instance.readEntriesForUser(
      currentUserId,
    );

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
                itemCount: entries.length > 4 ? 4 : entries.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  // Sortujemy od najnowszych (odwracamy listę jeśli przychodzi rosnąco)
                  // Tutaj zakładamy, że baza zwraca chronologicznie, więc bierzemy od końca.
                  // Ale lepiej sprawdźmy sortowanie. Dla pewności sortujemy tutaj:
                  entries.sort((a, b) => b.date.compareTo(a.date));
                  
                  final entry = entries[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Bounceable(
                      scaleFactor: 0.95,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        _openChatWithEntry(entry);
                      },
                      child: MoodCard(entry: entry),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _goToCalendar();
                },
                icon: const Icon(Icons.calendar_month),
                label: const Text("Przejdź do kalendarza"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: textColor.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
        return CalendarScreen(
          key: _calendarKey,
          onOpenChat: _handleEntryTap,
          onGoToProfile: _goToProfile,
        );
      case 2:
        if (_activeChatEntry == null) {
          return const Center(child: Text("Wybierz temat rozmowy w menu"));
        }
        return ChatScreen(
          entry: _activeChatEntry!,
          onBack: _backToHome,
          onGoToCalendar: _goToCalendar,
        );
      case 3:
        return const ProfileScreen();
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
