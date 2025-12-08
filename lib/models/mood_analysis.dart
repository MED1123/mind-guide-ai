class MoodAnalysis {
  final int entryCount;
  final double averageMood;
  final Map<String, int> moodStats;
  final String aiSuggestion;

  MoodAnalysis({
    required this.entryCount,
    required this.averageMood,
    required this.moodStats,
    required this.aiSuggestion,
  });

  factory MoodAnalysis.fromJson(Map<String, dynamic> json) {
    return MoodAnalysis(
      entryCount: json['entry_count'] ?? 0,
      averageMood: (json['average_mood_rating'] as num?)?.toDouble() ?? 0.0,
      // Konwersja mapy JSON na Map<String, int>
      moodStats: Map<String, int>.from(json['mood_stats'] ?? {}),
      aiSuggestion: json['ai_suggestion'] ?? "Brak analizy.",
    );
  }
}
