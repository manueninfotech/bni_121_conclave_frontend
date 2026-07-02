import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localDbProvider = Provider<LocalDatabase>((ref) {
  return LocalDatabase();
});

class LocalDatabase {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'conclave_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Attendance table (for captains)
    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        conclaveId TEXT NOT NULL,
        roundNumber INTEGER NOT NULL,
        tableNumber INTEGER NOT NULL,
        userId TEXT NOT NULL,
        isPresent INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        timestamp TEXT NOT NULL
      )
    ''');

    // Referrals table (for all users)
    await db.execute('''
      CREATE TABLE referrals (
        id TEXT PRIMARY KEY,
        conclaveId TEXT NOT NULL,
        roundNumber INTEGER NOT NULL,
        fromUserId TEXT NOT NULL,
        toUserId TEXT NOT NULL,
        notes TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  // --- Attendance ---
  Future<void> markAttendance({
    required String conclaveId,
    required int roundNumber,
    required int tableNumber,
    required String userId,
    required bool isPresent,
  }) async {
    final db = await database;
    final id = '\$conclaveId-\$roundNumber-\$userId';
    
    await db.insert('attendance', {
      'id': id,
      'conclaveId': conclaveId,
      'roundNumber': roundNumber,
      'tableNumber': tableNumber,
      'userId': userId,
      'isPresent': isPresent ? 1 : 0,
      'synced': 0,
      'timestamp': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAttendance() async {
    final db = await database;
    return await db.query('attendance', where: 'synced = ?', whereArgs: [0]);
  }

  Future<void> markAttendanceSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.update(
      'attendance',
      {'synced': 1},
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  // --- Referrals ---
  Future<void> addReferral({
    required String conclaveId,
    required int roundNumber,
    required String fromUserId,
    required String toUserId,
    String? notes,
  }) async {
    final db = await database;
    final id = DateTime.now().millisecondsSinceEpoch.toString(); // Unique enough for local
    
    await db.insert('referrals', {
      'id': id,
      'conclaveId': conclaveId,
      'roundNumber': roundNumber,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'notes': notes ?? '',
      'synced': 0,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedReferrals() async {
    final db = await database;
    return await db.query('referrals', where: 'synced = ?', whereArgs: [0]);
  }
  
  Future<void> markReferralsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.update(
      'referrals',
      {'synced': 1},
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }
}
