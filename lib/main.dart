import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'Services/database_service.dart';
import 'Services/gpt_service.dart';
// Import modelu
import 'models/mood_entry.dart';

// --- KONFIGURACJA KOLORÓW (Clean UI) ---
class AppColors {
  static const Color primaryBlue = Color(0xFF0D47A1);
  static const Color backgroundWhite = Color(0xFFF5F6F8);
  static const Color textDark = Color(0xFF1E1E1E);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color cardBlue = Color(0xFF42A5F5);
  static const Color cardRed = Color(0xFFEF5350);
  static const Color chatBubbleUser = Color(0xFF0D47A1);
  static const Color chatBubbleAI = Color(0xFFFFFFFF);
}

// --- GLOBALNE USTAWIENIA ---
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

// --- START APLIKACJI ---
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
            ),
          ),
          home: const LoginScreen(),
        );
      },
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
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(Icons.auto_awesome, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                "Mood Journal",
                style: TextStyle(
                  fontSize: 40,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
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
  final GlobalKey<_HomeScreenUIState> _homeKey = GlobalKey();

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
                _createNewEntryAndChat(context);
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
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                      child: Text(
                        DateFormat('dd').format(entry.date),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    title: Text(
                      DateFormat('MMMM yyyy, HH:mm').format(entry.date),
                    ),
                    subtitle: Text(
                      entry.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textGrey,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(entry: entry),
                        ),
                      ).then((_) => _homeKey.currentState?.refreshEntries());
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createNewEntryAndChat(BuildContext context) async {
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

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(entry: entryWithId)),
    ).then((_) => _homeKey.currentState?.refreshEntries());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeScreenUI(key: _homeKey),
            const PlaceholderScreen(title: "Kalendarz"),
            const SizedBox(), // Placeholder dla przycisku czatu
            const PlaceholderScreen(title: "Profil"),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(Icons.home_filled, 0, "Start"),
                _buildNavItem(Icons.calendar_month, 1, "Kalendarz"),
                _buildChatButton(),
                _buildNavItem(Icons.person, 3, "Profil"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatButton() {
    return InkWell(
      onTap: _handleChatTabTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: AppColors.primaryBlue,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.chat_bubble, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, String label) {
    bool isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? AppColors.primaryBlue : Colors.grey.shade400,
            ),
            if (isSelected)
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- EKRAN GŁÓWNY UI (Przywrócony Wygląd) ---
class HomeScreenUI extends StatefulWidget {
  const HomeScreenUI({super.key});

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

  Color _getCategoryColor(String category) {
    switch (category) {
      case "Radość":
        return Colors.orange;
      case "Stres":
        return AppColors.cardRed;
      case "Smutek":
        return Colors.blueGrey;
      case "Zmęczenie":
        return Colors.purpleAccent;
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
      default:
        return Icons.self_improvement;
    }
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
                  // 1. NAGŁÓWEK (Zgodny ze screenshotem)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Cześć, Ty 👋",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            "Jak się dzisiaj czujesz?",
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                      const CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(
                          "https://i.pravatar.cc/150?img=12",
                        ), // Avatar z API
                        backgroundColor: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // 2. POLE TEKSTOWE (Zgodne ze screenshotem)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      decoration: InputDecoration(
                        icon: const Icon(Icons.edit, color: AppColors.textGrey),
                        hintText: "Napisz, co Cię spotkało...",
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: AppColors.primaryBlue,
                          ),
                          onPressed: _handleSend,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 3. SEKCJA "TWÓJ NASTRÓJ" (Przywrócona!)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Twój nastrój",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _selectedCategory,
                        style: TextStyle(
                          color: _getCategoryColor(_selectedCategory),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // 4. CHIPSY (KATEGORIE)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((category) {
                        final bool isActive = _selectedCategory == category;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategory = category),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.textDark
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: isActive
                                  ? null
                                  : Border.all(color: Colors.grey.shade200),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isActive
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
                  const SizedBox(height: 30),

                  // 5. SEKCJA "TWOJE OSTATNIE WPISY"
                  const Text(
                    "Twoje ostatnie wpisy",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),

                  FutureBuilder<List<MoodEntry>>(
                    future: _entriesFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text("Brak wpisów. Napisz coś powyżej!"),
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
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(entry: entry),
                                  ),
                                ).then((_) => refreshEntries());
                              },
                              child: _buildMoodCard(entry),
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

  Widget _buildMoodCard(MoodEntry entry) {
    final color = _getCategoryColor(entry.category);
    final icon = _getCategoryIcon(entry.category);
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                child: Icon(icon, color: Colors.white),
              ),
              Text(
                DateFormat('dd MMM, HH:mm').format(entry.date),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- EKRAN CZATU ---
class ChatScreen extends StatefulWidget {
  final MoodEntry entry;
  const ChatScreen({super.key, required this.entry});

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

    String newConversation = _messages
        .map((m) => "${m['role'] == 'user' ? 'User' : 'AI'}: ${m['text']}")
        .join("|");
    String mainText = _currentEntry.text == "Rozmowa z asystentem"
        ? userText
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
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
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Asystent",
                  style: TextStyle(color: AppColors.textDark, fontSize: 16),
                ),
                Text(
                  appSettings.isAiFemale ? "Online (K)" : "Online (M)",
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textDark),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: AppColors.primaryBlue),
              child: Text(
                'Ustawienia',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              title: const Text("Rozmiar czcionki"),
              subtitle: Slider(
                value: appSettings.fontSize,
                min: 10,
                max: 24,
                divisions: 7,
                label: appSettings.fontSize.round().toString(),
                onChanged: (val) => appSettings.setFontSize(val),
              ),
            ),
            SwitchListTile(
              title: const Text("Żeński głos AI"),
              value: appSettings.isAiFemale,
              onChanged: (val) => appSettings.toggleGender(val),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppColors.chatBubbleUser
                          : AppColors.chatBubbleAI,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? const Radius.circular(0) : null,
                        bottomLeft: !isUser ? const Radius.circular(0) : null,
                      ),
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Asystent pisze...",
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.grey),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: "Napisz wiadomość...",
                        border: InputBorder.none,
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.mic, color: Colors.grey),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primaryBlue),
                    onPressed: _sendMessage,
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
      style: const TextStyle(fontSize: 24, color: AppColors.textGrey),
    ),
  );
}
