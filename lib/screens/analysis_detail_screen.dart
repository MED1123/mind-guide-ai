import 'package:flutter/material.dart';
import '../models/mood_analysis.dart';
import '../main.dart'; // AppColors

class AnalysisDetailScreen extends StatelessWidget {
  final String currentRange;
  final MoodAnalysis? analysis;

  const AnalysisDetailScreen({
    super.key,
    required this.currentRange,
    required this.analysis,
  });

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
        automaticallyImplyLeading: false, // Ukrywamy domyślną strzałkę
        actions: [
          // Przycisk Wyjścia (X)
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: textColor, size: 28),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              "Szczegółowa Analiza",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              "Zakres: $currentRange",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),

            // Karta z Poradą AI
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppColors.primaryBlue),
                      const SizedBox(width: 10),
                      const Text(
                        "Asystent radzi",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (analysis == null)
                    const Text("Brak danych do analizy.")
                  else
                    Text(
                      analysis!.aiSuggestion,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: textColor.withOpacity(0.9),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Tutaj można dodać więcej statystyk lub duży wykres w przyszłości
            if (analysis != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Text(
                      "Liczba wpisów: ${analysis!.entryCount}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Średnia ocena: ${analysis!.averageMood.toStringAsFixed(1)} / 5.0",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
