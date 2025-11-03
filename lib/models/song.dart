class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final String audioUrl;
  final int? duration; // 时长（秒）
  final String? platform; // 音乐平台：netease, qq, kugou等
  final String? r2CoverUrl; // R2对象存储的封面URL
  final String? lyricsLrc; // LRC 格式歌词

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    this.coverUrl = '',
    this.audioUrl = '',
    this.duration,
    this.platform,
    this.r2CoverUrl,
    this.lyricsLrc,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      album: json['album'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      audioUrl: json['audioUrl'] ?? '',
      duration: json['duration'] as int?,
      platform: json['platform'],
      r2CoverUrl: json['r2CoverUrl'],
      lyricsLrc: json['lyricsLrc'],
    );
  }

  /// 从音乐API返回的数据创建Song对象
  factory Song.fromApiJson(Map<String, dynamic> json, String platform) {
    // 解析时长（可能是秒数或字符串格式）
    int durationSeconds = 0;
    if (json['time'] != null) {
      if (json['time'] is int) {
        durationSeconds = json['time'];
      } else if (json['time'] is String) {
        durationSeconds = int.tryParse(json['time']) ?? 0;
      }
    }

    return Song(
      id: json['id']?.toString() ?? '',
      title: json['name'] ?? json['title'] ?? '',
      artist: json['artist']?.toString().split(',').first ?? '',
      album: json['album'] ?? '',
      coverUrl: json['pic'] ?? json['cover'] ?? '',
      audioUrl: json['url'] ?? '',
      duration: durationSeconds,
      platform: platform,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'coverUrl': coverUrl,
      'audioUrl': audioUrl,
      'duration': duration,
      'platform': platform,
      'r2CoverUrl': r2CoverUrl,
      'lyricsLrc': lyricsLrc,
    };
  }

  static List<Song> getMockData() {
    return [
      Song(
        id: '1',
        title: '夜曲',
        artist: '周杰伦',
        album: '十一月的萧邦',
        coverUrl: 'https://picsum.photos/400/400?random=1',
        audioUrl: '',
        duration: 225,
      ),
      Song(
        id: '2',
        title: '晴天',
        artist: '周杰伦',
        album: '叶惠美',
        coverUrl: 'https://picsum.photos/400/400?random=2',
        audioUrl: '',
        duration: 268,
      ),
      Song(
        id: '3',
        title: '七里香',
        artist: '周杰伦',
        album: '七里香',
        coverUrl: 'https://picsum.photos/400/400?random=3',
        audioUrl: '',
        duration: 302,
      ),
      Song(
        id: '4',
        title: '稻香',
        artist: '周杰伦',
        album: '魔杰座',
        coverUrl: 'https://picsum.photos/400/400?random=4',
        audioUrl: '',
        duration: 223,
      ),
      Song(
        id: '5',
        title: '青花瓷',
        artist: '周杰伦',
        album: '我很忙',
        coverUrl: 'https://picsum.photos/400/400?random=5',
        audioUrl: '',
        duration: 238,
      ),
      Song(
        id: '6',
        title: '告白气球',
        artist: '周杰伦',
        album: '周杰伦的床边故事',
        coverUrl: 'https://picsum.photos/400/400?random=6',
        audioUrl: '',
        duration: 215,
      ),
      Song(
        id: '7',
        title: '等你下课',
        artist: '周杰伦',
        album: '最伟大的作品',
        coverUrl: 'https://picsum.photos/400/400?random=7',
        audioUrl: '',
        duration: 255,
      ),
      Song(
        id: '8',
        title: '简单爱',
        artist: '周杰伦',
        album: '范特西',
        coverUrl: 'https://picsum.photos/400/400?random=8',
        audioUrl: '',
        duration: 270,
      ),
    ];
  }
}
