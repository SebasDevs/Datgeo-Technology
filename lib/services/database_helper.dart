import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/restaurant.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'restaurants.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE restaurants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        ruc TEXT,
        latitude REAL,
        longitude REAL,
        comment TEXT,
        photo1 TEXT,
        photo2 TEXT,
        photo3 TEXT,
        photo1CaptureTime TEXT,
        photo2CaptureTime TEXT,
        photo3CaptureTime TEXT,
        createdAt TEXT,
        isSynced INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE photo_types (
        uuid TEXT PRIMARY KEY,
        name TEXT
      )
    ''');
  }

  Future<int> insertRestaurant(Restaurant restaurant) async {
    final db = await database;
    return await db.insert('restaurants', restaurant.toMap());
  }

  Future<List<Restaurant>> getRestaurants() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('restaurants');
    return List.generate(maps.length, (i) {
      return Restaurant.fromMap(maps[i]);
    });
  }

  Future<List<Restaurant>> getUnsyncedRestaurants() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'restaurants',
      where: 'isSynced = ?',
      whereArgs: [0],
    );
    return List.generate(maps.length, (i) {
      return Restaurant.fromMap(maps[i]);
    });
  }

  Future<void> updateRestaurantSyncStatus(int id, bool isSynced) async {
    final db = await database;
    await db.update(
      'restaurants',
      {'isSynced': isSynced ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertPhotoType(String uuid, String name) async {
    final db = await database;
    await db.insert('photo_types', {'uuid': uuid, 'name': name});
  }

  Future<List<Map<String, dynamic>>> getPhotoTypes() async {
    final db = await database;
    return await db.query('photo_types');
  }

  Future<void> clearPhotoTypes() async {
    final db = await database;
    await db.delete('photo_types');
  }
}