import 'dart:async';
import 'dart:io';

import '../../models/song.dart';
import '../../utils/logger.dart';
import '../download/download.dart';
import 'lyrics_service.dart';
import '../network/network.dart';

class LyricsLoadingService {
  static final LyricsLoadingService _instance = LyricsLoadingService._internal();
  factory LyricsLoadingService() => _instance;
  LyricsLoadingService._internal();

  final _apiService = MusicApiService();
  final _downloadService = DownloadService();

  Future<LyricsResult?> loadLyrics(Song song) async {
    try {
      String? lyrics;
      String? trans;

      lyrics = _getLyricsFromSong(song);

      if (lyrics == null || lyrics.isEmpty) {
        final fileResult = await _getLyricsFromLocalFile(song.id);
        lyrics = fileResult.lrc;
        trans = fileResult.trans;
      }

      if (lyrics == null || lyrics.isEmpty) {
        final localResult = await _getLyricsFromLocalScannedSong(song);
        lyrics = localResult.lrc;
        if (trans == null || trans.isEmpty) trans = localResult.trans;
      }

      if (lyrics == null || lyrics.isEmpty || trans == null || trans.isEmpty) {
        final dbResult = await _getLyricsFromDatabase(song.id);
        if (lyrics == null || lyrics.isEmpty) lyrics = dbResult.lrc;
        if (trans == null || trans.isEmpty) trans = dbResult.trans;
      }

      if (lyrics == null || lyrics.isEmpty) {
        final apiResult = await _getLyricsFromApi(song);
        if (apiResult.lrc != null && apiResult.lrc!.isNotEmpty) {
          lyrics = apiResult.lrc;
        }
        if ((trans == null || trans.isEmpty) && apiResult.trans != null && apiResult.trans!.isNotEmpty) {
          trans = apiResult.trans;
        }
      }

      if (lyrics != null && lyrics.isNotEmpty) {
        return LyricsResult(lrc: lyrics, trans: trans);
      }

      return null;
    } catch (e) {
      Logger.error('加载歌词失败', e, null, 'LyricsLoading');
      return null;
    }
  }

  String? _getLyricsFromSong(Song song) {
    if (song.lyricsLrc != null && song.lyricsLrc!.isNotEmpty) {
      return song.lyricsLrc;
    }
    return null;
  }

  Future<LyricsResult> _getLyricsFromLocalFile(String songId) async {
    String? lrc;
    String? trans;

    try {
      final downloaded = await _downloadService.getDownloadedSongs();
      final downloadedSong = downloaded.where((d) => d.id == songId).firstOrNull;

      if (downloadedSong?.localLyricsPath != null) {
        try {
          final lyricsFile = File(downloadedSong!.localLyricsPath!);
          if (await lyricsFile.exists()) {
            lrc = await lyricsFile.readAsString();
          }
        } catch (e) {
          Logger.warning('读取本地歌词失败: $e', 'LyricsLoading');
        }
      }

      if (downloadedSong?.localTransPath != null) {
        try {
          final transFile = File(downloadedSong!.localTransPath!);
          if (await transFile.exists()) {
            trans = await transFile.readAsString();
          }
        } catch (e) {
          Logger.warning('读取本地翻译失败: $e', 'LyricsLoading');
        }
      }
    } catch (e) {
      Logger.warning('查询下载歌曲失败: $e', 'LyricsLoading');
    }

    return LyricsResult(lrc: lrc, trans: trans);
  }

  Future<LyricsResult> _getLyricsFromLocalScannedSong(Song song) async {
    String? lrc;
    String? trans;

    if (song.localLyricsPath != null && song.localLyricsPath!.isNotEmpty) {
      try {
        final lyricsFile = File(song.localLyricsPath!);
        if (await lyricsFile.exists()) {
          lrc = await lyricsFile.readAsString();
        }
      } catch (e) {
        Logger.warning('读取本地扫描歌词失败: $e', 'LyricsLoading');
      }
    }

    if (lrc == null || lrc.isEmpty) {
      try {
        // 通过 DownloadService 查询本地扫描歌曲的歌词路径
        final downloadService = DownloadService();
        final localSong = await downloadService.getDownloadedSongById(song.id);
        if (localSong != null) {
          if (localSong.localLyricsPath != null && localSong.localLyricsPath!.isNotEmpty) {
            final lyricsFile = File(localSong.localLyricsPath!);
            if (await lyricsFile.exists()) {
              lrc = await lyricsFile.readAsString();
            }
          }
          if (localSong.localTransPath != null && localSong.localTransPath!.isNotEmpty) {
            final transFile = File(localSong.localTransPath!);
            if (await transFile.exists()) {
              trans = await transFile.readAsString();
            }
          }
        }
      } catch (e) {
        Logger.warning('从数据库加载本地歌词失败: $e', 'LyricsLoading');
      }
    }

    if (song.localTransPath != null && song.localTransPath!.isNotEmpty && (trans == null || trans.isEmpty)) {
      try {
        final transFile = File(song.localTransPath!);
        if (await transFile.exists()) {
          trans = await transFile.readAsString();
        }
      } catch (e) {
        Logger.warning('读取本地扫描翻译失败: $e', 'LyricsLoading');
      }
    }

    return LyricsResult(lrc: lrc, trans: trans);
  }

  Future<LyricsResult> _getLyricsFromDatabase(String songId) async {
    String? lrc;
    String? trans;

    try {
      final dbResult = await LyricsService().getLyricsWithTranslation(songId);
      if (dbResult != null) {
        lrc = dbResult['lrc'];
        trans = dbResult['trans'];
      }
    } catch (e) {
      Logger.warning('从数据库读取歌词失败: $e', 'LyricsLoading');
    }

    return LyricsResult(lrc: lrc, trans: trans);
  }

  Future<LyricsResult> _getLyricsFromApi(Song song) async {
    String? lrc;
    String? trans;

    try {
      final result = await _apiService.getLyricsWithTranslation(songId: song.id);
      lrc = result?['lrc'];
      trans = result?['trans'];

      if (lrc != null && lrc.isNotEmpty) {
        unawaited(LyricsService().saveLyrics(
          songId: song.id,
          lyrics: lrc,
          title: song.title,
          artist: song.artist,
          translation: trans,
        ));
      }
    } catch (e) {
      Logger.warning('从API获取歌词失败: $e', 'LyricsLoading');
    }

    return LyricsResult(lrc: lrc, trans: trans);
  }
}

class LyricsResult {
  final String? lrc;
  final String? trans;

  const LyricsResult({this.lrc, this.trans});

  bool get hasLyrics => lrc != null && lrc!.isNotEmpty;
  bool get hasTranslation => trans != null && trans!.isNotEmpty;
}
