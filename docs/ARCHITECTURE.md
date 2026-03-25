# Hai Music 架构文档

## 1. 项目概述

Hai Music 是一个跨平台音乐播放器应用，使用 Flutter 框架开发，支持移动端、桌面端和 Web 端。

### 1.1 技术栈

- **框架**: Flutter 3.0+
- **语言**: Dart
- **状态管理**: Provider
- **网络请求**: Dio
- **音频播放**: 
  - 移动端: audio_service + just_audio
  - 桌面端: audioplayers
- **数据存储**: shared_preferences + path_provider

### 1.2 项目结构

```
lib/
├── config/           # 配置文件
├── extensions/       # 扩展方法
├── models/          # 数据模型
├── providers/       # 状态管理
├── screens/         # 界面组件
├── services/        # 业务服务
├── theme/           # 主题配置
├── utils/           # 工具类
├── widgets/         # 可复用组件
└── main.dart        # 应用入口
```

## 2. 架构设计

### 2.1 整体架构

项目采用 **分层架构** 设计，分为以下几层：

1. **表现层 (Presentation Layer)**: Screens 和 Widgets
2. **业务逻辑层 (Business Logic Layer)**: Providers 和 Services
3. **数据层 (Data Layer)**: Models 和 API Services

### 2.2 核心组件

#### 2.2.1 平台抽象层

为了解决移动端和桌面端的差异，我们创建了平台抽象层：

```dart
// 平台音频服务接口
abstract class PlatformAudioService {
  // 统一的音频播放接口
}

// 桌面端实现
class DesktopAudioService implements PlatformAudioService {
  // 使用 audioplayers
}

// 移动端实现
class MobileAudioService implements PlatformAudioService {
  // 使用 audio_service + just_audio
}

// 工厂类
class PlatformAudioServiceFactory {
  static PlatformAudioService createService({...});
}
```

#### 2.2.2 服务层

服务层负责核心业务逻辑：

- **PlaybackControllerService**: 播放控制
- **PlaylistManagerService**: 播放列表管理
- **SongUrlService**: 歌曲链接获取
- **SmartCacheService**: 智能缓存管理
- **SecurityConfigService**: 安全配置管理

#### 2.2.3 状态管理

使用 Provider 进行状态管理：

- **MusicProvider**: 音乐播放状态
- **ThemeProvider**: 主题状态

### 2.3 数据流

```
用户操作 -> Screen -> Provider -> Service -> API/Local Storage
                ↓
           UI 更新 <- Provider <- Service 回调
```

## 3. 关键功能实现

### 3.1 音频播放

#### 3.1.1 平台差异处理

移动端和桌面端使用不同的音频播放实现：

**移动端**:
- 使用 `audio_service` 实现后台播放
- 支持系统通知和锁屏控制
- 通过 `MusicAudioHandler` 处理播放逻辑

**桌面端**:
- 使用 `audioplayers` 实现本地播放
- 直接控制播放状态和进度
- 无需后台服务支持

#### 3.1.2 统一接口

通过 `PlatformAudioService` 接口统一不同平台的实现：

```dart
abstract class PlatformAudioService {
  Future<void> playSongs(List<Song> songs, {int startIndex = 0});
  Future<void> togglePlayPause();
  Future<void> playNext();
  Future<void> playPrevious();
  Future<void> seekTo(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setSpeed(double speed);
  // ... 其他方法
}
```

### 3.2 缓存管理

#### 3.2.1 智能缓存策略

- **LRU 清理**: 最近最少使用
- **过期管理**: 7天过期时间
- **空间限制**: 最多50首歌曲，最大500MB

#### 3.2.2 异步缓存

使用 Isolate 进行异步缓存操作，避免 UI 阻塞：

```dart
Future<void> cacheOnPlayAsync(Song song, {int? audioQuality}) async {
  // 在 Isolate 中执行下载
  await Isolate.spawn(_downloadInIsolate, message);
}
```

### 3.3 安全配置

#### 3.3.1 网络安全

- SSL 证书验证
- 可信主机列表
- 安全的请求头

#### 3.3.2 输入验证

- URL 验证
- 搜索关键词验证
- SQL 注入防护
- XSS 防护

#### 3.3.3 数据加密

- 敏感数据加密存储
- 安全的密钥管理

## 4. 性能优化

### 4.1 缓存优化

- 异步缓存操作
- 智能缓存清理
- 缓存统计和监控

### 4.2 网络优化

- 请求重试机制
- 请求队列管理
- 响应缓存

### 4.3 UI 优化

- const 构造器使用
- 懒加载实现
- 列表渲染优化

## 5. 测试策略

### 5.1 单元测试

- 服务层测试
- 模型层测试
- 工具类测试

### 5.2 集成测试

- API 调用测试
- 音频播放测试
- 缓存管理测试

### 5.3 测试覆盖率

目标测试覆盖率：
- 核心业务逻辑: >80%
- 工具类: >60%
- 整体: >50%

## 6. 安全考虑

### 6.1 网络安全

- HTTPS 强制使用
- SSL 证书验证
- 请求签名验证

### 6.2 数据安全

- 敏感数据加密
- 安全存储使用
- 输入数据清理

### 6.3 代码安全

- 依赖包安全扫描
- 代码审查流程
- 安全漏洞监控

## 7. 扩展性设计

### 7.1 插件化架构

- 音频播放器插件化
- 存储后端插件化
- UI 主题插件化

### 7.2 配置管理

- 环境配置分离
- 动态配置更新
- 配置验证机制

### 7.3 第三方集成

- API 抽象层
- 错误处理机制
- 降级策略

## 8. 部署和发布

### 8.1 构建配置

- 多平台构建脚本
- 环境变量配置
- 版本管理

### 8.2 发布流程

- 自动化构建
- 测试自动化
- 发布检查清单

## 9. 开发规范

### 9.1 代码规范

- 遵循 Flutter 最佳实践
- 使用 flutter_lints
- 代码格式化

### 9.2 文档规范

- 代码注释要求
- API 文档生成
- 架构文档维护

### 9.3 版本控制

- Git 工作流
- 分支管理策略
- 提交信息规范

## 10. 故障排除

### 10.1 常见问题

- 音频播放问题
- 网络请求问题
- 缓存管理问题

### 10.2 调试工具

- 日志系统
- 性能监控
- 错误追踪

### 10.3 支持渠道

- 问题报告流程
- 技术支持联系方式
- 社区支持

## 11. 未来规划

### 11.1 功能扩展

- 云同步功能
- 社交分享
- 智能推荐

### 11.2 技术升级

- Flutter 版本升级
- 依赖包更新
- 架构优化

### 11.3 性能提升

- 启动速度优化
- 内存占用优化
- 电池寿命优化

---

**文档版本**: 1.0  
**最后更新**: 2026-03-25  
**维护者**: Hai Music 开发团队
