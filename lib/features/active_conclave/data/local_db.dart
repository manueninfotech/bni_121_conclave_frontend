import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localDbProvider = Provider<LocalDatabase>((ref) {
  return LocalDatabase();
});

/// Offline-first store for everything captured at the table.
///
/// The venue has no usable connectivity for 300-400 people, so attendance and
/// referrals are written here first and pushed to the server later by
/// SyncService. Nothing in the capture path may depend on the network.
class LocalDatabase {
  Database? _db;

  /// Disambiguates referrals created within the same microsecond tick.
  int _referralCounter = 0;

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
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        conclaveId TEXT NOT NULL,
        roundNumber INTEGER NOT NULL,
        tableNumber INTEGER NOT NULL,
        userId TEXT NOT NULL,
        isPresent INTEGER NOT NULL,
        markedBy TEXT NOT NULL DEFAULT '',
        synced INTEGER NOT NULL DEFAULT 0,
        timestamp TEXT NOT NULL
      )
    ''');

    // Referrals this user GAVE. Created offline, pushed up by SyncService.
    //
    // toName/toBusinessName are denormalised on purpose: the recipient's name is
    // known from the table roster at the moment the referral is given, and the
    // post-conclave summary has no roster to look it up in later. Without them
    // the summary can only show a raw uid.
    await db.execute('''
      CREATE TABLE referrals (
        id TEXT PRIMARY KEY,
        conclaveId TEXT NOT NULL,
        roundNumber INTEGER NOT NULL,
        fromUserId TEXT NOT NULL,
        toUserId TEXT NOT NULL,
        toName TEXT NOT NULL DEFAULT '',
        toBusinessName TEXT NOT NULL DEFAULT '',
        notes TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        timestamp TEXT NOT NULL
      )
    ''');

    await _createReceivedTable(db);
  }

  /// Referrals this user RECEIVED. These are pulled DOWN from the server — a
  /// promise made on someone else's phone cannot reach us any other way. Cached
  /// locally so the post-conclave view still works offline afterwards.
  Future<void> _createReceivedTable(Database db) async {
    await db.execute('''
      CREATE TABLE referrals_received (
        id TEXT PRIMARY KEY,
        conclaveId TEXT NOT NULL,
        roundNumber INTEGER NOT NULL,
        fromUserId TEXT NOT NULL,
        toUserId TEXT NOT NULL,
        fromName TEXT NOT NULL DEFAULT '',
        fromBusinessName TEXT NOT NULL DEFAULT '',
        notes TEXT,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 rows were all written under a single broken primary key, so there is
      // at most one of them and it carries no attribution. Add the column; the
      // default covers the existing row.
      await db.execute(
        "ALTER TABLE attendance ADD COLUMN markedBy TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 3) {
      await _createReceivedTable(db);
    }
    if (oldVersion < 4) {
      // Existing rows have no recipient name. The summary falls back to the
      // conclave's participant snapshot for those.
      await db.execute("ALTER TABLE referrals ADD COLUMN toName TEXT NOT NULL DEFAULT ''");
      await db.execute(
        "ALTER TABLE referrals ADD COLUMN toBusinessName TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  // --- Attendance ---------------------------------------------------------

  /// Records whether [userId] was at the table for [roundNumber].
  ///
  /// Keyed by (conclave, round, user), so re-marking the same person in the same
  /// round updates that record rather than appending a second one.
  Future<void> markAttendance({
    required String conclaveId,
    required int roundNumber,
    required int tableNumber,
    required String userId,
    required bool isPresent,
    required String markedBy,
  }) async {
    final db = await database;
    final id = '$conclaveId-$roundNumber-$userId';

    await db.insert('attendance', {
      'id': id,
      'conclaveId': conclaveId,
      'roundNumber': roundNumber,
      'tableNumber': tableNumber,
      'userId': userId,
      'isPresent': isPresent ? 1 : 0,
      'markedBy': markedBy,
      'synced': 0,
      'timestamp': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Attendance for one round, as `userId -> isPresent`. Drives the captain's
  /// view of who showed up, and works with no network.
  Future<Map<String, bool>> getAttendanceForRound({
    required String conclaveId,
    required int roundNumber,
  }) async {
    final db = await database;
    final rows = await db.query(
      'attendance',
      where: 'conclaveId = ? AND roundNumber = ?',
      whereArgs: [conclaveId, roundNumber],
    );
    return {
      for (final r in rows) r['userId'] as String: (r['isPresent'] as int) == 1,
    };
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

  // --- Referrals ----------------------------------------------------------

  /// Records that [fromUserId] promised business to [toUserId].
  ///
  /// Referrals are immutable once given (spec: "can't modify"), so this refuses
  /// to write a second referral for the same (round, from, to) triple and
  /// reports whether it actually wrote.
  Future<bool> addReferral({
    required String conclaveId,
    required int roundNumber,
    required String fromUserId,
    required String toUserId,
    String toName = '',
    String toBusinessName = '',
    String? notes,
  }) async {
    if (fromUserId == toUserId) return false; // cannot refer yourself

    if (await hasReferred(
      conclaveId: conclaveId,
      roundNumber: roundNumber,
      fromUserId: fromUserId,
      toUserId: toUserId,
    )) {
      return false;
    }

    final db = await database;
    final id =
        '$conclaveId-$fromUserId-${DateTime.now().microsecondsSinceEpoch}-${_referralCounter++}';

    await db.insert('referrals', {
      'id': id,
      'conclaveId': conclaveId,
      'roundNumber': roundNumber,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'toName': toName,
      'toBusinessName': toBusinessName,
      'notes': notes ?? '',
      'synced': 0,
      'timestamp': DateTime.now().toIso8601String(),
    });
    return true;
  }

  Future<bool> hasReferred({
    required String conclaveId,
    required int roundNumber,
    required String fromUserId,
    required String toUserId,
  }) async {
    final db = await database;
    final rows = await db.query(
      'referrals',
      where:
          'conclaveId = ? AND roundNumber = ? AND fromUserId = ? AND toUserId = ?',
      whereArgs: [conclaveId, roundNumber, fromUserId, toUserId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// The uids this user has already referred in [roundNumber] — used to lock
  /// the referral buttons that have already been used.
  Future<Set<String>> getReferredUserIdsForRound({
    required String conclaveId,
    required int roundNumber,
    required String fromUserId,
  }) async {
    final db = await database;
    final rows = await db.query(
      'referrals',
      columns: ['toUserId'],
      where: 'conclaveId = ? AND roundNumber = ? AND fromUserId = ?',
      whereArgs: [conclaveId, roundNumber, fromUserId],
    );
    return rows.map((r) => r['toUserId'] as String).toSet();
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

  /// Every referral this user gave in [conclaveId], synced or not.
  Future<List<Map<String, dynamic>>> getGivenReferrals({
    required String conclaveId,
    required String fromUserId,
  }) async {
    final db = await database;
    return await db.query(
      'referrals',
      where: 'conclaveId = ? AND fromUserId = ?',
      whereArgs: [conclaveId, fromUserId],
      orderBy: 'roundNumber ASC',
    );
  }

  // --- Received referrals (pulled down from the server) --------------------

  /// Caches referrals other people gave to this user. Idempotent: the server may
  /// resend the same record, and re-syncing must not duplicate it.
  Future<void> upsertReceivedReferrals(List<Map<String, dynamic>> referrals) async {
    if (referrals.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final r in referrals) {
      final id = r['id'];
      if (id == null) continue;
      batch.insert(
        'referrals_received',
        {
          'id': id as String,
          'conclaveId': (r['conclaveId'] ?? '') as String,
          'roundNumber': (r['roundNumber'] as num?)?.toInt() ?? 0,
          'fromUserId': (r['fromUserId'] ?? '') as String,
          'toUserId': (r['toUserId'] ?? '') as String,
          'fromName': (r['fromName'] ?? '') as String,
          'fromBusinessName': (r['fromBusinessName'] ?? '') as String,
          'notes': (r['notes'] ?? '') as String,
          'timestamp': (r['createdAt'] ?? DateTime.now().toIso8601String()) as String,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getReceivedReferrals({
    required String conclaveId,
    required String toUserId,
  }) async {
    final db = await database;
    return await db.query(
      'referrals_received',
      where: 'conclaveId = ? AND toUserId = ?',
      whereArgs: [conclaveId, toUserId],
      orderBy: 'roundNumber ASC',
    );
  }

  // --- Attendance history (post-conclave view) -----------------------------

  /// This user's own attendance across every round, with sync state.
  Future<List<Map<String, dynamic>>> getMyAttendance({
    required String conclaveId,
    required String userId,
  }) async {
    final db = await database;
    return await db.query(
      'attendance',
      where: 'conclaveId = ? AND userId = ?',
      whereArgs: [conclaveId, userId],
      orderBy: 'roundNumber ASC',
    );
  }
}
