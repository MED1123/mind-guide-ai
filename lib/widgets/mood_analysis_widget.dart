import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../Services/api_service.dart';
import '../main.dart';
import '../models/mood_analysis.dart';

class MoodAnalysisWidget extends StatefulWidget {
  const MoodAnalysisWidget({super.key});

  @override
  State<MoodAnalysisWidget> createState() => _MoodAnalysisWidgetState();
}

class _MoodAnalysisWidgetState extends State<MoodAnalysisWidget> {
  String _selectedRange = 'Tydzień';
  final List<String> _ranges = ['Dzień', 'Tydzień', 'Miesiąc', 'Rok'];

  MoodAnalysis? _analysis;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAnalysis();
  }

  void _fetchAnalysis() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService().getMoodAnalysis(_selectedRange);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result != null) {
          _analysis = result;
        } else {
          _errorMessage = "Nie udało się pobrać analizy.";
        }
      });
    }
  }

  void _onRangeChanged(String newRange) {
    if (_selectedRange == newRange) return;
    setState(() {
      _selectedRange = newRange;
    });
    _fetchAnalysis();
  }

  // Helper do mapowania nastroju na ikonę/kolor
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
    // Domyślny
    return (Icons.circle, Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nagłówek i przełącznik
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Analiza nastroju",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              // Ikona odświeżania
              if (!_isLoading)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _fetchAnalysis,
                  color: AppColors.textGrey,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Przełącznik zakresów (scrollowany poziomo)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _ranges.map((range) {
                final isSelected = _selectedRange == range;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Bounceable(
                    onTap: () => _onRangeChanged(range),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryBlue
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryBlue
                              : AppColors.textGrey.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        range,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textGrey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Treść główna
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          else if (_analysis == null || _analysis!.entryCount < 2)
            // Warunek: Mniej niż 2 wpisy = brak wystarczających danych
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.textGrey),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Zbyt mało danych do analizy. Dodaj więcej wpisów w tym okresie.",
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                  ),
                ],
              ),
            )
          else
            // Mamy dane -> Wyświetlamy
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Sekcja AI (dymek)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        appSettings.isAiFemale ? Icons.face_3 : Icons.face,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _analysis!.aiSuggestion,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Minimalistyczny Wykres (Statystyka)
                Text(
                  "Statystyka okresu",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 12),

                // Generowanie pasków dla każdej kategorii
                ..._analysis!.moodStats.entries.map((entry) {
                  final catName = entry.key;
                  final count = entry.value;
                  final total = _analysis!.entryCount;
                  final percentage = count / total;
                  final (icon, color) = _getMoodStyle(catName);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        // Ikonka nastroju (minka)
                        Icon(icon, color: color, size: 24),
                        const SizedBox(width: 12),

                        // Pasek postępu
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: percentage,
                                child: Container(
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Liczba dni
                        Text(
                          "${count}x",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}
