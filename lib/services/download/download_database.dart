import 'dart:async';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../models/downloaded_song.dart';
import '../../utils/logger.dart';

/// 下载记录 SQLite 数据库
///
/// 管理已下载歌曲的持久化存储，替代旧版 SharedPreferences 方案
/// 表结构：downloaded_songs（主键：歌曲ID）
/// 索引：title、artist、source（加速查询和过滤）
///
/// 数据迁移：支持从 SharedPreferences 一键批量导入旧数据
class DownloadDatabase {
  static final DownloadDatabase _instance = DownloadDatabase._internal();
  factory DownloadDatabase() => _instance;
  DownloadDatabase._internal();

  Database? _db;
  static const int _version = 1;
  static const String _dbName = 'hai_music_downloads.db';
  Completer<Database>? _initCompleter;

  /// 获取数据库实例（懒初始化，线程安全）
  Future<Database> get database async {
    if (_db != null) return _db!;

    _initCompleter ??= Completer<Database>();
    if (!_initCompleter!.isCompleted) {
      try {
        final db = await _initDb();
        _db = db;
        _initCompleter!.complete(db);
      } catch (e) {
        _initCompleter!.completeError(e);
        _initCompleter = null;
        rethrow;
      }
    }
    return _initCompleter!.future;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, _dbName);

    return openDatabase(
      fullPath,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE downloaded_songs (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT NOT NULL DEFAULT '',
        cover_url TEXT NOT NULL DEFAULT '',
        local_audio_path TEXT NOT NULL,
        local_cover_path TEXT,
        local_lyrics_path TEXT,
        local_trans_path TEXT,
        duration INTEGER,
        platform TEXT,
        downloaded_at TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'downloaded',
        audio_quality_value INTEGER,
        content_uri TEXT,
        file_size INTEGER
      )
    ''');

    await db.execute('CREATE INDEX idx_downloaded_songs_title ON downloaded_songs(title)');
    await db.execute('CREATE INDEX idx_downloaded_songs_artist ON downloaded_songs(artist)');
    await db.execute('CREATE INDEX idx_downloaded_songs_source ON downloaded_songs(source)');

    Logger.info('下载数据库创建成功 v$version', 'DownloadDB');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    Logger.info('下载数据库升级: v$oldVersion -> v$newVersion', 'DownloadDB');
    for (int v = oldVersion + 1; v <= newVersion; v++) {
      switch (v) {
        default:
          break;
      }
    }
  }

  /// 插入或替换一条下载记录
  Future<void> insertDownloadedSong(DownloadedSong song) async {
    final db = await database;
    await db.insert(
      'downloaded_songs',
      _toRow(song),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 按来源查询下载歌曲列表
  Future<List<DownloadedSong>> getSongsBySource(String source) async {
    final db = await database;
    final rows = await db.query(
      'downloaded_songs',
      where: 'source = ?',
      whereArgs: [source],
      orderBy: 'downloaded_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  /// 按来源统计下载歌曲数量
  Future<int> getCountBySource(String source) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM downloaded_songs WHERE source = ?',
      [source],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取所有下载歌曲（按下载时间倒序）
  Future<List<DownloadedSong>> getAllDownloadedSongs() async {
    final db = await database;
    final rows = await db.query(
      'downloaded_songs',
      orderBy: 'downloaded_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  /// 根据歌曲ID查询下载记录
  Future<DownloadedSong?> getDownloadedSong(String id) async {
    final db = await database;
    final rows = await db.query(
      'downloaded_songs',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// 检查歌曲是否已下载
  Future<bool> isDownloaded(String id) async {
    final db = await database;
    final rows = await db.query(
      'downloaded_songs',
      where: 'id = ?',
      whereArgs: [id],
      columns: ['id'],
    );
    return rows.isNotEmpty;
  }

  /// 根据歌曲ID删除下载记录
  Future<int> deleteDownloadedSong(String id) async {
    final db = await database;
    return db.delete(
      'downloaded_songs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取下载歌曲总数
  Future<int> getDownloadedCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM downloaded_songs');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取所有下载歌曲的总文件大小
  Future<int> getDownloadedSize() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COALESCE(SUM(file_size), 0) as total FROM downloaded_songs');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 按音质分组统计文件大小
  Future<Map<String, int>> getSizeByQuality() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT audio_quality_value, COALESCE(SUM(file_size), 0) as total FROM downloaded_songs GROUP BY audio_quality_value',
    );
    final map = <String, int>{};
    for (final row in result) {
      final quality = row['audio_quality_value']?.toString() ?? 'unknown';
      map[quality] = (row['total'] as int?) ?? 0;
    }
    return map;
  }

  /// 更新歌曲文件大小
  Future<int> updateFileSize(String id, int fileSize) async {
    final db = await database;
    return db.update(
      'downloaded_songs',
      {'file_size': fileSize},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 从 SharedPreferences 批量迁移旧数据到 SQLite
  Future<void> migrateFromSharedPreferences(List<DownloadedSong> songs) async {
    if (songs.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final song in songs) {
      batch.insert(
        'downloaded_songs',
        _toRow(song),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
    Logger.success('从 SharedPreferences 迁移 ${songs.length} 条下载记录到 SQLite', 'DownloadDB');
  }

  /// 清空所有下载记录
  Future<void> deleteAll() async {
    final db = await database;
    await db.delete('downloaded_songs');
  }

  /// 批量删除下载记录（使用事务确保原子性）
  Future<void> batchDeleteDownloadedSongs(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.delete(
        'downloaded_songs',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 获取数据库文件路径
  Future<String?> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return path.join(dbPath, _dbName);
  }

  /// 关闭数据库连接并释放资源
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _initCompleter = null;
      Logger.info('下载数据库已关闭', 'DownloadDB');
    }
  }

  Map<String, dynamic> _toRow(DownloadedSong song) {
    return {
      'id': song.id,
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'cover_url': song.coverUrl,
      'local_audio_path': song.localAudioPath,
      'local_cover_path': song.localCoverPath,
      'local_lyrics_path': song.localLyricsPath,
      'local_trans_path': song.localTransPath,
      'duration': song.duration,
      'platform': song.platform,
      'downloaded_at': song.downloadedAt.toIso8601String(),
      'source': song.source.label,
      'audio_quality_value': song.audioQualityValue,
      'content_uri': song.contentUri,
      'file_size': song.fileSize,
    };
  }

  DownloadedSong _fromRow(Map<String, dynamic> row) {
    return DownloadedSong(
      id: row['id'] as String,
      title: row['title'] as String,
      artist: row['artist'] as String,
      album: (row['album'] as String?) ?? '',
      coverUrl: (row['cover_url'] as String?) ?? '',
      localAudioPath: row['local_audio_path'] as String,
      localCoverPath: row['local_cover_path'] as String?,
      localLyricsPath: row['local_lyrics_path'] as String?,
      localTransPath: row['local_trans_path'] as String?,
      duration: row['duration'] as int?,
      platform: row['platform'] as String?,
      downloadedAt: DateTime.tryParse(row['downloaded_at'] as String? ?? '') ?? DateTime.now(),
      source: DownloadedSong.parseSource(row['source']),
      audioQualityValue: row['audio_quality_value'] as int?,
      contentUri: row['content_uri'] as String?,
      fileSize: row['file_size'] as int?,
    );
  }
}
