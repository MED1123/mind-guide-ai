import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:intl/intl.dart';

import '../Services/database_service.dart';
import '../Services/gpt_service.dart';
import '../Services/tts_service.dart';
import '../Services/translation_service.dart'; // Import
import '../models/mood_entry.dart';
import '../main.dart';
import '../widgets/animated_button.dart';

// --- WIADOMOŚĆ PRZESUWANA ---
class SlidableMessage extends StatefulWidget {
  final Widget child;
  final DateTime? time;
  final bool isUser;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SlidableMessage({
    super.key,
    required this.child,
    this.time,
    required this.isUser,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<SlidableMessage> createState() => _SlidableMessageState();
}

class _SlidableMessageState extends State<SlidableMessage>
    with TickerProviderStateMixin {
  double _dragOffset = 0.0;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  final double _maxDrag = 80.0;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideController.addListener(() {
      setState(() {
        _dragOffset = _slideAnimation.value;
      });
    });

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _runResetAnimation() {
    _slideAnimation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));
    _slideController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = widget.time != null
        ? DateFormat('HH:mm').format(widget.time!)
        : "";

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (_slideController.isAnimating) _slideController.stop();
        
        double delta = details.delta.dx;
        
        if (widget.isUser) {
           if (delta < 0 || _dragOffset < 0) {
             setState(() {
               _dragOffset += delta;
               if (_dragOffset < -_maxDrag) {
                 _dragOffset = -_maxDrag + (delta * 0.1);
               }
               if (_dragOffset > 0) _dragOffset = 0;
             });
           }
        } 
        else {
           if (delta > 0 || _dragOffset > 0) {
             setState(() {
               _dragOffset += delta;
               if (_dragOffset > _maxDrag) {
                  _dragOffset = _maxDrag + (delta * 0.1);
               }
               if (_dragOffset < 0) _dragOffset = 0;
             });
           }
        }
      },
      onHorizontalDragEnd: (details) {
        _runResetAnimation();
      },
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) => _scaleController.reverse(),
      onTapCancel: () => _scaleController.reverse(),
      onTap: widget.onTap,
      onLongPress: () async {
        await _scaleController.forward();
        await Future.delayed(const Duration(milliseconds: 100));
        await _scaleController.reverse();
        widget.onLongPress?.call();
      },
      child: Stack(
        alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          if (widget.isUser && _dragOffset < -5)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: _maxDrag,
              child: Center(
                child: Opacity(
                  opacity: (-_dragOffset / 40.0).clamp(0.0, 1.0),
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            
          if (!widget.isUser && _dragOffset > 5)
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: _maxDrag,
              child: Center(
                child: Opacity(
                  opacity: (_dragOffset / 40.0).clamp(0.0, 1.0),
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

// --- EKRAN CZATU ---
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

  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  late MoodEntry _currentEntry;

  final ImagePicker _picker = ImagePicker();
  final TtsService _ttsService = TtsService();

  bool _showSendButton = false;
  bool _isSoundEnabled = false;

  List<String> _tempChatImages = [];

  @override
  void initState() {
    super.initState();
    _currentEntry = widget.entry;
    _loadMessagesFromEntry();

    _ttsService.init();

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
    _ttsService.stop();
    super.dispose();
  }

  // --- METODY POMOCNICZE ---

  void _showPersonaSelector() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          TranslationService.tr('choose_personality'),
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.face, color: Colors.white),
              ),
              title: Text(
                TranslationService.tr('assistant'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(TranslationService.tr('male_voice')),
              trailing: !appSettings.isAiFemale
                  ? const Icon(Icons.check_circle, color: AppColors.primaryBlue)
                  : null,
              onTap: () {
                if (appSettings.isAiFemale) {
                  appSettings.toggleGender(false);
                }
                Navigator.pop(ctx);
              },
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.pinkAccent,
                child: Icon(Icons.face_3, color: Colors.white),
              ),
              title: Text(
                TranslationService.tr('assistant_female'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(TranslationService.tr('female_voice')),
              trailing: appSettings.isAiFemale
                  ? const Icon(Icons.check_circle, color: Colors.pinkAccent)
                  : null,
              onTap: () {
                if (!appSettings.isAiFemale) {
                  appSettings.toggleGender(true);
                  // USUNIĘTO WYMUSZONE POWITANIE
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(String path) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _attachImageFromHistory(String path) {
    if (_tempChatImages.contains(path)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("To zdjęcie jest już załączone"),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _tempChatImages.add(path);
      _showSendButton = true;
    });

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Załączono zdjęcie do wiadomości"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _toggleSound() {
    HapticFeedback.selectionClick();
    setState(() {
      _isSoundEnabled = !_isSoundEnabled;
    });

    if (!_isSoundEnabled) {
      _ttsService.stop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Włączono czytanie głosowe"),
          duration: Duration(seconds: 2),
        ),
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

  void _showMessageOptions(int index) {
    final msg = _messages[index];
    if (!msg['role'].startsWith('user')) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            if (msg['role'] == 'user')
              ListTile(
                leading: const Icon(Icons.edit, color: AppColors.primaryBlue),
                title: Text(TranslationService.tr('edit_message')),
                onTap: () {
                  Navigator.pop(ctx);
                  _editMessageDialog(index);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(TranslationService.tr('delete_message'), style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteMessage(index);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _editMessageDialog(int index) {
    final msg = _messages[index];
    final TextEditingController editController =
        TextEditingController(text: msg['text']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(TranslationService.tr('edit_message')),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Wpisz treść...",
          ),
          minLines: 1,
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(TranslationService.tr('cancel')),
          ),
          TextButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                setState(() {
                  _messages[index]['text'] = editController.text.trim();
                });
                _saveConversation();
                Navigator.pop(ctx);
              }
            },
            child: Text(TranslationService.tr('save')),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(int index) {
    setState(() {
      _messages.removeAt(index);
    });
    _saveConversation();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Wiadomość usunięta"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // --- LOGIKA CZATU ---
  void _loadMessagesFromEntry() {
    _messages.clear();
    final defaultTime = widget.entry.date;

    if (_currentEntry.conversation.isNotEmpty) {
      final parts = _currentEntry.conversation.split('|');
      for (var part in parts) {
        if (part.startsWith("User: ")) {
          String content = part.substring(6);
          if (content.startsWith("[IMG:")) {
            String path = content.substring(5, content.length - 1);
            _messages.add({
              "role": "user_image",
              "path": path,
              "time": defaultTime,
            });
          } else {
            _messages.add({
              "role": "user",
              "text": content,
              "time": defaultTime,
            });
          }
        } else if (part.startsWith("AI: ")) {
          _messages.add({
            "role": "ai",
            "text": part.substring(4),
            "time": defaultTime,
          });
        }
      }
    } else if (_currentEntry.text.isNotEmpty) {
      _messages.add({
        "role": "user",
        "text": _currentEntry.text,
        "time": defaultTime,
      });
    }

    if (_currentEntry.conversation.isEmpty &&
        _currentEntry.imagePaths.isNotEmpty) {
      for (var img in _currentEntry.imagePaths) {
        bool exists = _messages.any(
          (m) => m['role'] == 'user_image' && m['path'] == img,
        );
        if (!exists) {
          _messages.insert(0, {
            "role": "user_image",
            "path": img,
            "time": defaultTime,
          });
        }
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
        appSettings.locale.languageCode, // <--- New Param
        imagePaths: imagesToSend,
      );

      if (!mounted) return;
      setState(() {
        _messages.add({
          "role": "ai",
          "text": aiResponse,
          "time": DateTime.now(),
        });
      });

      if (_isSoundEnabled) {
        _ttsService.speak(aiResponse);
      }

      _saveConversation();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Problem z połączeniem.")));
    } finally {
      if (mounted) setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  void _sendMessage() async {
    if (_inputController.text.trim().isEmpty && _tempChatImages.isEmpty) return;

    _ttsService.stop();
    HapticFeedback.lightImpact();

    final userText = _inputController.text.trim();
    List<String> imagesToSend = List.from(_tempChatImages);
    final now = DateTime.now();

    setState(() {
      for (var path in imagesToSend) {
        _messages.add({"role": "user_image", "path": path, "time": now});
      }
      if (userText.isNotEmpty) {
        _messages.add({"role": "user", "text": userText, "time": now});
      }
      _isTyping = true;

      // Dodajemy tylko unikalne zdjęcia do historii wpisu
      List<String> newImagePaths = List.from(_currentEntry.imagePaths);
      for (var path in imagesToSend) {
        if (!newImagePaths.contains(path)) {
          newImagePaths.add(path);
        }
      }
      _currentEntry.imagePaths = newImagePaths;

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
        appSettings.locale.languageCode, // <--- New Param
        imagePaths: _currentEntry.imagePaths,
      );

      if (!mounted) return;
      setState(() {
        _messages.add({
          "role": "ai",
          "text": aiResponse,
          "time": DateTime.now(),
        });
      });

      if (_isSoundEnabled) {
        _ttsService.speak(aiResponse);
      }

      _saveConversation();
    } catch (e) {
      if (mounted)
        setState(() {
          _messages.add({
            "role": "ai",
            "text": "Wystąpił błąd połączenia.",
            "time": DateTime.now(),
          });
        });
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
        title: Text(
          TranslationService.tr('manage_chat'),
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
                child: Text(
                  TranslationService.tr('clear_chat'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Historia rozmowy wyczyszczona")),
      );
      widget.onGoToCalendar?.call();
    }
  }

  void _deleteEntireEntry() async {
    if (_currentEntry.id != null) {
      await DatabaseService.instance.deleteEntry(_currentEntry.id!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Wpis został usunięty")));
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
            // NAGŁÓWEK Z WYBOREM OSOBOWOŚCI
            title: GestureDetector(
              onTap: _showPersonaSelector,
              child: Row(
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
                        appSettings.isAiFemale
                            ? "Asystentka AI"
                            : "Asystent AI",
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                        children: [
                          SwitchListTile(
                            // ZMIANA: Skrócona nazwa, mniejsza czcionka, jedna linia
                            title: const Text(
                              "Tryb ciemny",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                              TranslationService.tr('font_size'),
                              // ZMIANA: Mniejsza czcionka
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
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
                                  TranslationService.tr('small'),
                                  12.0,
                                  () => appSettings.setFontSizeSmall(),
                                ),
                                const SizedBox(width: 10),
                                _buildFontSizeOption(
                                  TranslationService.tr('medium'),
                                  14.0,
                                  () => appSettings.setFontSizeMedium(),
                                ),
                                const SizedBox(width: 10),
                                _buildFontSizeOption(
                                  TranslationService.tr('large'),
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
                            // ZMIANA: Zmiana tekstu na krótszy, mniejsza czcionka, jedna linia
                            title: Text(
                              TranslationService.tr('chat_options'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: _showClearOrDeleteDialog,
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
                                if (_currentEntry.imagePaths.isEmpty)
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                  )
                                else
                                  SizedBox(
                                    height: 100,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount:
                                          _currentEntry.imagePaths.length,
                                      separatorBuilder: (ctx, i) =>
                                          const SizedBox(width: 8),
                                      itemBuilder: (context, index) {
                                        final path =
                                            _currentEntry.imagePaths[index];
                                        return GestureDetector(
                                          onTap: () => _showFullImage(path),
                                          onLongPress: () =>
                                              _attachImageFromHistory(path),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Image.file(
                                              File(path),
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder: (c, o, s) =>
                                                  Container(
                                                    width: 100,
                                                    height: 100,
                                                    color: Colors.grey,
                                                    child: const Icon(
                                                      Icons.broken_image,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                      child: SlidableMessage(
                        isUser: isUser,
                        time: msg['time'] as DateTime?,
                        onLongPress: () {
                          if (isUser) {
                            HapticFeedback.mediumImpact();
                            _showMessageOptions(index);
                          }
                        },
                        onTap: () {
                          if (msg['role'] == 'user_image') {
                            _showFullImage(msg['path']!);
                          }
                        },
                        child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: msg['role'] == 'user_image'
                                ? const EdgeInsets.all(4)
                                : const EdgeInsets.all(16),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (msg['role'] == 'user_image')
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      File(msg['path']!),
                                      width: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                else
                                  Text(
                                    msg['text']!,
                                    // Ta część nadal reaguje na suwak
                                    style: TextStyle(
                                      fontSize: appSettings.fontSize,
                                      color: (isUser || isDark && !isUser)
                                          ? Colors.white
                                          : AppColors.textDark,
                                      height: 1.4,
                                    ),
                                  ),
                              ],
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
                            onTap: _toggleSound,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: _isSoundEnabled
                                    ? AppColors.primaryBlue
                                    : (isDark
                                          ? const Color(0xFF2C2C2C)
                                          : Colors.grey.shade200),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isSoundEnabled
                                    ? Icons.volume_up
                                    : Icons.volume_off,
                                color: _isSoundEnabled
                                    ? Colors.white
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
                                  hintText: TranslationService.tr('type_message'),
                                  hintStyle: TextStyle(
                                    color: inputIconColor,
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.all(12),
                                ),
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


