import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;

class DatabaseHelper {
  static const _databaseName = 'music_favorites.db';
  static const _databaseVersion = 3; // Updated version
  static const table = 'favorites';
  static const columnPath = 'path';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async => _database ??= await _initDatabase();

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnPath TEXT PRIMARY KEY NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS $table');
      await _onCreate(db, newVersion);
    }
    // Add any additional upgrade logic here
  }

  String _normalizePath(String path) {
    if (path.isEmpty) return path;

    // Standardize path format
    String normalized = path
        .replaceAll('\\', '/')
        .replaceAll('/sdcard/', '/storage/emulated/0/')
        .replaceAll('//', '/')
        .toLowerCase()
        .trim();

    return normalized;
  }

  Future<int> insertFavorite(String path) async {
    try {
      final db = await database;
      final normalizedPath = _normalizePath(path);
      developer.log('Inserting favorite: $normalizedPath');
      return await db.insert(
        table,
        {columnPath: normalizedPath},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      developer.log('Error inserting favorite: $e');
      rethrow;
    }
  }

  Future<int> deleteFavorite(String path) async {
    try {
      final db = await database;
      final normalizedPath = _normalizePath(path);
      developer.log('Deleting favorite: $normalizedPath');
      return await db.delete(
        table,
        where: '$columnPath = ?',
        whereArgs: [normalizedPath],
      );
    } catch (e) {
      developer.log('Error deleting favorite: $e');
      rethrow;
    }
  }

  Future<List<String>> getAllFavorites() async {
    try {
      final db = await database;
      final maps = await db.query(table);
      developer.log('Found ${maps.length} favorites in database');

      return List.generate(maps.length, (i) => maps[i][columnPath] as String);
    } catch (e) {
      developer.log('Error getting favorites: $e');
      return [];
    }
  }

  Future<bool> isFavorite(String path) async {
    try {
      if (path.isEmpty) return false;
      final normalizedPath = _normalizePath(path);
      final db = await database;
      final result = await db.query(
        table,
        where: '$columnPath = ?',
        whereArgs: [normalizedPath],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      developer.log('Error checking favorite: $e');
      return false;
    }
  }

  // Add this helper method for path matching
  bool isPathMatch(String path1, String path2) {
    return _normalizePath(path1) == _normalizePath(path2);
  }
}