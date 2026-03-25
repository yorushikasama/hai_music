import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/models/song.dart';
import 'package:hai_music/services/platform_audio_service.dart';
import 'package:hai_music/services/platform_audio_service_factory.dart';
import 'package:hai_music/services/playlist_manager_service.dart';
import 'package:hai_music/services/song_url_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformAudioService', () {
    late PlaylistManagerService playlistManager;
    late SongUrlService urlService;

    setUp(() {
      playlistManager = PlaylistManagerService();
      urlService = SongUrlService();
    });

    tearDown(() {
      playlistManager.dispose();
    });

    test('should create platform-specific audio service', () {
      final service = PlatformAudioServiceFactory.createService(
        playlistManager: playlistManager,
        urlService: urlService,
      );

      expect(service, isNotNull);
      expect(service, isA<PlatformAudioService>());
    });

    test('should have correct initial state', () {
      final service = PlatformAudioServiceFactory.createService(
        playlistManager: playlistManager,
        urlService: urlService,
      );

      expect(service.isPlaying, isFalse);
      expect(service.isLoading, isFalse);
      expect(service.currentPosition, equals(Duration.zero));
      expect(service.totalDuration, equals(Duration.zero));
      expect(service.volume, equals(1.0));
      expect(service.speed, equals(1.0));
      expect(service.currentPlayingSong, isNull);
    });

    test('should manage playlist correctly', () {
      final service = PlatformAudioServiceFactory.createService(
        playlistManager: playlistManager,
        urlService: urlService,
      );

      final songs = [
        Song(
          id: '1',
          title: 'Song 1',
          artist: 'Artist 1',
          album: 'Album 1',
          coverUrl: 'https://example.com/cover1.jpg',
          audioUrl: 'https://example.com/song1.mp3',
          duration: 180,
          platform: 'qq',
        ),
        Song(
          id: '2',
          title: 'Song 2',
          artist: 'Artist 2',
          album: 'Album 2',
          coverUrl: 'https://example.com/cover2.jpg',
          audioUrl: 'https://example.com/song2.mp3',
          duration: 200,
          platform: 'qq',
        ),
      ];

      // 更新播放列表
      service.updatePlaylist(songs);
      
      // 播放列表应该被更新
      expect(playlistManager.playlist.length, equals(2));
    });

    test('should handle volume changes correctly', () async {
      final service = PlatformAudioServiceFactory.createService(
        playlistManager: playlistManager,
        urlService: urlService,
      );

      // 测试音量设置
      await service.setVolume(0.5);
      expect(service.volume, equals(0.5));

      // 测试音量边界
      await service.setVolume(1.5);
      expect(service.volume, equals(1.0));

      await service.setVolume(-0.5);
      expect(service.volume, equals(0.0));
    });

    test('should handle speed changes correctly', () async {
      final service = PlatformAudioServiceFactory.createService(
        playlistManager: playlistManager,
        urlService: urlService,
      );

      // 测试播放速度设置
      await service.setSpeed(1.5);
      expect(service.speed, equals(1.5));

      // 测试速度边界
      await service.setSpeed(4.0);
      expect(service.speed, equals(3.0));

      await service.setSpeed(0.1);
      expect(service.speed, equals(0.25));
    });

    test('should create song copies correctly', () {
      final originalSong = Song(
        id: '1',
        title: 'Original Song',
        artist: 'Original Artist',
        album: 'Original Album',
        coverUrl: 'https://example.com/original.jpg',
        audioUrl: 'https://example.com/original.mp3',
        duration: 180,
        platform: 'qq',
      );

      // 创建副本并修改audioUrl
      final copiedSong = originalSong.copyWith(
        audioUrl: 'https://example.com/new.mp3',
      );

      // 验证副本的属性
      expect(copiedSong.id, equals(originalSong.id));
      expect(copiedSong.title, equals(originalSong.title));
      expect(copiedSong.artist, equals(originalSong.artist));
      expect(copiedSong.audioUrl, equals('https://example.com/new.mp3'));
      expect(originalSong.audioUrl, equals('https://example.com/original.mp3'));
    });

    test('should compare songs correctly', () {
      final song1 = Song(
        id: '1',
        title: 'Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        coverUrl: 'https://example.com/cover1.jpg',
        audioUrl: 'https://example.com/song1.mp3',
        duration: 180,
        platform: 'qq',
      );

      final song2 = Song(
        id: '1',
        title: 'Different Title',
        artist: 'Different Artist',
        album: 'Different Album',
        coverUrl: 'https://example.com/different.jpg',
        audioUrl: 'https://example.com/different.mp3',
        duration: 200,
        platform: 'netease',
      );

      final song3 = Song(
        id: '2',
        title: 'Song 2',
        artist: 'Artist 2',
        album: 'Album 2',
        coverUrl: 'https://example.com/cover2.jpg',
        audioUrl: 'https://example.com/song2.mp3',
        duration: 220,
        platform: 'qq',
      );

      // 相同ID的歌曲应该相等
      expect(song1 == song2, isTrue);
      
      // 不同ID的歌曲应该不相等
      expect(song1 == song3, isFalse);
      
      // 哈希码应该相同
      expect(song1.hashCode, equals(song2.hashCode));
    });

    test('should generate correct song string representation', () {
      final song = Song(
        id: '1',
        title: 'Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
        coverUrl: 'https://example.com/cover.jpg',
        audioUrl: 'https://example.com/song.mp3',
        duration: 180,
        platform: 'qq',
      );

      final stringRepresentation = song.toString();
      expect(stringRepresentation.contains('id: 1'), isTrue);
      expect(stringRepresentation.contains('title: Test Song'), isTrue);
      expect(stringRepresentation.contains('artist: Test Artist'), isTrue);
      expect(stringRepresentation.contains('album: Test Album'), isTrue);
      expect(stringRepresentation.contains('duration: 180'), isTrue);
      expect(stringRepresentation.contains('platform: qq'), isTrue);
    });

    test('should handle empty playlist', () async {
      final service = PlatformAudioServiceFactory.createService(
        playlistManager: playlistManager,
        urlService: urlService,
      );

      // 尝试播放空列表
      await service.playSongs([]);
      
      // 不应该抛出异常，应该正常处理
      expect(service.isPlaying, isFalse);
    });

    test('should dispose resources correctly', () async {
      final service = PlatformAudioServiceFactory.createService(
        playlistManager: playlistManager,
        urlService: urlService,
      );

      // 释放资源
      await service.dispose();
      
      // 资源应该被正确释放
      expect(service.isPlaying, isFalse);
    });
  });
}
