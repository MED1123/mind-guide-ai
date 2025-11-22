import 'package:flutter/material.dart';
import '../Services/database_service.dart';
import '../models/mood_entry.dart';
import '../main.dart'; // Dostęp do AppColors, AppSettings
import '../widgets/mood_card.dart'; // Dostęp do MoodCard

// --- 7. EKRAN GŁÓWNY (HOME) ---
class HomeScreenUI extends StatefulWidget {
  final Function(MoodEntry) onOpenChat;
  final VoidCallback? onGoToCalendar;
  final Function(MoodEntry, bool)? onPostCreated;

  const HomeScreenUI({
    super.key,
    this.onOpenChat = _defaultOpenChat,
    this.onGoToCalendar,
    this.onPostCreated,
  });

  static void _defaultOpenChat(MoodEntry e) {}

  @override
  // ZMIANA: Odwołujemy się do publicznej klasy stanu
  State<HomeScreenUI> createState() => HomeScreenUIState();
}

// ZMIANA: Usunięto "_" z nazwy klasy, aby była publiczna
class HomeScreenUIState extends State<HomeScreenUI> {
  final TextEditingController _textController = TextEditingController();
  String? _selectedCategory;
  bool _wantAI = false;

  final List<String> _categories = [
    "Jestem spokojny 😌",
    "Jestem radosny 😃",
    "Jestem zestresowany 😫",
    "Jestem smutny 😔",
    "Jestem zmęczony 😴",
    "Jestem zły 😡",
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

  bool _isPositiveMood(String category) {
    final lower = category.toLowerCase();
    return lower.contains("radosny") || lower.contains("spokojny");
  }

  String _getFeelingWord(String fullCategory) {
    List<String> parts = fullCategory.split(' ');
    if (parts.length >= 2) return parts[1];
    return "tak";
  }

  String _getHintText() {
    if (_selectedCategory == null) return "";
    if (_isPositiveMood(_selectedCategory!)) {
      return "To wspaniale! Wpisz do dziennika, jak minął Ci dzień 😁";
    }
    return "Dlaczego czujesz się ${_getFeelingWord(_selectedCategory!)}?\nNasz asystent AI chętnie Ci pomoże...";
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _wantAI = !_isPositiveMood(category);
    });
  }

  void _handleSend() async {
    if (_textController.text.isEmpty || _selectedCategory == null) return;

    String conversationInit = _wantAI ? "User: ${_textController.text}|" : "";

    final newEntry = MoodEntry(
      date: DateTime.now(),
      text: _textController.text,
      moodRating: 3.0,
      category: _selectedCategory!,
      aiAnalysis: "",
      conversation: conversationInit,
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

    refreshEntries();

    bool userWantedAI = _wantAI;

    _textController.clear();
    setState(() {
      _selectedCategory = null;
      _wantAI = false;
    });
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Zapisano wpis!")));

    if (widget.onPostCreated != null) {
      widget.onPostCreated!(entryWithId, userWantedAI);
    }
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
                  const SizedBox(height: 10),
                  Text(
                    "Jak się dzisiaj czujesz?",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 32,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    children: _categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return GestureDetector(
                        onTap: () => _onCategorySelected(category),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryBlue
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryBlue
                                  : Colors.grey.shade200,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primaryBlue.withOpacity(
                                        0.3,
                                      ),
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
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: _selectedCategory == null
                        ? const SizedBox.shrink()
                        : Column(
                            children: [
                              const SizedBox(height: 32),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: _textController,
                                      maxLines: 4,
                                      minLines: 2,
                                      decoration: InputDecoration(
                                        hintText: _getHintText(),
                                        hintStyle: TextStyle(
                                          color: AppColors.textGrey.withOpacity(
                                            0.5,
                                          ),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(
                                          20,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 16,
                                        bottom: 8,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.image_outlined,
                                            color: AppColors.textGrey,
                                          ),
                                          onPressed: () {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Dodawanie zdjęć - wkrótce!",
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Czy chcesz uruchomić asystenta AI?",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildChoiceBtn(
                                          "Nie",
                                          !_wantAI,
                                          () => setState(() => _wantAI = false),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildChoiceBtn(
                                          "Tak",
                                          _wantAI,
                                          () => setState(() => _wantAI = true),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryBlue,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  onPressed: _handleSend,
                                  child: const Text(
                                    "Zapisz wpis",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 40),

                  const Text(
                    "Twoje ostatnie wpisy",
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

                      final allEntries = snapshot.data!;
                      final displayEntries = allEntries.take(4).toList();
                      final showMoreButton = allEntries.length > 4;

                      return Column(
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: displayEntries.length,
                            itemBuilder: (context, index) {
                              final entry = displayEntries[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: MoodCard(
                                  entry: entry,
                                  onTap: () =>
                                      widget.onOpenChat(entry), // Pop-up
                                ),
                              );
                            },
                          ),
                          if (showMoreButton)
                            TextButton(
                              onPressed: widget.onGoToCalendar,
                              child: const Text(
                                "Zobacz wszystkie wpisy",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
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

  Widget _buildChoiceBtn(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.primaryBlue : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textGrey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
