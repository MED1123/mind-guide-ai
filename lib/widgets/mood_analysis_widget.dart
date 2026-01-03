import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../Services/api_service.dart';
import '../main.dart';
import '../models/mood_analysis.dart';
import '../screens/analysis_detail_screen.dart';
import '../Services/translation_service.dart';

class MoodAnalysisWidget extends StatefulWidget {
  const MoodAnalysisWidget({super.key});

  @override
  State<MoodAnalysisWidget> createState() => _MoodAnalysisWidgetState();
}

class _MoodAnalysisWidgetState extends State<MoodAnalysisWidget> {
  final List<String> _ranges = ['day', 'week', 'month', 'year'];
  int _currentIndex = 1;

  MoodAnalysis? _analysis;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchAnalysis();
  }

  void _fetchAnalysis() async {
    setState(() => _isLoading = true);
    final range = _ranges[_currentIndex];
    final result = await ApiService()
        .getMoodAnalysis(range, appSettings.locale.languageCode);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _analysis = result;
      });
    }
  }

  void _handleSwipe(bool isLeft) {
    setState(() {
      if (isLeft) {
        if (_currentIndex < _ranges.length - 1) _currentIndex++;
      } else {
        if (_currentIndex > 0) _currentIndex--;
      }
    });
    _fetchAnalysis();
  }

  void _openDetailScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalysisDetailScreen(
          initialRange: _ranges[_currentIndex],
          initialAnalysis: _analysis,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  (IconData, Color) _getMoodStyle(String category) {
    if (category.toLowerCase().contains("radosny") ||
        category.contains("Radość")) {
      return (Icons.sentiment_very_satisfied, Colors.orange);
    }
    if (category.toLowerCase().contains("spokojny")) {
      return (Icons.self_improvement, Colors.green);
    }
    if (category.toLowerCase().contains("zestresowany") ||
        category.contains("Stres")) {
      return (Icons.bolt, AppColors.cardRed);
    }
    if (category.toLowerCase().contains("smutny")) {
      return (Icons.cloud, Colors.blueGrey);
    }
    if (category.toLowerCase().contains("zły") || category.contains("Złość")) {
      return (Icons.whatshot, AppColors.angerRed);
    }
    return (Icons.circle, Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! < 0)
          _handleSwipe(true);
        else if (details.primaryVelocity! > 0)
          _handleSwipe(false);
      },
      child: Bounceable(
        onTap: _openDetailScreen,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_currentIndex > 0)
                    Icon(Icons.chevron_left, size: 16, color: Colors.grey),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      TranslationService.tr(_ranges[_currentIndex]),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  if (_currentIndex < _ranges.length - 1)
                    Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 10),

              _isLoading
                  ? const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_analysis == null || _analysis!.entryCount < 2)
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          "Brak danych dla: ${TranslationService.tr(_ranges[_currentIndex])}",
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 120,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final countMap = _analysis!.moodStats;
                          final entries = countMap.entries.toList();

                          // POPRAWKA: Zwiększono overheadHeight z 52px na 60px dla bezpieczeństwa
                          const double overheadHeight = 60.0;
                          final double maxBarHeight =
                              constraints.maxHeight - overheadHeight;

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: entries.map((entry) {
                              final catName = entry.key;
                              final count = entry.value;
                              final total = _analysis!.entryCount;
                              final double barHeight = total > 0
                                  ? (count / total) * maxBarHeight
                                  : 0;
                              final (icon, color) = _getMoodStyle(catName);

                              return Flexible(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      child: FittedBox(
                                        child: Text(
                                          "$count",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: textColor.withOpacity(0.6),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: 10,
                                      height: barHeight < 8 ? 8 : barHeight,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Icon(
                                      icon,
                                      color: color.withOpacity(0.8),
                                      size: 18,
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
