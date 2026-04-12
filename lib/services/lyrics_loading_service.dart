import 'dart:async';
import 'dart:io';

import '../models/song.dart';
import '../utils/logger.dart';
import 'download_service.dart';
import 'lyrics_service.dart';
import 'music_api_service.dart';

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

      if (lyrics == null || lyrics.isEmpty || trans == null || trans.isEmpty) {
        final dbResult = await _getLyricsFromDatabase(song.id);
        if (lyrics == null || lyrics.isEmpty) lyrics = dbResult.lrc;
        if (trans == null || trans.isEmpty) trans = dbResult.trans;
      }

      if (lyrics == null || lyrics.isEmpty) {
        final apiResult = await _getLyricsFromApi(song);
        lyrics = apiResult.lrc;
        trans = apiResult.trans;
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
      Logger.debug('使用对象存储的歌词: ${song.title}', 'LyricsLoading');
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
          if (lyricsFile.existsSync()) {
            lrc = await lyricsFile.readAsString();
            Logger.debug('使用本地下载的歌词', 'LyricsLoading');
          }
        } catch (e) {
          Logger.warning('读取本地歌词失败: $e', 'LyricsLoading');
        }
      }

      if (downloadedSong?.localTransPath != null) {
        try {
          final transFile = File(downloadedSong!.localTransPath!);
          if (transFile.existsSync()) {
            trans = await transFile.readAsString();
            Logger.debug('使用本地下载的翻译', 'LyricsLoading');
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

  Future<LyricsResult> _getLyricsFromDatabase(String songId) async {
    String? lrc;
    String? trans;

    try {
      final dbResult = await LyricsService().getLyricsWithTranslation(songId);
      if (dbResult != null) {
        lrc = dbResult['lrc'];
        trans = dbResult['trans'];
        if (lrc != null && lrc.isNotEmpty) {
          Logger.debug('从数据库读取歌词', 'LyricsLoading');
        }
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
      Logger.debug('使用API获取歌词: ${song.title}', 'LyricsLoading');
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
