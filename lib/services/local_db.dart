import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/queue_models.dart';
import '../models/wallpaper.dart';

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'pinwall_local.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE api_cache (
            cache_key TEXT PRIMARY KEY,
            items_json TEXT NOT NULL,
            fetched_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE import_history (
            board_url TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            pin_count INTEGER NOT NULL,
            preview_url TEXT,
            last_imported_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE queue_boards (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            queue_type TEXT NOT NULL,
            board_url TEXT NOT NULL,
            label TEXT NOT NULL,
            added_at INTEGER NOT NULL,
            UNIQUE(queue_type, board_url)
          )
        ''');
        await db.execute('''
          CREATE TABLE queued_wallpapers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            queue_type TEXT NOT NULL,
            pin_id TEXT,
            image_url TEXT NOT NULL,
            local_path TEXT NOT NULL,
            source_board TEXT,
            alt TEXT,
            width INTEGER,
            height INTEGER,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            applied_at INTEGER,
            UNIQUE(queue_type, image_url)
          )
        ''');
      },
    );
    return _db!;
  }

  static String boardLabelFromUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.pathSegments.isEmpty) return rawUrl.trim();
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0]} / ${parts[1]}';
    if (parts.isNotEmpty) return parts.first;
    return rawUrl.trim();
  }

  // ── Heavy API Cache ───────────────────────────────────────────────────────

  Future<List<MediaItem>?> getCachedItems(
    String key, {
    Duration ttl = const Duration(hours: 6),
  }) async {
    final database = await db;
    final rows = await database.query(
      'api_cache',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final fetchedAt = rows.first['fetched_at'] as int;
    final ageMs = DateTime.now().millisecondsSinceEpoch - fetchedAt;
    if (ageMs > ttl.inMilliseconds) return null;

    final rawList = jsonDecode(rows.first['items_json'] as String) as List;
    return rawList
        .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setCachedItems(String key, List<MediaItem> items) async {
    final database = await db;
    await database.insert(
      'api_cache',
      {
        'cache_key': key,
        'items_json': jsonEncode(items.map((e) => e.toJson()).toList()),
        'fetched_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> appendCachedItems(String key, List<MediaItem> moreItems) async {
    final existing = await getCachedItems(key, ttl: const Duration(days: 30)) ?? [];
    final seen = existing.map((e) => e.url).toSet();
    final merged = [
      ...existing,
      ...moreItems.where((e) => !seen.contains(e.url)),
    ];
    await setCachedItems(key, merged);
  }

  Future<int> getApiCacheCount() async {
    final database = await db;
    final res = await database.rawQuery('SELECT COUNT(*) as c FROM api_cache');
    return (res.first['c'] as int?) ?? 0;
  }

  Future<void> clearApiCache() async {
    final database = await db;
    await database.delete('api_cache');
  }

  // ── Import History ────────────────────────────────────────────────────────

  Future<void> upsertImportHistory(ImportHistoryEntry entry) async {
    final database = await db;
    await database.insert(
      'import_history',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ImportHistoryEntry>> getImportHistory() async {
    final database = await db;
    final rows = await database.query(
      'import_history',
      orderBy: 'last_imported_at DESC',
    );
    return rows.map(ImportHistoryEntry.fromMap).toList();
  }

  Future<void> deleteImportHistory(String boardUrl) async {
    final database = await db;
    await database.delete(
      'import_history',
      where: 'board_url = ?',
      whereArgs: [boardUrl],
    );
  }

  // ── Queue Boards ──────────────────────────────────────────────────────────

  Future<void> addQueueBoard(String queueType, String boardUrl) async {
    final database = await db;
    final cleanUrl = boardUrl.trim();
    await database.insert(
      'queue_boards',
      {
        'queue_type': queueType,
        'board_url': cleanUrl,
        'label': boardLabelFromUrl(cleanUrl),
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<QueueBoard>> getQueueBoards([String? queueType]) async {
    final database = await db;
    final rows = await database.query(
      'queue_boards',
      where: queueType != null ? 'queue_type = ?' : null,
      whereArgs: queueType != null ? [queueType] : null,
      orderBy: 'added_at DESC',
    );
    return rows.map(QueueBoard.fromMap).toList();
  }

  Future<void> removeQueueBoard(int id) async {
    final database = await db;
    await database.delete('queue_boards', where: 'id = ?', whereArgs: [id]);
  }

  // ── Queued Wallpapers (Local Disk Gallery) ────────────────────────────────

  Future<bool> hasWallpaperInQueue(String queueType, String imageUrl) async {
    final database = await db;
    final rows = await database.query(
      'queued_wallpapers',
      columns: ['id'],
      where: 'queue_type = ? AND image_url = ?',
      whereArgs: [queueType, imageUrl],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> insertQueuedWallpaper(QueuedWallpaper item) async {
    final database = await db;
    return database.insert(
      'queued_wallpapers',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<QueuedWallpaper>> getQueuedWallpapers({
    String? queueType,
    String? status,
  }) async {
    final database = await db;
    final whereParts = <String>[];
    final args = <Object>[];
    if (queueType != null) {
      whereParts.add('queue_type = ?');
      args.add(queueType);
    }
    if (status != null) {
      whereParts.add('status = ?');
      args.add(status);
    }
    final rows = await database.query(
      'queued_wallpapers',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at ASC',
    );
    return rows.map(QueuedWallpaper.fromMap).toList();
  }

  Future<void> markWallpaperApplied(int id) async {
    final database = await db;
    await database.update(
      'queued_wallpapers',
      {
        'status': 'applied',
        'applied_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteQueuedWallpaper(QueuedWallpaper item) async {
    final database = await db;
    if (item.id != null) {
      await database.delete(
        'queued_wallpapers',
        where: 'id = ?',
        whereArgs: [item.id],
      );
    }
    try {
      final f = File(item.localPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Deletes applied wallpapers in [queueType] (optionally keeping [keepId] so user sees current active).
  Future<int> deleteAppliedWallpapers(String queueType, {int? keepId}) async {
    final applied = await getQueuedWallpapers(
      queueType: queueType,
      status: 'applied',
    );
    int deleted = 0;
    for (final item in applied) {
      if (keepId != null && item.id == keepId) continue;
      await deleteQueuedWallpaper(item);
      deleted++;
    }
    return deleted;
  }

  /// Enforces [maxSize] for [queueType] by removing oldest applied items first,
  /// then oldest queued items if still over limit.
  Future<int> pruneQueueToMaxSize(String queueType, int maxSize) async {
    final all = await getQueuedWallpapers(queueType: queueType);
    if (all.length <= maxSize) return 0;

    int toRemove = all.length - maxSize;
    int removed = 0;

    // Delete oldest applied first
    final applied = all.where((e) => e.isApplied).toList()
      ..sort((a, b) => (a.appliedAt ?? a.createdAt).compareTo(b.appliedAt ?? b.createdAt));
    for (final item in applied) {
      if (toRemove <= 0) break;
      await deleteQueuedWallpaper(item);
      toRemove--;
      removed++;
    }

    // Then oldest queued if still exceeding maxSize
    if (toRemove > 0) {
      final queued = all.where((e) => !e.isApplied).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final item in queued) {
        if (toRemove <= 0) break;
        await deleteQueuedWallpaper(item);
        toRemove--;
        removed++;
      }
    }
    return removed;
  }

  Future<void> clearQueue(String queueType) async {
    final items = await getQueuedWallpapers(queueType: queueType);
    for (final item in items) {
      await deleteQueuedWallpaper(item);
    }
  }
}

