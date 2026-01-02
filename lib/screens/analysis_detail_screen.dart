import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:intl/intl.dart';
import '../models/mood_analysis.dart';
import '../models/mood_entry.dart';
import '../main.dart'; // AppColors
import 'chat_screen.dart';
import '../Services/api_service.dart';
import '../Services/translation_service.dart'; // Import

class AnalysisDetailScreen extends StatefulWidget {
  final String initialRange;
  final MoodAnalysis? initialAnalysis;

  const AnalysisDetailScreen({
    super.key,
    required this.initialRange,
    required this.initialAnalysis,
  });

  @override
  State<AnalysisDetailScreen> createState() => _AnalysisDetailScreenState();
}

class _AnalysisDetailScreenState extends State<AnalysisDetailScreen> {
  late String _currentRange;
  MoodAnalysis? _analysis;
  bool _isLoading = false;

  final List<String> _ranges = ['Dzień', 'Tydzień', 'Miesiąc', 'Rok'];

  @override
  void initState() {
    super.initState();
    _currentRange = widget.initialRange;
    _analysis = widget.initialAnalysis;
  }

  void _changeRange(int direction) async {
    int currentIndex = _ranges.indexOf(_currentRange);
    int newIndex = currentIndex + direction;

    if (newIndex >= 0 && newIndex < _ranges.length) {
      setState(() {
        _currentRange = _ranges[newIndex];
        _isLoading = true;
      });

      try {
        final result = await ApiService().getMoodAnalysis(
          _currentRange,
          appSettings.locale.languageCode,
        );
        if (mounted) {
          setState(() {
            _analysis = result;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            // Opcjonalnie: obsługa błędu
          });
        }
      }
    }
  }

  void _openChatAboutResults(BuildContext context) {
    if (_analysis == null) return;

    final dummyEntry = MoodEntry(
      date: DateTime.now(),
      text:
          "Kontekst: Użytkownik chce porozmawiać o swojej analizie nastroju ($_currentRange).",
      moodRating: _analysis!.averageMood,
      category: "Analiza",
      aiAnalysis: _analysis!.aiSuggestion,
      conversation:
          "AI: Cześć! Widzę Twoją analizę. ${_analysis!.aiSuggestion}. O czym chcesz porozmawiać?|",
      imagePaths: [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          entry: dummyEntry,
          onBack: () => Navigator.pop(context),
          onGoToCalendar: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          TranslationService.tr('analysis_title'),
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // NAGŁÓWEK Z NAWIGACJĄ ( STRZAŁKI )
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _ranges.indexOf(_currentRange) > 0
                      ? () => _changeRange(-1)
                      : null,
                  icon: Icon(
                    Icons.chevron_left,
                    color: _ranges.indexOf(_currentRange) > 0
                        ? textColor
                        : Colors.grey.withOpacity(0.3),
                    size: 32,
                  ),
                ),
                Text(
                  "${TranslationService.tr('activity')} (${TranslationService.tr(_currentRange)})",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                IconButton(
                  onPressed: _ranges.indexOf(_currentRange) < _ranges.length - 1
                      ? () => _changeRange(1)
                      : null,
                  icon: Icon(
                    Icons.chevron_right,
                    color: _ranges.indexOf(_currentRange) < _ranges.length - 1
                        ? textColor
                        : Colors.grey.withOpacity(0.3),
                    size: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- WYKRES ---
            Container(
              height: 280, // Zwiększono wysokość na legendę
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEGENDA / PODPIS OSI Y
                        Text(
                          TranslationService.tr('number_of_entries'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textColor.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(child: _buildBarChart(isDark, textColor)),
                      ],
                    ),
            ),

            const SizedBox(height: 30),

            // --- KARTA ASYSTENTA ---
            Text(
              TranslationService.tr('assistant_opinion'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          AppColors.primaryBlue.withOpacity(0.2),
                          const Color(0xFF1E1E1E),
                        ]
                      : [AppColors.primaryBlue.withOpacity(0.05), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                ),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              TranslationService.tr('ai_conclusion'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _analysis?.aiSuggestion ?? TranslationService.tr('no_data_analysis'),
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: textColor.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Bounceable(
                          onTap: () => _openChatAboutResults(context),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  TranslationService.tr('talk_results'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 30),

            // --- DOMINUJĄCE NASTROJE ---
            Text(
              TranslationService.tr('dominant_moods'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            if (!_isLoading &&
                _analysis != null &&
                _analysis!.moodStats.isNotEmpty)
              ..._analysis!.moodStats.entries.map((entry) {
                final percent = (entry.value / _analysis!.entryCount);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildMoodStatRow(
                    entry.key,
                    entry.value,
                    percent,
                    isDark,
                    textColor,
                  ),
                );
              })
            else if (!_isLoading)
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(TranslationService.tr('no_data')),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(bool isDark, Color textColor) {
    if (_analysis == null || _analysis!.dailyCounts.isEmpty) {
      return Center(child: Text(TranslationService.tr('no_data')));
    }

    final sortedKeys = _analysis!.dailyCounts.keys.toList()..sort();

    int maxCount = 0;
    for (var count in _analysis!.dailyCounts.values) {
      if (count > maxCount) maxCount = count;
    }
    if (maxCount == 0) maxCount = 1;

    const double barColumnWidth = 45.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment:
                  (sortedKeys.length * barColumnWidth < constraints.maxWidth)
                      ? MainAxisAlignment.spaceEvenly
                      : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: sortedKeys.map((dateStr) {
                final count = _analysis!.dailyCounts[dateStr]!;
                final heightFactor = count / maxCount;
                final date = DateTime.parse(dateStr);
                final dayName = DateFormat('E', appSettings.locale.toLanguageTag()).format(date);
                final dayNum = DateFormat('d').format(date);

                // POPRAWKA: Zwiększono margines bezpieczeństwa na teksty do 70px
                final double availableHeight = constraints.maxHeight - 70;
                final double barHeight = availableHeight * heightFactor;

                return SizedBox(
                  width: barColumnWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Liczba u góry
                      SizedBox(
                        height: 20,
                        child: count > 0
                            ? Center(
                                child: FittedBox(
                                  child: Text(
                                    "$count",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),

                      const SizedBox(height: 4),

                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        width: 14,
                        height: count > 0 ? barHeight : 4,
                        decoration: BoxDecoration(
                          color: count > 0
                              ? AppColors.primaryBlue
                              : (isDark
                                  ? Colors.white10
                                  : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        height: 38,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            FittedBox(
                              child: Text(
                                dayName,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textColor.withOpacity(0.5),
                                ),
                              ),
                            ),
                            FittedBox(
                              child: Text(
                                dayNum,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: textColor.withOpacity(0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoodStatRow(
    String mood,
    int count,
    double percent,
    bool isDark,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              TranslationService.tr(mood),
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "${(percent * 100).toInt()}%",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: 8),
          Text("($count)", style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
