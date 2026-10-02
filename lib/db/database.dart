import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/song.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  static Database? _db;

  DatabaseHelper._();
  factory DatabaseHelper() => _instance;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'singbook.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE songs (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          artist TEXT NOT NULL,
          album_art TEXT DEFAULT '',
          key_offset INTEGER DEFAULT 0,
          memo TEXT DEFAULT '',
          tags TEXT DEFAULT '[]',
          updated_at INTEGER NOT NULL
        )
      '''),
    );
  }

  Future<List<Song>> getAll() async {
    final rows = await (await db).query('songs', orderBy: 'updated_at DESC');
    return rows.map(Song.fromMap).toList();
  }

  Future<Song?> getById(String id) async {
    final rows = await (await db).query('songs', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Song.fromMap(rows.first);
  }

  Future<void> upsert(Song song) async {
    await (await db).insert(
      'songs',
      song.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    await (await db).delete('songs', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Song>> search(String query) async {
    final q = '%$query%';
    final rows = await (await db).query(
      'songs',
      where: 'title LIKE ? OR artist LIKE ?',
      whereArgs: [q, q],
      orderBy: 'updated_at DESC',
    );
    return rows.map(Song.fromMap).toList();
  }

  // Returns tag -> song count map
  Future<Map<String, int>> getAllTags() async {
    final songs = await getAll();
    final Map<String, int> counts = {};
    for (final song in songs) {
      for (final tag in song.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  // Remove a tag from all songs
  Future<void> deleteTag(String tag) async {
    final songs = await getAll();
    final d = await db;
    final batch = d.batch();
    for (final song in songs) {
      if (song.tags.contains(tag)) {
        final updated = song.copyWith(tags: song.tags.where((t) => t != tag).toList());
        batch.insert('songs', updated.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteAll() async {
    await (await db).delete('songs');
  }

  Future<String> exportJson() async {
    final songs = await getAll();
    final list = songs.map((s) => s.toMap()).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }
}
