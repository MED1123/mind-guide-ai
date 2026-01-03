class MoodEntry {
  final int? id; // Local SQLite ID
  final int? backendId; // Remote Postgres ID
  
  final DateTime date;
  String text;
  final double moodRating;
  final String category;
  String aiAnalysis;
  String conversation;
  List<String> imagePaths;
  final String? ownerId;

  MoodEntry({
    this.id,
    this.backendId,
    required this.date,
    required this.text,
    required this.moodRating,
    required this.category,
    required this.aiAnalysis,
    this.conversation = "",
    this.imagePaths = const [],
    this.ownerId,
  });
}
