import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:intl/intl.dart';
import '../models/mood_analysis.dart';
import '../models/mood_entry.dart';
import '../main.dart'; // AppColors
import 'chat_screen.dart';

class AnalysisDetailScreen extends StatelessWidget {
  final String currentRange;
  final MoodAnalysis? analysis;

  const AnalysisDetailScreen({
    super.key,
    required this.currentRange,
    required this.analysis,
  });

  void _openChatAboutResults(BuildContext context) {
    if (analysis == null) return;

    final dummyEntry = MoodEntry(
      date: DateTime.now(),
      text:
          "Kontekst: Użytkownik chce porozmawiać o swojej analizie nastroju ($currentRange).",
      moodRating: analysis!.averageMood,
      category: "Analiza",
      aiAnalysis: analysis!.aiSuggestion,
      conversation:
          "AI: Cześć! Widzę Twoją analizę. ${analysis!.aiSuggestion}. O czym chcesz porozmawiać?|",
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
          "Analiza nastroju",
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
            Text(
              "Aktywność ($currentRange)",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),

            // --- WYKRES ---
            Container(
              height: 240,
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
              child: _buildBarChart(isDark, textColor),
            ),

            const SizedBox(height: 30),

            // --- KARTA ASYSTENTA ---
            Text(
              "Opinia Asystenta",
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
              child: Column(
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
                      const Text(
                        "Wnioski AI",
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
                    analysis?.aiSuggestion ?? "Brak danych do analizy.",
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
                        children: const [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Porozmawiaj o wynikach",
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
              "Dominujące nastroje",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            if (analysis != null && analysis!.moodStats.isNotEmpty)
              ...analysis!.moodStats.entries.map((entry) {
                final percent = (entry.value / analysis!.entryCount);
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
            else
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Brak danych."),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(bool isDark, Color textColor) {
    if (analysis == null || analysis!.dailyCounts.isEmpty) {
      return const Center(child: Text("Brak danych"));
    }

    final sortedKeys = analysis!.dailyCounts.keys.toList()..sort();

    int maxCount = 0;
    for (var count in analysis!.dailyCounts.values) {
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
                final count = analysis!.dailyCounts[dateStr]!;
                final heightFactor = count / maxCount;
                final date = DateTime.parse(dateStr);
                final dayName = DateFormat('E', 'pl_PL').format(date);
                final dayNum = DateFormat('d').format(date);

                // POPRAWKA: Zwiększono margines bezpieczeństwa na teksty do 70px (było 60px)
                // Teraz mamy pewność, że napisy się zmieszczą.
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

                      // POPRAWKA: Zwiększono wysokość kontenera na datę z 30 do 38px
                      // Dodano FittedBox, aby tekst się skalował zamiast wychodzić.
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
              mood,
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
