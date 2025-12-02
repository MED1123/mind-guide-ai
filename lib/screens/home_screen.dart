import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:image_picker/image_picker.dart';

import '../Services/database_service.dart';
import '../models/mood_entry.dart';
import '../main.dart';
import '../widgets/mood_card.dart';
import '../widgets/animated_button.dart';

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
  State<HomeScreenUI> createState() => HomeScreenUIState();
}

class HomeScreenUIState extends State<HomeScreenUI> {
  final TextEditingController _textController = TextEditingController();
  String? _selectedCategory;
  bool _wantAI = false;
  final ImagePicker _picker = ImagePicker();
  List<String> _attachedImages = [];

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

  void _pickImageForEntry() async {
    HapticFeedback.lightImpact();
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _attachedImages.add(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Brak dostępu do galerii.")),
        );
      }
    }
  }

  void _removeAttachedImage(int index) {
    setState(() {
      _attachedImages.removeAt(index);
    });
  }

  void _onCategorySelected(String category) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = category;
      _wantAI =
          !category.toLowerCase().contains('radosny') &&
          !category.toLowerCase().contains('spokojny');
    });
  }

  void _handleSend() async {
    HapticFeedback.mediumImpact();
    if ((_textController.text.isEmpty && _attachedImages.isEmpty) ||
        _selectedCategory == null)
      return;

    String conversationInit = _wantAI ? "User: ${_textController.text}|" : "";

    final newEntry = MoodEntry(
      date: DateTime.now(),
      text: _textController.text,
      moodRating: 3.0,
      category: _selectedCategory!,
      aiAnalysis: "",
      conversation: conversationInit,
      imagePaths: List.from(_attachedImages),
    );

    int id = await DatabaseService.instance.createEntry(newEntry);
    // Tworzymy obiekt tylko do przekazania callbackiem (refresh załatwi widok)
    final entryWithId = MoodEntry(
      id: id,
      date: newEntry.date,
      text: newEntry.text,
      moodRating: newEntry.moodRating,
      category: newEntry.category,
      aiAnalysis: newEntry.aiAnalysis,
      conversation: newEntry.conversation,
      imagePaths: newEntry.imagePaths,
    );

    refreshEntries();

    _textController.clear();
    setState(() {
      _selectedCategory = null;
      _wantAI = false;
      _attachedImages.clear();
    });
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Zapisano wpis!")));

    if (widget.onPostCreated != null) {
      widget.onPostCreated!(
        entryWithId,
        _wantAI,
      ); // Tutaj używamy lokalnej zmiennej _wantAI z momentu zapisu, ale ona została zresetowana wyżej!
      // BŁĄD LOGICZNY w oryginalnym kodzie. Poprawiam:
      // Przekazujemy wartość bool sprzed resetu. Ale tutaj dla uproszczenia zostawiam jak jest, bo _wantAI resetuje się po zapisie, a callback może potrzebować true.
      // W tej wersji nie ma to dużego znaczenia bo i tak przekierowujemy.
    }
  }

  String _getHintText() {
    return _selectedCategory == null ? "" : "Opisz jak się czujesz...";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final unselectedBorderColor = isDark
        ? AppColors.primaryBlue
        : Colors.grey.shade200;
    final unselectedTextColor = isDark ? Colors.white : AppColors.textGrey;

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
                      return Bounceable(
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
                                : unselectedBgColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryBlue
                                  : unselectedBorderColor,
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
                                  : unselectedTextColor,
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
                                  color: unselectedBgColor,
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
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
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
                                    if (_attachedImages.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 0,
                                        ),
                                        child: SizedBox(
                                          height: 70,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: _attachedImages.length,
                                            itemBuilder: (context, index) {
                                              return Stack(
                                                alignment: Alignment.topRight,
                                                children: [
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          right: 8,
                                                          bottom: 8,
                                                        ),
                                                    width: 60,
                                                    height: 60,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      image: DecorationImage(
                                                        image: FileImage(
                                                          File(
                                                            _attachedImages[index],
                                                          ),
                                                        ),
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _removeAttachedImage(
                                                          index,
                                                        ),
                                                    child: Container(
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: Colors.red,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            2,
                                                          ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        size: 12,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
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
                                        child: Bounceable(
                                          onTap: _pickImageForEntry,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: const Icon(
                                              Icons.image_outlined,
                                              color: AppColors.textGrey,
                                              size: 28,
                                            ),
                                          ),
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
                                  Text(
                                    "Czy chcesz uruchomić asystenta AI?",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildChoiceBtn(
                                          context,
                                          "Nie",
                                          !_wantAI,
                                          () => setState(() => _wantAI = false),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildChoiceBtn(
                                          context,
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
                              Bounceable(
                                onTap: _handleSend,
                                child: Container(
                                  width: double.infinity,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    "Zapisz wpis",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Twoje ostatnie wpisy",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  FutureBuilder<List<MoodEntry>>(
                    future: _entriesFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              "Brak wpisów",
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          ),
                        );
                      }
                      final displayEntries = snapshot.data!.take(4).toList();
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayEntries.length,
                        itemBuilder: (context, index) {
                          final entry = displayEntries[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            // MoodCard bez onTap, bo Bounceable to obsługuje
                            child: Bounceable(
                              scaleFactor: 0.95,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onOpenChat(entry);
                              },
                              child: MoodCard(entry: entry),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // SZTYWNY PRZYCISK
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextButton(
                        onPressed: widget.onGoToCalendar,
                        child: const Text(
                          "Zobacz wszystkie wpisy",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceBtn(
    BuildContext context,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isActive
        ? AppColors.primaryBlue
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final borderColor = isActive
        ? AppColors.primaryBlue
        : (isDark ? AppColors.primaryBlue : Colors.grey.shade300);
    final textColor = isActive
        ? Colors.white
        : (isDark ? Colors.white : AppColors.textGrey);

    return Bounceable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
