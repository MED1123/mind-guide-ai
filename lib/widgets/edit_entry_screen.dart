import 'package:flutter/material.dart';
import '../Services/database_service.dart';
import '../models/mood_entry.dart';
import '../main.dart'; // Aby uzyskać dostęp do AppColors

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
    // Jeśli rozmowa już istnieje, domyślnie włączamy AI
    _wantAI = widget.entry.conversation.isNotEmpty;
  }

  void _saveChanges() async {
    if (_textController.text.isEmpty) return;

    // Logika AI:
    String conversationData = widget.entry.conversation;

    if (_wantAI) {
      // Jeśli użytkownik chce AI, a rozmowa jest pusta -> Inicjujemy
      if (conversationData.isEmpty) {
        conversationData = "User: ${_textController.text}|";
      }
      // Jeśli rozmowa już była, zostawiamy ją (asystent zobaczy nową treść przy ewentualnym odświeżeniu promptu,
      // choć w tym prostym modelu historia jest w conversation.
      // Można tu ewentualnie wyczyścić conversation, żeby AI odniosło się do nowej treści,
      // ale bezpieczniej zostawić historię).
    } else {
      // Jeśli użytkownik wyłączył AI -> Czyścimy rozmowę?
      // Decyzja: Tak, wyłączenie asystenta "resetuje" tryb czatu dla tego wpisu.
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

    // Jeśli użytkownik włączył AI, zwracamy ten obiekt, żeby MainAppScaffold wiedział, że ma otworzyć czat
    if (_wantAI) {
      Navigator.pop(context, updatedEntry);
    } else {
      Navigator.pop(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(title: const Text("Edycja wpisu")),
      body: SingleChildScrollView(
        // Dodano ScrollView na wypadek małych ekranów
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Edytuj treść:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
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
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Zawsze pokazujemy opcję włączenia/wyłączenia AI
            const Text(
              "Pomoc Asystenta AI",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  child: GestureDetector(
                    onTap: () => setState(() => _wantAI = false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !_wantAI ? AppColors.primaryBlue : Colors.white,
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
                  child: GestureDetector(
                    onTap: () => setState(() => _wantAI = true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _wantAI ? AppColors.primaryBlue : Colors.white,
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

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _saveChanges,
                child: const Text(
                  "Zapisz zmiany",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
