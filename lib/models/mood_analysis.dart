class MoodAnalysis {
  final int entryCount;
  final double averageMood;
  final Map<String, int> moodStats;
  final Map<String, int> dailyCounts;
  final String aiSuggestion;

  MoodAnalysis({
    required this.entryCount,
    required this.averageMood,
    required this.moodStats,
    required this.dailyCounts,
    required this.aiSuggestion,
  });

  factory MoodAnalysis.fromJson(Map<String, dynamic> json) {
    return MoodAnalysis(
      entryCount: json['entry_count'] ?? 0,
      averageMood: (json['average_mood_rating'] as num?)?.toDouble() ?? 0.0,
      moodStats: Map<String, int>.from(json['mood_stats'] ?? {}),
      // Mapowanie danych dla wykresu
      dailyCounts: Map<String, int>.from(json['daily_counts'] ?? {}),
      aiSuggestion: json['ai_suggestion'] ?? "Brak analizy.",
    );
  }
}
