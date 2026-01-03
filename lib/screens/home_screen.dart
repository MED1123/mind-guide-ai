import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:image_picker/image_picker.dart';

import '../Services/database_service.dart';
import '../Services/api_service.dart'; // Import serwisu API
import '../models/mood_entry.dart';
import '../main.dart';
import '../widgets/mood_card.dart';
import '../Services/translation_service.dart';
import 'dart:math';

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
  bool _wantAI = false;
  bool _tempIsAiFemale = false;


  final ImagePicker _picker = ImagePicker();
  List<String> _attachedImages = [];

  // --- KONFIGURACJA DANYCH ---
  final Map<String, Map<String, dynamic>> _moodCategories = {
    "Negatywne": {
      "color": AppColors.cardRed,
      "icon": Icons.sentiment_very_dissatisfied,
      "moods": [
        "zły",
        "zmęczony",
        "smutny",
        "zestresowany",
        "poirytowany",
        "przytłoczony",
        "zniechęcony",
        "rozczarowany",
        "zmartwiony",
        "samotny",
        "znudzony",
        "bezradny",
        "przestraszony",
        "zawiedziony",
      ],
    },
    "Pozytywne": {
      "color": Colors.green,
      "icon": Icons.sentiment_very_satisfied,
      "moods": [
        "spokojny",
        "radosny",
        "szczęśliwy",
        "zadowolony",
        "entuzjastyczny",
        "pełen energii",
        "optymistyczny",
        "wdzięczny",
        "rozluźniony",
        "pewny siebie",
        "dumny",
        "zainspirowany",
      ],
    },
    "Neutralne": {
      "color": Colors.amber,
      "icon": Icons.sentiment_neutral,
      "moods": [
        "obojętny",
        "zamyślony",
        "ciekawy",
        "niepewny",
        "zaskoczony",
        "nostalgiczny",
        "ostrożny",
      ],
    },
  };

  // Stan wyboru
  String? _selectedMainCategory; // np. "Negatywne"
  String? _selectedSpecificMood; // np. "zły"

  // Pozostałe zmienne
  late Future<List<MoodEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    refreshEntries();
    _tempIsAiFemale = appSettings.isAiFemale;
  }

  void refreshEntries() {
    setState(() {
      final userId = ApiService().currentUserId;
      if (userId != null) {
        _entriesFuture = DatabaseService.instance.readEntriesForUser(userId);
      } else {
        _entriesFuture = Future.value([]);
      }
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
           SnackBar(content: Text(TranslationService.tr('gallery_error'))),
        );
      }
    }
  }

  void _removeAttachedImage(int index) {
    setState(() {
      _attachedImages.removeAt(index);
    });
  }

  // Wybór głównej kategorii (Negatywne / Pozytywne / Neutralne)
  void _onMainCategoryTap(String category) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedMainCategory == category) {
        // Odznaczenie
        _selectedMainCategory = null;
        _selectedSpecificMood = null;
        _wantAI = false;
      } else {
        // Zaznaczenie nowej
        _selectedMainCategory = category;
        _selectedSpecificMood = null; // Reset konkretnego nastroju
      }
    });
  }

  // Wybór konkretnego nastroju (np. "zły")
  void _onSpecificMoodTap(String mood) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedSpecificMood == mood) {
        _selectedSpecificMood = null;
        _wantAI = false;
      } else {
        _selectedSpecificMood = mood;
        
        // Logika AI domyślnie wyłączona dla pozytywnych
        bool isPositive = _selectedMainCategory == "Pozytywne";
        _wantAI = !isPositive;
        
        _tempIsAiFemale = appSettings.isAiFemale;
      }
    });
  }

  void _handleSend() async {
    HapticFeedback.mediumImpact();
    if ((_textController.text.isEmpty && _attachedImages.isEmpty) ||
        _selectedSpecificMood == null)
      return;

    final currentUserId = ApiService().currentUserId;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(TranslationService.tr('login_needed'))),
      );
      return;
    }

    String conversationInit = _wantAI ? "User: ${_textController.text}|" : "";

    if (_wantAI) {
      appSettings.toggleGender(_tempIsAiFemale);
    }

    // Dodaję emoji do nazwy kategorii w bazie, dla zachowania spójności
    // lub po prostu zapisuję goły tekst. 
    // Wcześniej było np. "Jestem zły 😡". Teraz user wybiera "zły".
    // Możemy dodać emoji na podstawie głównej kategorii lub zostawić samo "zły".
    // Zostawiam samo + ewentualnie emoji głównej kategorii dla czytelności?
    // Decyzja: Zapisuję tak jak wybrał user + emoji z mapy jeśli chcemy, 
    // ale prościej zapisać po prostu string "zły".
    
    final newEntry = MoodEntry(
      date: DateTime.now(),
      text: _textController.text,
      moodRating: _calculateRating(_selectedMainCategory!),
      category: _selectedSpecificMood!, 
      aiAnalysis: "",
      conversation: conversationInit,
      imagePaths: List.from(_attachedImages),
      ownerId: currentUserId,
    );

    int localId = await DatabaseService.instance.createEntry(newEntry);
    int? backendId;

    try {
      backendId = await ApiService().createEntry(newEntry);
      if (backendId != null) {
        // Sync: Update local entry with backend ID
        await DatabaseService.instance.updateBackendId(localId, backendId);
        print("Zsynchonizowano ID: Local=$localId -> Backend=$backendId");
      }
    } catch (e) {
      print("Nie udało się zsynchronizować z serwerem: $e");
    }

    // Hack na odświeżenie listy z nowym ID
    final entryWithId = MoodEntry(
        id: localId, // LOCAL ID
        backendId: backendId, // BACKEND ID
        date: newEntry.date,
        text: newEntry.text,
        moodRating: newEntry.moodRating,
        category: newEntry.category,
        aiAnalysis: newEntry.aiAnalysis,
        conversation: newEntry.conversation,
        imagePaths: newEntry.imagePaths,
        ownerId: currentUserId);

    refreshEntries();

    bool userWantedAI = _wantAI;

    _textController.clear();
    setState(() {
      _selectedMainCategory = null;
      _selectedSpecificMood = null;
      _wantAI = false;
      _attachedImages.clear();
    });
    FocusScope.of(context).unfocus();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(TranslationService.tr('entry_saved'))));
    }

    if (widget.onPostCreated != null) {
      widget.onPostCreated!(entryWithId, userWantedAI);
    }
  }

  double _calculateRating(String mainCategory) {
    switch (mainCategory) {
      case "Pozytywne":
        return 5.0;
      case "Negatywne":
        return 1.0;
      default:
        return 3.0;
    }
  }

  // --- FUNKCJA TESTOWA (DEV ONLY) ---
  void _generateTestEntries() async {
    final userId = ApiService().currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(TranslationService.tr('login_needed'))),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(TranslationService.tr('generating')),
      ),
    );

    final random = Random();
    // Sztywne definicje, aby wykres wyglądał ładnie
    final testData = [
      // Dziś
      (0, "radosny", 4.5),
      (0, "spokojny", 4.0),
      // Wczoraj
      (1, "zmęczony", 2.5),
      (1, "zestresowany", 2.0),
      // 2 dni temu
      (2, "smutny", 2.0),
      // 3 dni temu
      (3, "zły", 1.5),
      (3, "zestresowany", 2.0),
      // 5 dni temu
      (5, "spokojny", 4.0),
      (5, "radosny", 5.0),
      // Tydzień temu
      (7, "radosny", 4.8),
    ];

    for (var data in testData) {
      final daysAgo = data.$1;
      final category = data.$2;
      final rating = data.$3;

      // Tworzymy datę wsteczną
      final date = DateTime.now().subtract(
        Duration(days: daysAgo, minutes: random.nextInt(100)),
      );

      final entry = MoodEntry(
        date: date,
        text: "Testowy wpis historyczny (sprzed $daysAgo dni).",
        moodRating: rating,
        category: category,
        aiAnalysis: "Symulowana analiza historyczna.",
        conversation: "",
        imagePaths: [],
        ownerId: userId,
      );

      // 1. Baza lokalna
      await DatabaseService.instance.createEntry(entry);

      // 2. API
      try {
        await ApiService().createEntry(entry);
      } catch (e) {
        print("Błąd API: $e");
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(TranslationService.tr('generated'))),
      );
      refreshEntries();
    }
  }

  String _getHintText() {
    return _selectedSpecificMood == null ? "" : "${TranslationService.tr('describe_why')} ${TranslationService.tr(_selectedSpecificMood!)}...";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

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
                    TranslationService.tr('today_feeling'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 32,
                          height: 1.2,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // 1. GŁÓWNE KATEGORIE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _moodCategories.entries.map((entry) {
                      final catName = entry.key;
                      final data = entry.value;
                      final isSelected = _selectedMainCategory == catName;
                      final color = data['color'] as Color;
                      final icon = data['icon'] as IconData;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Bounceable(
                            onTap: () => _onMainCategoryTap(catName),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 100,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withOpacity(0.2)
                                    : unselectedBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : (isDark ? Colors.white12 : Colors.grey.shade200),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    icon,
                                    color: isSelected ? color : Colors.grey,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    TranslationService.tr(catName),
                                    style: TextStyle(
                                      color: isSelected
                                          ? color
                                          : (isDark ? Colors.white70 : Colors.black54),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // 2. SZCZEGÓŁOWE NASTROJE (Wysuwane)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    alignment: Alignment.topCenter,
                    child: _selectedMainCategory == null
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),
                              Text(
                                TranslationService.tr('refine'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: (_moodCategories[_selectedMainCategory]!['moods'] as List<String>)
                                    .map((mood) {
                                  final isSelected = _selectedSpecificMood == mood;
                                  final mainColor = _moodCategories[_selectedMainCategory]!['color'] as Color;

                                  return Bounceable(
                                    onTap: () => _onSpecificMoodTap(mood),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? mainColor
                                            : unselectedBgColor,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? mainColor
                                              : (isDark ? Colors.white12 : Colors.grey.shade200),
                                        ),
                                      ),
                                      child: Text(
                                        TranslationService.tr(mood),
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : (isDark ? Colors.white : Colors.black87),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                  ),

                  // 3. FORMULARZ WPISU (Wysuwany po wyborze nastroju)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: _selectedSpecificMood == null // Zmieniono warunek
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
                                    TranslationService.tr('activate_ai'),
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
                                          TranslationService.tr('no'),
                                          !_wantAI,
                                          () => setState(() => _wantAI = false),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildChoiceBtn(
                                          context,
                                          TranslationService.tr('yes'),
                                          _wantAI,
                                          () => setState(() => _wantAI = true),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_wantAI) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      TranslationService.tr('choose_personality'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildAvatarChoice(
                                            context,
                                            TranslationService.tr('male_voice'),
                                            'assets/images/male_avatar.png',
                                            !_tempIsAiFemale,
                                            () => setState(() => _tempIsAiFemale = false),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildAvatarChoice(
                                            context,
                                            TranslationService.tr('female_voice'),
                                            'assets/images/female_avatar.png',
                                            _tempIsAiFemale,
                                            () => setState(() => _tempIsAiFemale = true),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                                  child: Text(
                                    TranslationService.tr('save_entry'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              // ---------------------------------------------------
                              // TUTAJ DODANO PRZYCISK DEWELOPERSKI
                              // ---------------------------------------------------
                              const SizedBox(height: 20),
                              Center(
                                child: TextButton.icon(
                                  onPressed: _generateTestEntries,
                                  icon: const Icon(
                                    Icons.bug_report,
                                    color: Colors.orange,
                                  ),
                                  label: Text(
                                    TranslationService.tr('generate_demo'),
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              // ---------------------------------------------------
                            ],
                          ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        TranslationService.tr('your_entries'),
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
                              TranslationService.tr('no_entries'),
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          ),
                        );
                      }
                      final allEntries = snapshot.data!;
                      final displayEntries = allEntries.take(4).toList();
                      
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
                          ),
                          if (allEntries.length >= 4)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: TextButton(
                                  onPressed: widget.onGoToCalendar,
                                  child: Text(
                                    TranslationService.tr('see_all'),
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
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

  Widget _buildAvatarChoice(
      BuildContext context,
      String label,
      String assetPath,
      bool isActive,
      VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isActive
        ? AppColors.primaryBlue
        : (isDark ? Colors.white12 : Colors.grey.shade200);
    final bgColor = isActive
        ? AppColors.primaryBlue.withOpacity(0.1)
        : (isDark ? Colors.black12 : Colors.grey.shade50);

    return Bounceable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isActive ? 2 : 1),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: AssetImage(assetPath),
              backgroundColor: Colors.transparent,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isActive 
                    ? AppColors.primaryBlue 
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            if (isActive) ...[
               const SizedBox(height: 4),
               const Icon(Icons.check_circle, size: 16, color: AppColors.primaryBlue),
            ]
          ],
        ),
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
