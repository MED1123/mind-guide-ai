import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'Services/database_service.dart';
import 'Services/gpt_service.dart';
import 'models/mood_entry.dart';

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
  final GlobalKey<_HomeScreenUIState> _homeKey = GlobalKey();
  final GlobalKey<_CalendarScreenState> _calendarKey = GlobalKey();

  // Zmienna przechowująca wpis, o którym aktualnie rozmawiamy
  MoodEntry? _activeChatEntry;

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
                _createNewEntryAndChat();
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

  void _createNewEntryAndChat() async {
    final newEntry = MoodEntry(
      date: DateTime.now(),
      text: "Rozmowa z asystentem",
      moodRating: 3.0,
      category: "Rozmowa",
      aiAnalysis: "",
      conversation: "",
    );

    int id = await DatabaseService.instance.createEntry(newEntry);
    final entryWithId = MoodEntry(
      id: id,
      date: newEntry.date,
      text: newEntry.text,
      moodRating: newEntry.moodRating,
      category: newEntry.category,
      aiAnalysis: newEntry.aiAnalysis,
      conversation: newEntry.conversation,
    );

    _openChatWithEntry(entryWithId);
  }

  // Zmiana: Zamiast Navigator.push, zmieniamy stan głównego widoku
  void _openChatWithEntry(MoodEntry entry) {
    setState(() {
      _activeChatEntry = entry;
      _currentIndex = 2; // Przełączamy na zakładkę Czat
    });
  }

  // Powrót z czatu do Home
  void _backToHome() {
    setState(() {
      _currentIndex = 0;
      _homeKey.currentState?.refreshEntries(); // Odświeżamy listę po powrocie
      _calendarKey.currentState?._loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        // Zamiast IndexedStack, używamy warunku dla czatu, by wymusić odświeżenie przy zmianie wpisu
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
              // Zmniejszony padding zgodnie z życzeniem
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
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
        return HomeScreenUI(key: _homeKey, onOpenChat: _openChatWithEntry);
      case 1:
        return CalendarScreen(
          key: _calendarKey,
          onOpenChat: _openChatWithEntry,
        );
      case 2:
        if (_activeChatEntry == null) {
          // Jeśli user kliknie ikonę Asystenta bez wybrania wpisu, pokazujemy menu
          // Ale ponieważ onTap na ikonie otwiera modal, ten stan jest rzadki.
          // Dajemy tu pusty ekran, a modal się otworzy.
          return const Center(child: Text("Wybierz temat rozmowy w menu"));
        }
        return ChatScreen(
          entry: _activeChatEntry!,
          onBack: _backToHome, // Przekazujemy funkcję powrotu
        );
      case 3:
        return const PlaceholderScreen(title: "Profil");
      default:
        return HomeScreenUI(key: _homeKey);
    }
  }

  // Ikona czatu - teraz zachowuje się wizualnie jak inne (szara/niebieska)
  // Ale jej kliknięcie otwiera modal wyboru tematu
  Widget _buildChatButton(int index, String label) {
    bool isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: _handleChatTabTap, // Zawsze otwiera modal
        behavior: HitTestBehavior.translucent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? Icons.chat_bubble
                  : Icons.chat_bubble_outline, // Wypełniona jeśli aktywna
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

// --- 6. WIDGET KARTY NASTROJU ---
class MoodCard extends StatelessWidget {
  final MoodEntry entry;
  final VoidCallback? onTap;

  const MoodCard({super.key, required this.entry, this.onTap});

  Color _getCategoryColor(String category) {
    switch (category) {
      case "Radość":
        return Colors.orange;
      case "Stres":
        return AppColors.cardRed;
      case "Smutek":
        return Colors.blueGrey;
      case "Zmęczenie":
        return Colors.purple;
      case "Złość":
        return AppColors.angerRed;
      default:
        return AppColors.cardBlue;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "Radość":
        return Icons.sentiment_very_satisfied;
      case "Stres":
        return Icons.bolt;
      case "Smutek":
        return Icons.cloud;
      case "Zmęczenie":
        return Icons.bedtime;
      case "Złość":
        return Icons.whatshot;
      default:
        return Icons.self_improvement;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(entry.category);
    final icon = _getCategoryIcon(entry.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.8)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                Text(
                  DateFormat('dd MMM, HH:mm').format(entry.date),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- 7. EKRAN GŁÓWNY (HOME) ---
class HomeScreenUI extends StatefulWidget {
  // Dodajemy callback, żeby HomeScreen mógł otworzyć czat w głównym Scaffoldzie
  final Function(MoodEntry) onOpenChat;
  const HomeScreenUI({super.key, this.onOpenChat = _defaultOpenChat});

  static void _defaultOpenChat(MoodEntry e) {}

  @override
  State<HomeScreenUI> createState() => _HomeScreenUIState();
}

class _HomeScreenUIState extends State<HomeScreenUI> {
  final TextEditingController _textController = TextEditingController();
  String _selectedCategory = "Spokój";
  final List<String> _categories = [
    "Spokój",
    "Radość",
    "Stres",
    "Smutek",
    "Zmęczenie",
    "Złość",
  ];
  late Future<List<MoodEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    refreshEntries();
  }

  void refreshEntries() {
    setState(() {
      _entriesFuture = DatabaseService.instance.readAllEntries();
    });
  }

  void _handleSend() async {
    if (_textController.text.isEmpty) return;
    final newEntry = MoodEntry(
      date: DateTime.now(),
      text: _textController.text,
      moodRating: 3.0,
      category: _selectedCategory,
      aiAnalysis: "",
      conversation: "User: ${_textController.text}|",
    );
    await DatabaseService.instance.createEntry(newEntry);
    refreshEntries();
    _textController.clear();
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Dodano nowy wpis!")));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NAGŁÓWEK
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Cześć 👋",
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(fontSize: 32),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Jak się dzisiaj czujesz?",
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryBlue,
                            width: 2,
                          ),
                        ),
                        child: const CircleAvatar(
                          radius: 22,
                          backgroundImage: NetworkImage(
                            "https://i.pravatar.cc/150?img=68",
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // POLE TEKSTOWE
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: "Opisz swoje myśli...",
                        hintStyle: TextStyle(
                          color: AppColors.textGrey.withOpacity(0.5),
                        ),
                        prefixIcon: const Icon(
                          Icons.edit_note,
                          color: AppColors.primaryBlue,
                        ),
                        suffixIcon: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                            // Zmiana ikony na strzałkę w prawo
                            child: const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          onPressed: _handleSend,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // KATEGORIE
                  const Text(
                    "Kategorie",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategory = category),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryBlue
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : Colors.grey.shade200,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primaryBlue
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textGrey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // LISTA WPISÓW
                  const Text(
                    "Ostatnie wpisy",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<MoodEntry>>(
                    future: _entriesFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Text(
                            "Brak wpisów",
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final entry = snapshot.data![index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: MoodCard(
                              entry: entry,
                              onTap: () => widget.onOpenChat(
                                entry,
                              ), // Używamy callbacka z Main
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 8. EKRAN KALENDARZA ---
class CalendarScreen extends StatefulWidget {
  final Function(MoodEntry) onOpenChat;
  const CalendarScreen({super.key, this.onOpenChat = _defaultOpenChat});

  static void _defaultOpenChat(MoodEntry e) {}

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<MoodEntry>> _groupedEvents = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  void _loadEvents() async {
    final entries = await DatabaseService.instance.readAllEntries();
    final Map<DateTime, List<MoodEntry>> data = {};
    for (var entry in entries) {
      final dateKey = DateTime.utc(
        entry.date.year,
        entry.date.month,
        entry.date.day,
      );
      if (data[dateKey] == null) data[dateKey] = [];
      data[dateKey]!.add(entry);
    }
    if (mounted)
      setState(() {
        _groupedEvents = data;
      });
  }

  List<MoodEntry> _getEventsForDay(DateTime day) {
    final dateKey = DateTime.utc(day.year, day.month, day.day);
    return _groupedEvents[dateKey] ?? [];
  }

  Color _getDotColor(String category) {
    if (category == "Stres" || category == "Smutek" || category == "Złość")
      return AppColors.cardRed;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Text(
                  " Twój Kalendarz",
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                calendarStyle: const CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Color(0x4D0D47A1),
                    shape: BoxShape.circle,
                  ),
                  weekendTextStyle: TextStyle(color: AppColors.textGrey),
                ),
                eventLoader: _getEventsForDay,
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return null;
                    final entries = events as List<MoodEntry>;
                    final color = _getDotColor(entries.first.category);
                    return Positioned(
                      bottom: 1,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                    child: Text(
                      _selectedDay != null
                          ? "Wpisy z ${DateFormat('d MMMM').format(_selectedDay!)}"
                          : "Wybierz dzień",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: selectedEvents.isEmpty
                        ? Center(
                            child: Text(
                              "Brak wpisów",
                              style: TextStyle(
                                color: AppColors.textGrey.withOpacity(0.5),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: selectedEvents.length,
                            itemBuilder: (context, index) {
                              final entry = selectedEvents[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: MoodCard(
                                  entry: entry,
                                  onTap: () => widget.onOpenChat(
                                    entry,
                                  ), // Callback do otwarcia czatu
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 9. EKRAN CZATU (Wbudowany w zakładkę) ---
class ChatScreen extends StatefulWidget {
  final MoodEntry entry;
  final VoidCallback onBack; // Callback do powrotu na Start

  const ChatScreen({super.key, required this.entry, required this.onBack});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  late MoodEntry _currentEntry;

  @override
  void initState() {
    super.initState();
    _currentEntry = widget.entry;
    _loadMessagesFromEntry();

    // AUTOMATYCZNA ODPOWIEDŹ (Jeśli wchodzimy z historii, a nie było czatu)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messages.length == 1 &&
          _messages[0]['role'] == 'user' &&
          _currentEntry.category != "Rozmowa") {
        _triggerAutoReply();
      }
    });
  }

  void _loadMessagesFromEntry() {
    if (_currentEntry.conversation.isNotEmpty) {
      final parts = _currentEntry.conversation.split('|');
      for (var part in parts) {
        if (part.startsWith("User: "))
          _messages.add({"role": "user", "text": part.substring(6)});
        else if (part.startsWith("AI: "))
          _messages.add({"role": "ai", "text": part.substring(4)});
      }
    } else if (_currentEntry.text.isNotEmpty &&
        _currentEntry.text != "Rozmowa z asystentem") {
      _messages.add({"role": "user", "text": _currentEntry.text});
    }
  }

  void _triggerAutoReply() async {
    setState(() {
      _isTyping = true;
    });
    _scrollToBottom();

    String historyStr = "User: ${_currentEntry.text}";
    final aiResponse = await GptService.chatWithAI(
      _currentEntry.text,
      historyStr,
      appSettings.isAiFemale,
    );

    if (!mounted) return;
    setState(() {
      _messages.add({"role": "ai", "text": aiResponse});
      _isTyping = false;
    });
    _scrollToBottom();
    _saveConversation();
  }

  void _sendMessage() async {
    if (_inputController.text.trim().isEmpty) return;
    final userText = _inputController.text;

    setState(() {
      _messages.add({"role": "user", "text": userText});
      _inputController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    String historyStr = _messages
        .map((m) => "${m['role'] == 'user' ? 'User' : 'AI'}: ${m['text']}")
        .join("\n");
    final aiResponse = await GptService.chatWithAI(
      userText,
      historyStr,
      appSettings.isAiFemale,
    );

    if (!mounted) return;
    setState(() {
      _messages.add({"role": "ai", "text": aiResponse});
      _isTyping = false;
    });
    _scrollToBottom();
    _saveConversation();
  }

  void _saveConversation() async {
    String newConversation = _messages
        .map((m) => "${m['role'] == 'user' ? 'User' : 'AI'}: ${m['text']}")
        .join("|");
    String mainText =
        _currentEntry.text == "Rozmowa z asystentem" && _messages.isNotEmpty
        ? _messages[0]['text']!
        : _currentEntry.text;

    final updatedEntry = MoodEntry(
      id: _currentEntry.id,
      date: _currentEntry.date,
      text: mainText,
      moodRating: _currentEntry.moodRating,
      category: _currentEntry.category,
      aiAnalysis: _currentEntry.aiAnalysis,
      conversation: newConversation,
    );
    await DatabaseService.instance.updateEntry(updatedEntry);
    _currentEntry = updatedEntry;
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        // Zmiana: Przycisk Wróć wywołuje callback, a nie Navigator.pop
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: widget.onBack,
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
              child: Icon(
                appSettings.isAiFemale ? Icons.face_3 : Icons.face,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Asystent AI",
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "Dostępny",
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.settings, color: AppColors.textGrey),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "Ustawienia",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text("Żeński głos AI"),
                value: appSettings.isAiFemale,
                activeColor: AppColors.primaryBlue,
                onChanged: (val) => appSettings.toggleGender(val),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Wielkość czcionki"),
                ),
              ),
              Slider(
                value: appSettings.fontSize,
                min: 10,
                max: 24,
                divisions: 7,
                activeColor: AppColors.primaryBlue,
                label: appSettings.fontSize.round().toString(),
                onChanged: (val) => appSettings.setFontSize(val),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppColors.chatBubbleUser
                          : AppColors.chatBubbleAI,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        fontSize:
                            appSettings.fontSize, // Użycie ustawień czcionki
                        color: isUser ? Colors.white : AppColors.textDark,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "AI pisze...",
                  style: TextStyle(
                    color: AppColors.textGrey.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWhite,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _inputController,
                        decoration: const InputDecoration(
                          hintText: "Napisz wiadomość...",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
