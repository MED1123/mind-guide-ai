import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../main.dart';
import '../models/mood_entry.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mood_journal_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    print("📂 Ścieżka do bazy danych: $path");

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE mood_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      text TEXT NOT NULL,
      moodRating REAL NOT NULL,
      category TEXT NOT NULL,
      aiAnalysis TEXT NOT NULL,
      conversation TEXT NOT NULL 
    )
    ''');
  }

  Future<int> createEntry(MoodEntry entry) async {
    final db = await instance.database;
    return await db.insert('mood_entries', {
      'date': entry.date.toIso8601String(),
      'text': entry.text,
      'moodRating': entry.moodRating,
      'category': entry.category,
      'aiAnalysis': entry.aiAnalysis,
      'conversation': entry.conversation,
    });
  }

  Future<List<MoodEntry>> readAllEntries() async {
    final db = await instance.database;
    final result = await db.query('mood_entries', orderBy: 'date DESC');

    return result
        .map(
          (json) => MoodEntry(
            id: json['id'] as int?,
            date: DateTime.parse(json['date'] as String),
            text: json['text'] as String,
            moodRating: json['moodRating'] as double,
            category: json['category'] as String,
            aiAnalysis: json['aiAnalysis'] as String,
            conversation: json['conversation'] as String? ?? "",
          ),
        )
        .toList();
  }

  Future<int> updateEntry(MoodEntry entry) async {
    final db = await instance.database;
    return await db.update(
      'mood_entries',
      {
        'text': entry.text,
        'conversation': entry.conversation,
        'aiAnalysis': entry.aiAnalysis,
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }
}
