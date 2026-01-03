import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback
import 'package:image_picker/image_picker.dart'; // Galeria
import 'package:flutter_bounceable/flutter_bounceable.dart';

import '../Services/database_service.dart';
import '../Services/api_service.dart'; // Import
import '../models/mood_entry.dart';
import '../Services/translation_service.dart'; // Import
import '../main.dart';

// --- EKRAN EDYCJI ---
class EditEntryScreen extends StatefulWidget {
  final MoodEntry entry;
  const EditEntryScreen({super.key, required this.entry});

  @override
  State<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
  late TextEditingController _textController;
  bool _wantAI = false;

  // Obsługa zdjęć
  final ImagePicker _picker = ImagePicker();
  List<String> _currentImages = [];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.entry.text);
    _wantAI = widget.entry.conversation.isNotEmpty;
    // Kopiujemy listę zdjęć, aby móc ją edytować bez zmiany oryginału przed zapisem
    _currentImages = List.from(widget.entry.imagePaths);
  }

  // --- LOGIKA ZDJĘĆ ---
  void _pickImage() async {
    HapticFeedback.lightImpact();
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _currentImages.add(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Błąd galerii")));
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _currentImages.removeAt(index);
    });
  }

  void _showFullImage(String path) {
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

  // --- ZAPIS ---
  void _saveChanges() async {
    if (_textController.text.isEmpty && _currentImages.isEmpty) return;

    String conversationData = widget.entry.conversation;

    // Jeśli użytkownik włączył AI, a wcześniej go nie było, inicjujemy rozmowę
    if (_wantAI) {
      if (conversationData.isEmpty) {
        // Budujemy startowy kontekst.
        // Uwaga: ChatScreen sam sobie poradzi z wczytaniem zdjęć z imagePaths,
        // więc tutaj wystarczy zainicjować tekst, jeśli jest.
        if (_textController.text.isNotEmpty) {
          conversationData = "User: ${_textController.text}|";
        }
        // Jeśli sam obrazek, ChatScreen to wykryje po pustym conversation i liście zdjęć.
      }
    } else {
      // Jeśli wyłączył AI, czyścimy historię (opcjonalne, zależy od preferencji)
      // conversationData = "";
    }

    final updatedEntry = MoodEntry(
      id: widget.entry.id,
      date: widget.entry.date,
      text: _textController.text,
      moodRating: widget.entry.moodRating,
      category: widget.entry.category,
      aiAnalysis: widget.entry.aiAnalysis,
      conversation: conversationData,
      imagePaths: _currentImages, // Zapisujemy zaktualizowaną listę zdjęć
    );

    await DatabaseService.instance.updateEntry(updatedEntry);

    // Sync with backend
    if (updatedEntry.backendId != null) {
      await ApiService().updateEntry(updatedEntry);
    } else {
      print("Warning: Edytowany wpis nie ma backendId, nie można zsynchronizować edycji.");
      // Optional: Try to find by content? Or just let it be. 
      // Ideally we should enforce backendId presence or creation.
    }

    if (!mounted) return;

    if (_wantAI) {
      // Przekazujemy zaktualizowany wpis do ChatScreen
      Navigator.pop(context, updatedEntry);
    } else {
      Navigator.pop(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final containerColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(TranslationService.tr('edit_entry_title')),
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TranslationService.tr('edit_content_label'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: TextField(
                controller: _textController,
                maxLines: 6,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  hintText: TranslationService.tr('your_entry_hint'),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // --- SEKCJA ZDJĘĆ ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  TranslationService.tr('attached_photos'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                // Przycisk dodawania zdjęcia
                Bounceable(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_a_photo,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_currentImages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    TranslationService.tr('no_photos'),
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _currentImages.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final path = _currentImages[index];
                    return Stack(
                      alignment: Alignment.topRight,
                      children: [
                        GestureDetector(
                          onTap: () => _showFullImage(path),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(path),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (c, o, s) => Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey,
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            const SizedBox(height: 30),

            Text(
              TranslationService.tr('ai_help_title'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              TranslationService.tr('ai_help_desc'),
              style: TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Bounceable(
                    onTap: () => setState(() => _wantAI = false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !_wantAI
                            ? AppColors.primaryBlue
                            : containerColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryBlue),
                      ),
                      child: Center(
                        child: Text(
                          TranslationService.tr('no'),
                          style: TextStyle(
                            color: !_wantAI ? Colors.white : AppColors.textGrey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Bounceable(
                    onTap: () => setState(() => _wantAI = true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _wantAI ? AppColors.primaryBlue : containerColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryBlue),
                      ),
                      child: Center(
                        child: Text(
                          TranslationService.tr('yes_chat'),
                          style: TextStyle(
                            color: _wantAI ? Colors.white : AppColors.textGrey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            Bounceable(
              onTap: _saveChanges,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  TranslationService.tr('save_changes'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
