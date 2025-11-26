import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Services/database_service.dart';
import '../Services/gpt_service.dart';
import '../models/mood_entry.dart';
import '../main.dart';
import '../widgets/animated_button.dart';

// --- EKRAN CZATU ---
class ChatScreen extends StatefulWidget {
  final MoodEntry entry;
  final VoidCallback onBack;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messages.length == 1 &&
          _messages[0]['role'] == 'user' &&
          !_currentEntry.conversation.contains('AI:')) {
        _triggerAutoReply();
      }
    });
  }

  void _loadMessagesFromEntry() {
    _messages.clear();

    if (_currentEntry.conversation.isNotEmpty) {
      final parts = _currentEntry.conversation.split('|');
      for (var part in parts) {
        if (part.startsWith("User: "))
          _messages.add({"role": "user", "text": part.substring(6)});
        else if (part.startsWith("AI: "))
          _messages.add({"role": "ai", "text": part.substring(4)});
      }
    } else if (_currentEntry.text.isNotEmpty) {
      _messages.add({"role": "user", "text": _currentEntry.text});
    }
  }

  void _triggerAutoReply() async {
    if (_messages.isEmpty) return;

    setState(() {
      _isTyping = true;
    });
    _scrollToBottom();

    String historyStr = "User: ${_messages.last['text']}";
    final userInput = _messages.last['text']!;

    final aiResponse = await GptService.chatWithAI(
      userInput,
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
    if (_inputController.text.trim().isEmpty || _isTyping) return;
    HapticFeedback.lightImpact();
    final userText = _inputController.text;

    setState(() {
      _messages.add({"role": "user", "text": userText});
      _inputController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    String lastUserMessage = userText;

    String conversationHistory = _messages
        .sublist(0, _messages.length - 1)
        .map((m) => "${m['role'] == 'user' ? 'User' : 'AI'}: ${m['text']}")
        .join("|");

    final aiResponse = await GptService.chatWithAI(
      lastUserMessage,
      conversationHistory,
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

    String mainText = _currentEntry.text;
    if (mainText.isEmpty && _messages.isNotEmpty) {
      mainText = _messages[0]['text']!;
    }

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

  void _clearConversation() async {
    final updatedEntry = MoodEntry(
      id: _currentEntry.id,
      date: _currentEntry.date,
      text: _currentEntry.text,
      moodRating: _currentEntry.moodRating,
      category: _currentEntry.category,
      aiAnalysis: "",
      conversation: "",
    );

    await DatabaseService.instance.updateEntry(updatedEntry);

    setState(() {
      _currentEntry = updatedEntry;
      _loadMessagesFromEntry();
    });

    if (mounted) Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Rozmowa wyczyszczona")));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: appSettings,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: Theme.of(context).iconTheme.color,
              ),
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
                    Text(
                      "Asystent AI",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
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
                  icon: Icon(Icons.settings, color: AppColors.textGrey),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
              ),
            ],
          ),
          endDrawer: Drawer(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      "Ustawienia",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                  const Divider(),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            title: const Text("Żeński głos AI"),
                            value: appSettings.isAiFemale,
                            activeColor: AppColors.primaryBlue,
                            onChanged: (val) {
                              appSettings.toggleGender(val);
                            },
                          ),

                          SwitchListTile(
                            title: const Text("Tryb Ciemny"),
                            value: appSettings.isDarkMode,
                            activeColor: AppColors.primaryBlue,
                            secondary: Icon(
                              appSettings.isDarkMode
                                  ? Icons.dark_mode
                                  : Icons.light_mode,
                            ),
                            onChanged: (val) {
                              appSettings.toggleTheme(val);
                            },
                          ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              "Wielkość czcionki",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Row(
                              children: [
                                _buildFontSizeOption(
                                  "Mała",
                                  12.0,
                                  () => appSettings.setFontSizeSmall(),
                                ),
                                const SizedBox(width: 10),
                                _buildFontSizeOption(
                                  "Średnia",
                                  14.0,
                                  () => appSettings.setFontSizeMedium(),
                                ),
                                const SizedBox(width: 10),
                                _buildFontSizeOption(
                                  "Duża",
                                  16.0,
                                  () => appSettings.setFontSizeLarge(),
                                ),
                              ],
                            ),
                          ),

                          const Divider(height: 40),

                          ListTile(
                            leading: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            title: const Text(
                              "Wyczyść rozmowę",
                              style: TextStyle(color: Colors.red),
                            ),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Wyczyścić rozmowę?"),
                                  content: const Text(
                                    "Twoje notatki pozostaną, ale historia czatu z AI zostanie usunięta.",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text("Anuluj"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _clearConversation();
                                      },
                                      child: const Text(
                                        "Wyczyść",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // PRZYWRÓCONA SEKCJA: Ostatnie Zdjęcia
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Twoje ostatnie zdjęcia",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black26
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  color: Colors.grey.shade400,
                                  size: 30,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "Brak ostatnich zdjęć",
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  // POPRAWKA: Zmniejszono padding dolny z 20 na 4
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
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
                              : (isDark
                                    ? AppColors.chatBubbleAIDark
                                    : AppColors.chatBubbleAI),
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
                            fontSize: appSettings.fontSize,
                            color: (isUser || isDark && !isUser)
                                ? Colors.white
                                : AppColors.textDark,
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
                // POPRAWKA: Zmniejszono górny padding z 10 na 0
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2C2C2C)
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.transparent,
                            ),
                          ),
                          child: TextField(
                            controller: _inputController,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: "Napisz wiadomość...",
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.grey
                                    : Colors.grey.shade600,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedPressButton(
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
      },
    );
  }

  Widget _buildFontSizeOption(
    String label,
    double sizeValue,
    VoidCallback onTap,
  ) {
    final isSelected = (appSettings.fontSize - sizeValue).abs() < 0.01;

    final isDark = appSettings.isDarkMode;
    final bgColor = isSelected
        ? AppColors.primaryBlue
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade200);

    final textColor = isSelected
        ? Colors.white
        : (isDark ? Colors.white70 : Colors.black87);

    return Expanded(
      child: AnimatedPressButton(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
