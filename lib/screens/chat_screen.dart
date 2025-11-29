import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';

import '../Services/database_service.dart';
import '../Services/gpt_service.dart';
import '../models/mood_entry.dart';
import '../main.dart';
import '../widgets/animated_button.dart';

class ChatScreen extends StatefulWidget {
  final MoodEntry entry;
  final VoidCallback onBack;
  final VoidCallback? onGoToCalendar;

  const ChatScreen({
    super.key,
    required this.entry,
    required this.onBack,
    this.onGoToCalendar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  late MoodEntry _currentEntry;

  final ImagePicker _picker = ImagePicker();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _showSendButton = false;
  bool _speechInitialized = false;

  List<String> _tempChatImages = [];

  @override
  void initState() {
    super.initState();
    _currentEntry = widget.entry;
    _loadMessagesFromEntry();

    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      final hasImages = _tempChatImages.isNotEmpty;
      if (_showSendButton != (hasText || hasImages)) {
        setState(() {
          _showSendButton = hasText || hasImages;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messages.length == 1 &&
          _messages[0]['role'] == 'user' &&
          !_currentEntry.conversation.contains('AI:')) {
        _triggerAutoReply();
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureSpeechInitialized() async {
    if (_speechInitialized) return;

    _speech = stt.SpeechToText();
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      _speechInitialized = true;
    } catch (e) {
      // Ignoruj błąd inicjalizacji
    }
  }

  void _toggleListening() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }

    await _ensureSpeechInitialized();

    if (!_speechAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rozpoznawanie mowy niedostępne.")),
        );
      }
      return;
    }

    HapticFeedback.mediumImpact();

    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _inputController.text = result.recognizedWords;
            _inputController.selection = TextSelection.fromPosition(
              TextPosition(offset: _inputController.text.length),
            );
          });
        },
        localeId: "pl_PL",
      );
    }
  }

  void _pickMedia() async {
    HapticFeedback.lightImpact();
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );
      if (image != null) {
        setState(() {
          _tempChatImages.add(image.path);
          _showSendButton = true;
        });
      }
    } catch (e) {
      // Ignoruj błąd
    }
  }

  void _removeTempImage(int index) {
    setState(() {
      _tempChatImages.removeAt(index);
      if (_tempChatImages.isEmpty && _inputController.text.trim().isEmpty) {
        _showSendButton = false;
      }
    });
  }

  void _loadMessagesFromEntry() {
    _messages.clear();
    if (_currentEntry.conversation.isNotEmpty) {
      final parts = _currentEntry.conversation.split('|');
      for (var part in parts) {
        if (part.startsWith("User: ")) {
          String content = part.substring(6);
          if (content.startsWith("[IMG:")) {
            String path = content.substring(5, content.length - 1);
            _messages.add({"role": "user_image", "path": path});
          } else {
            _messages.add({"role": "user", "text": content});
          }
        } else if (part.startsWith("AI: ")) {
          _messages.add({"role": "ai", "text": part.substring(4)});
        }
      }
    } else if (_currentEntry.text.isNotEmpty) {
      _messages.add({"role": "user", "text": _currentEntry.text});
    }

    if (_currentEntry.conversation.isEmpty &&
        _currentEntry.imagePaths.isNotEmpty) {
      for (var img in _currentEntry.imagePaths) {
        _messages.insert(0, {"role": "user_image", "path": img});
      }
    }
  }

  void _triggerAutoReply() async {
    if (_messages.isEmpty) return;

    setState(() => _isTyping = true);
    _scrollToBottom();

    String userInputText = "";
    var lastUserMsg = _messages.last;

    if (lastUserMsg['role'] == 'user') {
      userInputText = lastUserMsg['text']!;
    } else if (lastUserMsg['role'] == 'user_image') {
      userInputText = "Przesyłam zdjęcie.";
    }

    String historyStr = "";
    if (_messages.length > 1) {
      historyStr = _messages
          .sublist(0, _messages.length - 1)
          .where((m) => m['text'] != null)
          .map((m) => "${m['role'] == 'user' ? 'User' : 'AI'}: ${m['text']}")
          .join("|");
    }

    List<String> imagesToSend = [];
    if (_currentEntry.imagePaths.isNotEmpty) {
      imagesToSend.addAll(_currentEntry.imagePaths);
    }

    try {
      final aiResponse = await GptService.chatWithAI(
        userInputText,
        historyStr,
        appSettings.isAiFemale,
        imagePaths: imagesToSend,
      );

      if (!mounted) return;
      setState(() {
        _messages.add({"role": "ai", "text": aiResponse});
      });
      _saveConversation();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Problem z połączeniem.")));
      }
    } finally {
      if (mounted) setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  void _sendMessage() async {
    if (_inputController.text.trim().isEmpty && _tempChatImages.isEmpty) return;
    HapticFeedback.lightImpact();

    final userText = _inputController.text;
    List<String> imagesToSend = List.from(_tempChatImages);

    setState(() {
      for (var path in imagesToSend) {
        _messages.add({"role": "user_image", "path": path});
      }
      if (userText.isNotEmpty) {
        _messages.add({"role": "user", "text": userText});
      }
      _isTyping = true;
      _tempChatImages.clear();
      _inputController.clear();
      _showSendButton = false;
    });
    _scrollToBottom();

    String prompt = userText.isEmpty ? "Przesłałem zdjęcie." : userText;

    int newItems = (userText.isNotEmpty ? 1 : 0) + imagesToSend.length;
    String history = "";

    if (_messages.length > newItems) {
      history = _messages
          .sublist(0, _messages.length - newItems)
          .where((m) => m['text'] != null)
          .map((m) => "${m['role'] == 'user' ? 'User' : 'AI'}: ${m['text']}")
          .join("|");
    }

    try {
      final aiResponse = await GptService.chatWithAI(
        prompt,
        history,
        appSettings.isAiFemale,
        imagePaths: imagesToSend,
      );

      if (!mounted) return;
      setState(() {
        _messages.add({"role": "ai", "text": aiResponse});
      });
      _saveConversation();
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({"role": "ai", "text": "Wystąpił błąd połączenia."});
        });
      }
    } finally {
      if (mounted) setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  void _saveConversation() async {
    String newConversation = _messages
        .map((m) {
          if (m['role'] == 'user') return "User: ${m['text']}";
          if (m['role'] == 'ai') return "AI: ${m['text']}";
          if (m['role'] == 'user_image') return "User: [IMG:${m['path']}]";
          return "";
        })
        .where((s) => s.isNotEmpty)
        .join("|");

    String mainText = _currentEntry.text;
    if (mainText.isEmpty && _messages.isNotEmpty) {
      var firstTxt = _messages.firstWhere(
        (m) => m['role'] == 'user' && m['text'] != null,
        orElse: () => {},
      );
      if (firstTxt.isNotEmpty) mainText = firstTxt['text']!;
    }

    final updatedEntry = MoodEntry(
      id: _currentEntry.id,
      date: _currentEntry.date,
      text: mainText,
      moodRating: _currentEntry.moodRating,
      category: _currentEntry.category,
      aiAnalysis: _currentEntry.aiAnalysis,
      conversation: newConversation,
      imagePaths: _currentEntry.imagePaths,
    );

    await DatabaseService.instance.updateEntry(updatedEntry);
    _currentEntry = updatedEntry;
  }

  void _showClearOrDeleteDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Zarządzanie rozmową",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.orangeAccent : Colors.orange,
                  side: BorderSide(
                    color: isDark ? Colors.orangeAccent : Colors.orange,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _clearConversationOnly();
                },
                child: const Text(
                  "Wyczyść rozmowę",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.red.withOpacity(0.2)
                      : Colors.red.shade100,
                  foregroundColor: isDark
                      ? Colors.redAccent
                      : Colors.red.shade900,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteEntireEntry();
                },
                child: const Text(
                  "Usuń cały wpis",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Anuluj",
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearConversationOnly() async {
    final updatedEntry = MoodEntry(
      id: _currentEntry.id,
      date: _currentEntry.date,
      text: _currentEntry.text,
      moodRating: _currentEntry.moodRating,
      category: _currentEntry.category,
      aiAnalysis: "",
      conversation: "",
      imagePaths: _currentEntry.imagePaths,
    );
    await DatabaseService.instance.updateEntry(updatedEntry);
    if (mounted) {
      Navigator.pop(context);
      widget.onGoToCalendar?.call();
    }
  }

  void _deleteEntireEntry() async {
    if (_currentEntry.id != null) {
      await DatabaseService.instance.deleteEntry(_currentEntry.id!);
      if (mounted) {
        Navigator.pop(context);
        widget.onGoToCalendar?.call();
      }
    }
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
    final inputBgColor = isDark
        ? const Color(0xFF2C2C2C)
        : Colors.grey.shade200;
    final inputIconColor = isDark ? Colors.grey : Colors.grey.shade600;

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
                    padding: const EdgeInsets.all(20),
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
                        children: [
                          SwitchListTile(
                            title: const Text("Żeński głos AI"),
                            value: appSettings.isAiFemale,
                            activeColor: AppColors.primaryBlue,
                            onChanged: (v) => appSettings.toggleGender(v),
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
                            onChanged: (v) => appSettings.toggleTheme(v),
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
                              Icons.edit_note,
                              color: AppColors.primaryBlue,
                            ),
                            title: const Text(
                              "Zarządzaj rozmową",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onTap: _showClearOrDeleteDialog,
                          ),
                        ],
                      ),
                    ),
                  ),
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
                ],
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg['role']!.startsWith('user');
                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: msg['role'] == 'user_image'
                            ? const EdgeInsets.all(4)
                            : const EdgeInsets.all(16),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? AppColors.chatBubbleUser
                              : (isDark
                                    ? AppColors.chatBubbleAIDark
                                    : AppColors.chatBubbleAI),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: msg['role'] == 'user_image'
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  File(msg['path']!),
                                  width: 200,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Text(
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
                  padding: const EdgeInsets.only(left: 24, bottom: 10),
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
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_tempChatImages.isNotEmpty)
                        Container(
                          height: 70,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _tempChatImages.length,
                            itemBuilder: (ctx, i) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(_tempChatImages[i]),
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: GestureDetector(
                                      onTap: () => _removeTempImage(i),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: const Icon(
                                          Icons.close,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Bounceable(
                            onTap: _pickMedia,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2C2C2C)
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.image_outlined,
                                color: AppColors.primaryBlue,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Bounceable(
                            onTap: _toggleListening,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: _isListening
                                    ? Colors.red.withOpacity(0.1)
                                    : inputBgColor,
                                shape: BoxShape.circle,
                                border: _isListening
                                    ? Border.all(color: Colors.red, width: 1.5)
                                    : null,
                              ),
                              child: Icon(
                                _isListening ? Icons.stop : Icons.mic_none,
                                color: _isListening
                                    ? Colors.red
                                    : AppColors.primaryBlue,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 0,
                              ),
                              decoration: BoxDecoration(
                                color: inputBgColor,
                                borderRadius: BorderRadius.circular(20),
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
                                  fontSize: 14,
                                ),
                                minLines: 1,
                                maxLines: 5,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: "Napisz wiadomość...",
                                  hintStyle: TextStyle(
                                    color: inputIconColor,
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                onChanged: (v) => setState(() {}),
                              ),
                            ),
                          ),
                          if (_showSendButton) ...[
                            const SizedBox(width: 8),
                            Bounceable(
                              onTap: _sendMessage,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 2),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ],
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
    return Expanded(
      child: AnimatedPressButton(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryBlue
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
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
