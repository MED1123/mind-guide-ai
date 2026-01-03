import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/mood_entry.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Zmiana nazwy pliku wymusi utworzenie nowej bazy z nowym schematem
    _database = await _initDB('mood_journal_v4.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 3, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE mood_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      backend_id INTEGER,
      date TEXT NOT NULL,
      text TEXT NOT NULL,
      moodRating REAL NOT NULL,
      category TEXT NOT NULL,
      aiAnalysis TEXT NOT NULL,
      conversation TEXT NOT NULL,
      imagePaths TEXT NOT NULL,
      owner_id TEXT NOT NULL
    )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Add backend_id column if it doesn't exist
      try {
        await db.execute('ALTER TABLE mood_entries ADD COLUMN backend_id INTEGER');
      } catch (e) {
        // Ignorujemy błąd jeśli kolumna już istnieje (np. po reinstallu)
        print("Migracja: kolumna backend_id pewnie już istnieje: $e");
      }
    }
  }

  Future<int> createEntry(MoodEntry entry) async {
    final db = await instance.database;
    final imagesString = entry.imagePaths.join('|');

    return await db.insert('mood_entries', {
      'backend_id': entry.backendId,
      'date': entry.date.toIso8601String(),
      'text': entry.text,
      'moodRating': entry.moodRating,
      'category': entry.category,
      'aiAnalysis': entry.aiAnalysis,
      'conversation': entry.conversation,
      'imagePaths': imagesString,
      'owner_id': entry.ownerId,
    });
  }

  Future<List<MoodEntry>> readEntriesForUser(String userId) async {
    final db = await instance.database;

    final result = await db.query(
      'mood_entries',
      where: 'owner_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );

    return result.map((json) {
      String imagesStr = json['imagePaths'] as String? ?? "";
      List<String> images = imagesStr.isEmpty ? [] : imagesStr.split('|');

      return MoodEntry(
        id: json['id'] as int?,
        backendId: json['backend_id'] as int?,
        date: DateTime.parse(json['date'] as String),
        text: json['text'] as String,
        moodRating: json['moodRating'] as double,
        category: json['category'] as String,
        aiAnalysis: json['aiAnalysis'] as String,
        conversation: json['conversation'] as String? ?? "",
        imagePaths: images,
        ownerId: json['owner_id'] as String?,
      );
    }).toList();
  }

  Future<int> updateEntry(MoodEntry entry) async {
    final db = await instance.database;
    final imagesString = entry.imagePaths.join('|');

    return await db.update(
      'mood_entries',
      {
        'backend_id': entry.backendId, // Ensure backendId is preserved or updated
        'text': entry.text,
        'conversation': entry.conversation,
        'aiAnalysis': entry.aiAnalysis,
        'imagePaths': imagesString,
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> updateBackendId(int localId, int backendId) async {
    final db = await instance.database;
    await db.update(
      'mood_entries',
      {'backend_id': backendId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<int> deleteEntry(int id) async {
    final db = await instance.database;
    return await db.delete('mood_entries', where: 'id = ?', whereArgs: [id]);
  }
}
