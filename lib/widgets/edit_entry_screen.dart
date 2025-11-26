import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../Services/database_service.dart';
import '../models/mood_entry.dart';
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

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.entry.text);
    _wantAI = widget.entry.conversation.isNotEmpty;
  }

  void _saveChanges() async {
    if (_textController.text.isEmpty) return;

    String conversationData = widget.entry.conversation;

    if (_wantAI) {
      if (conversationData.isEmpty) {
        conversationData = "User: ${_textController.text}|";
      }
    } else {
      conversationData = "";
    }

    final updatedEntry = MoodEntry(
      id: widget.entry.id,
      date: widget.entry.date,
      text: _textController.text,
      moodRating: widget.entry.moodRating,
      category: widget.entry.category,
      aiAnalysis: widget.entry.aiAnalysis,
      conversation: conversationData,
    );

    await DatabaseService.instance.updateEntry(updatedEntry);

    if (!mounted) return;

    if (_wantAI) {
      Navigator.pop(context, updatedEntry);
    } else {
      Navigator.pop(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Poprawa #3: Pobieramy czy jest tryb ciemny
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final containerColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: backgroundColor, // Używamy koloru z motywu
      appBar: AppBar(
        title: const Text("Edycja wpisu"),
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Edytuj treść:",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: containerColor, // Ciemny kontener w trybie ciemnym
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _textController,
                    maxLines: 6,
                    style: TextStyle(color: textColor), // Kolor tekstu
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            Text(
              "Pomoc Asystenta AI",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              "Czy chcesz, aby asystent przeanalizował ten wpis?",
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
                          "Nie",
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
                          "Tak (Czat)",
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
                child: const Text(
                  "Zapisz zmiany",
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
