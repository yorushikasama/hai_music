# Logger 使用指南

## 📖 快速开始

### 导入 Logger

```dart
import '../utils/logger.dart';
```

### 基础使用

```dart
// 调试信息（仅 debug 模式）
Logger.debug('调试信息', 'MyClass');

// 普通信息（始终输出）
Logger.info('操作开始', 'MyClass');

// 成功信息（仅 debug 模式）
Logger.success('操作成功', 'MyClass');

// 警告信息（始终输出）
Logger.warning('潜在问题', 'MyClass');

// 错误信息（始终输出）
Logger.error('操作失败', error, stackTrace, 'MyClass');
```

---

## 🎯 专用方法

### 下载日志

```dart
Logger.download('开始下载: ${song.title}', 'DownloadService');
Logger.download('下载进度: ${progress}%', 'DownloadService');
Logger.download('下载完成', 'DownloadService');
```

### 缓存日志

```dart
Logger.cache('缓存命中: $key', 'DataCache');
Logger.cache('缓存已过期', 'DataCache');
Logger.cache('清理缓存', 'DataCache');
```

### 数据库日志

```dart
Logger.database('查询数据', 'Supabase');
Logger.database('插入记录', 'Supabase');
Logger.database('更新成功', 'Supabase');
```

### 网络日志

```dart
Logger.network('请求: $url', 'API');
Logger.network('响应成功', 'API');
Logger.network('网络错误', 'API');
```

---

## 🏷️ Tag 命名规范

### 使用类名

```dart
class MusicProvider {
  void play() {
    Logger.info('播放', 'MusicProvider');
  }
}
```

### 使用模块名

```dart
// 内存监控
Logger.debug('内存使用: ${memory}MB', 'MemoryMonitor');

// 缓存清理
Logger.info('清理完成', 'CacheCleanup');
```

---

## 📊 日志级别说明

| 方法 | 图标 | debug 模式 | release 模式 | 用途 |
|------|------|-----------|-------------|------|
| `debug()` | 🔍 | ✅ 输出 | ❌ 不输出 | 详细调试信息 |
| `info()` | ℹ️ | ✅ 输出 | ✅ 输出 | 重要操作信息 |
| `success()` | ✅ | ✅ 输出 | ❌ 不输出 | 成功操作 |
| `warning()` | ⚠️ | ✅ 输出 | ✅ 输出 | 警告信息 |
| `error()` | ❌ | ✅ 输出 | ✅ 输出 | 错误信息 |
| `download()` | ⬇️ | ✅ 输出 | ❌ 不输出 | 下载操作 |
| `cache()` | 📦 | ✅ 输出 | ❌ 不输出 | 缓存操作 |
| `database()` | 💾 | ✅ 输出 | ❌ 不输出 | 数据库操作 |
| `network()` | 🌐 | ✅ 输出 | ❌ 不输出 | 网络请求 |

---

## 🔧 高级用法

### 错误日志完整示例

```dart
try {
  // 执行操作
  await someOperation();
} catch (e, stackTrace) {
  // 记录完整的错误信息
  Logger.error('操作失败', e, stackTrace, 'MyClass');
}
```

### 条件日志

```dart
// Logger 内部已经处理了 debug/release 控制
// 不需要手动判断 kDebugMode
Logger.debug('这只在 debug 模式输出', 'MyClass');
```

### 手动控制日志开关

```dart
// 临时关闭 debug 日志（不推荐）
Logger.enableDebugLog = false;

// 恢复默认（根据 kDebugMode）
Logger.enableDebugLog = kDebugMode;
```

---

## 💡 最佳实践

### ✅ 推荐做法

```dart
// 1. 使用合适的日志级别
Logger.info('用户登录', 'Auth');  // 重要操作
Logger.debug('缓存键: $key', 'Cache');  // 调试信息

// 2. 提供有用的上下文
Logger.info('播放: ${song.title} - ${song.artist}', 'MusicProvider');

// 3. 错误日志包含完整信息
Logger.error('下载失败', e, stackTrace, 'Download');

// 4. 使用专用方法
Logger.download('进度: $progress%', 'DownloadService');
```

### ❌ 避免做法

```dart
// 1. 不要在 release 模式输出过多日志
// ❌ 错误：使用 info 输出调试信息
Logger.info('临时调试: $value', 'MyClass');
// ✅ 正确：使用 debug
Logger.debug('临时调试: $value', 'MyClass');

// 2. 不要忽略错误信息
// ❌ 错误：只输出消息
Logger.error('失败', null, null, 'MyClass');
// ✅ 正确：包含错误对象
Logger.error('失败', e, stackTrace, 'MyClass');

// 3. 不要使用过长的 tag
// ❌ 错误
Logger.info('消息', 'MyVeryLongClassName');
// ✅ 正确
Logger.info('消息', 'MyClass');
```

---

## 📝 迁移示例

### 从 print 迁移

```dart
// 之前
print('✅ 下载完成: ${song.title}');
print('❌ 下载失败: $e');

// 之后
Logger.success('下载完成: ${song.title}', 'Download');
Logger.error('下载失败', e, null, 'Download');
```

### 从 debugPrint 迁移

```dart
// 之前
debugPrint('调试信息: $value');

// 之后
Logger.debug('调试信息: $value', 'MyClass');
```

---

## 🎯 实际应用示例

### 播放器示例

```dart
class MusicProvider {
  Future<void> playSong(Song song) async {
    try {
      Logger.info('开始播放: ${song.title}', 'MusicProvider');
      
      final url = await _getSongUrl(song);
      if (url == null) {
        Logger.warning('无法获取播放链接', 'MusicProvider');
        return;
      }
      
      await _audioPlayer.play(url);
      Logger.success('播放成功', 'MusicProvider');
    } catch (e, stackTrace) {
      Logger.error('播放失败', e, stackTrace, 'MusicProvider');
    }
  }
}
```

### 下载服务示例

```dart
class DownloadService {
  Future<void> downloadSong(Song song) async {
    try {
      Logger.download('开始下载: ${song.title}', 'Download');
      
      await _dio.download(
        song.url,
        savePath,
        onReceiveProgress: (received, total) {
          final progress = (received / total * 100).toInt();
          Logger.download('进度: $progress%', 'Download');
        },
      );
      
      Logger.success('下载完成', 'Download');
    } catch (e, stackTrace) {
      Logger.error('下载失败', e, stackTrace, 'Download');
    }
  }
}
```

### 缓存服务示例

```dart
class CacheService {
  T? get<T>(String key) {
    if (_cache.containsKey(key)) {
      Logger.cache('缓存命中: $key', 'Cache');
      return _cache[key] as T;
    }
    
    Logger.cache('缓存未命中: $key', 'Cache');
    return null;
  }
  
  void clear() {
    final count = _cache.length;
    _cache.clear();
    Logger.cache('清理了 $count 个缓存项', 'Cache');
  }
}
```

---

## 🔍 调试技巧

### 1. 按 Tag 过滤日志

在 IDE 或终端中搜索特定 tag：
```
[MusicProvider]
[Download]
[Cache]
```

### 2. 按图标过滤日志

搜索特定图标：
```
⬇️  # 下载日志
📦  # 缓存日志
❌  # 错误日志
```

### 3. 查看完整错误信息

错误日志会自动输出：
- 错误消息
- 错误详情（error 对象）
- 堆栈跟踪（stackTrace）

---

## 📚 更多资源

- [Logger 源码](../lib/utils/logger.dart)

---

**最后更新：** 2026-04-11
