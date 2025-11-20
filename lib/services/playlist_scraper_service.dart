import 'package:dio/dio.dart';
import '../utils/logger.dart';

/// 推荐歌单数据模型
class RecommendedPlaylist {
  final String id;
  final String title;
  final String coverUrl;

  RecommendedPlaylist({
    required this.id,
    required this.title,
    required this.coverUrl,
  });

  @override
  String toString() {
    return 'RecommendedPlaylist(id: $id, title: $title, coverUrl: $coverUrl)';
  }
}

/// QQ音乐推荐歌单爬虫服务
class PlaylistScraperService {
  final Dio _dio = Dio();

  /// 获取QQ音乐首页推荐歌单
  Future<List<RecommendedPlaylist>> fetchRecommendedPlaylists() async {
    try {
      Logger.network('开始请求 QQ音乐首页...', 'PlaylistScraper');
      final response = await _dio.get(
        'https://y.qq.com/',
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          },
        ),
      );
      
      Logger.network('响应状态码: ${response.statusCode}', 'PlaylistScraper');
      
      if (response.statusCode != 200) {
        Logger.warning('请求失败,状态码: ${response.statusCode}', 'PlaylistScraper');
        return [];
      }
      
      final htmlContent = response.data;
      Logger.debug('HTML 内容长度: ${htmlContent.length}', 'PlaylistScraper');
      
      final playlists = <RecommendedPlaylist>[];
      
      // 从HTML中提取JSON数据
      // 匹配: "imgurl":"http://qpic.y.qq.com/...","dissname":"...","listennum":...,"dissid":...
      final playlistDataRegex = RegExp(
        r'"imgurl":"([^"]+)","dissname":"([^"]+)","listennum":\d+,"dissid":(\d+)',
      );
      
      final matches = playlistDataRegex.allMatches(htmlContent);
      Logger.debug('找到 ${matches.length} 个匹配项', 'PlaylistScraper');
      
      for (final match in matches) {
        try {
          var imgurl = match.group(1)!;
          final dissname = match.group(2)!;
          final dissid = match.group(3)!;
          
          // 处理封面URL (替换转义字符)
          imgurl = imgurl.replaceAll(r'\u002F', '/');
          
          // 添加https协议
          if (imgurl.startsWith('//')) {
            imgurl = 'https:$imgurl';
          } else if (imgurl.startsWith('http://')) {
            imgurl = imgurl.replaceFirst('http://', 'https://');
          } else if (!imgurl.startsWith('https://')) {
            imgurl = 'https://$imgurl';
          }
          
          playlists.add(RecommendedPlaylist(
            id: dissid,
            title: dissname,
            coverUrl: imgurl,
          ));
        } catch (e) {
          continue;
        }
      }
      
      Logger.success('成功解析 ${playlists.length} 个歌单', 'PlaylistScraper');
      return playlists;
    } catch (e) {
      Logger.error('解析歌单失败', e, null, 'PlaylistScraper');
      return [];
    }
  }
}
