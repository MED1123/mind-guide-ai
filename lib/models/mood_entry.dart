class MoodEntry {
  final int? id;
  final DateTime date;
  String text;
  final double moodRating;
  final String category;
  String aiAnalysis;
  String conversation;
  List<String> imagePaths;

  MoodEntry({
    this.id,
    required this.date,
    required this.text,
    required this.moodRating,
    required this.category,
    required this.aiAnalysis,
    this.conversation = "",
    this.imagePaths = const [],
  });
}
