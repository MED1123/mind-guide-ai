import 'package:flutter/material.dart';
import '../Services/database_service.dart';
import '../Services/gpt_service.dart';
import '../models/mood_entry.dart';
import '../main.dart'; // Dostęp do AppColors, AppSettings

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
      // Automatyczna odpowiedź AI, jeśli to nowa konwersacja zainicjowana przez użytkownika
      if (_messages.length == 1 &&
          _messages[0]['role'] == 'user' &&
          !_currentEntry.conversation.contains('AI:')) {
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
    } else if (_currentEntry.text.isNotEmpty) {
      // POPRAWKA: Jeśli brak historii rozmowy, użyj treści wpisu jako pierwszej wiadomości
      _messages.add({"role": "user", "text": _currentEntry.text});
    }
  }

  void _triggerAutoReply() async {
    if (_messages.isEmpty) return;

    setState(() {
      _isTyping = true;
    });
    _scrollToBottom();

    // Budujemy historię: w tym przypadku to po prostu pierwsza wiadomość (treść wpisu)
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
    final userText = _inputController.text;

    setState(() {
      _messages.add({"role": "user", "text": userText});
      _inputController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    String lastUserMessage = userText;

    // Historia bez ostatniej wiadomości
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

    // Jeśli to pierwsza rozmowa, nie nadpisuj oryginalnego tekstu wpisu, chyba że był pusty
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
                        fontSize: appSettings.fontSize,
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
