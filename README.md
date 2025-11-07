# Hai Music 🎵

一款专注于构建个人音乐库的跨平台音乐播放器，支持 Windows、Android 和 Web。通过"我喜欢"功能收藏喜爱的歌曲，自动下载到本地并可选择同步到云端，打造属于自己的音乐收藏库。界面简洁美观，支持深色/浅色主题切换。

## ✨ 应用截图

<div align="center">

<p><strong>云端同步配置页面</strong></p>
<img src="pic/29ae7de02b29c735b75384b469d8c213.png" width="70%" alt="云端同步配置页面" />

<p><strong>windows端主页面</strong></p>
<img src="pic/6d840a56c3b1e2059ec1983259f7762b.png" width="70%" alt="windows端主页面" />

<p><strong>手机端主页</strong></p>
<img src="pic/8524a6646bc2e10ffe5745938f69472b_720.jpg" width="40%" alt="手机端主页" />

</div>

## 🎯 核心功能

### ❤️ 个人音乐库（核心功能）
- **我喜欢**：一键收藏喜爱的歌曲，构建个人音乐库
- **本地存储**：收藏的歌曲自动下载到本地，支持离线播放
- **云端同步**：可选配置 Supabase + Cloudflare R2 实现多设备同步
- **播放全部**：支持播放全部收藏歌曲
- **收藏管理**：查看、播放、删除收藏的歌曲

### 🎼 音乐播放
- **在线搜索**：支持腾讯音乐搜索
- **播放控制**：播放/暂停、上一首/下一首、进度调节、音量控制
- **播放模式**：顺序播放、单曲循环、随机播放
- **音质选择**：标准、HQ 高音质、臻品母带 2.0
- **歌词显示**：支持 LRC 格式歌词显示
- **键盘快捷键**：支持空格播放/暂停等快捷操作（桌面端）
- **定时关闭**：支持 15/30/45/60/90 分钟定时停止播放

### 📚 音乐库
- **发现页面**：每日推荐歌曲和推荐歌单
- **搜索功能**：快速搜索歌曲
- **我喜欢**：查看和管理所有收藏的歌曲
- **最近播放**：自动记录播放历史（最多 50 条）
- **歌单管理**：支持 QQ 音乐歌单导入和播放

### 🎨 界面设计
- **现代化 UI**：采用 Material Design 设计规范
- **毛玻璃效果**：精美的背景模糊和半透明效果
- **主题切换**：支持浅色/深色主题切换
- **响应式布局**：自适应桌面和移动端界面
- **流畅动画**：页面切换和交互动画流畅自然

### 💾 缓存管理
- **智能缓存**：自动缓存音频文件和封面图片
- **容量统计**：实时显示缓存占用空间
- **一键清理**：快速清理音频和封面缓存
- **离线播放**：已缓存的歌曲支持离线播放

### ☁️ 云端同步（可选）
- **Supabase 数据库**：存储歌曲元数据
- **Cloudflare R2**：存储音频文件和封面图片
- **自动同步**：收藏时自动上传到云端
- **多设备访问**：在不同设备间同步收藏列表

## 🛠️ 技术栈

### 核心框架
- **Flutter 3.0+** - 跨平台 UI 框架
- **Dart 3.0+** - 编程语言

### 状态管理
- **Provider 6.1+** - 轻量级状态管理

### UI 组件
- **Google Fonts** - 字体库
- **Animations** - 动画效果
- **Shimmer** - 加载骨架屏
- **Cached Network Image** - 图片缓存

### 音频播放
- **Just Audio** - 音频播放引擎
- **Audio Service** - 后台播放服务
- **Audioplayers** - 备用播放器

### 网络请求
- **Dio 5.4+** - HTTP 客户端
- **HTTP** - 基础网络库

### 数据存储
- **Shared Preferences** - 本地配置存储
- **Path Provider** - 文件路径管理
- **Supabase Flutter** - 云端数据库
- **Minio** - S3 兼容对象存储（用于 R2）

### 桌面端特性
- **Bitsdojo Window** - 自定义窗口样式
- **Flutter Acrylic** - 亚克力/毛玻璃效果

### 其他
- **Flutter Lyric** - 歌词解析和显示
- **HTML Parser** - HTML 解析

## 🚀 快速开始

### 环境要求

- **Flutter SDK**: 3.0.0 或更高版本
- **Dart SDK**: 3.0.0 或更高版本
- **Android Studio** / **VS Code**（推荐安装 Flutter 插件）

**平台特定要求：**
- **Windows**: Visual Studio 2022（包含 C++ 桌面开发组件）
- **Android**: Android SDK（API 21+）
- **Web**: Chrome 浏览器

### 安装步骤

1. **克隆项目**
```bash
git clone <repository-url>
cd haiMusic
```

2. **安装依赖**
```bash
flutter pub get
```

3. **运行应用**

```bash
# Windows 桌面端
flutter run -d windows
# 或使用批处理文件
run_windows.bat

# Android 端（需连接设备或启动模拟器）
flutter run -d android
# 或使用批处理文件
run_android.bat

# Web 端
flutter run -d chrome
# 或使用批处理文件
run_web.bat
```

## 📦 构建发布

### Windows 应用

```bash
flutter build windows --release
```

产物位置：`build\windows\x64\runner\Release\`

### Android APK

```bash
# 标准构建
flutter build apk --release

# 按 ABI 拆分（减小体积）
flutter build apk --release --split-per-abi
```

产物位置：`build\app\outputs\flutter-apk\`

### Web 应用

```bash
flutter build web --release
```

产物位置：`build\web\`

## ⚙️ 配置说明

### 云端同步配置

如需启用云端同步功能，请参考详细配置指南：

📖 **[云端同步配置指南](docs/CLOUD_SYNC_GUIDE.md)**

主要步骤：
1. 创建 Supabase 项目并执行 `docs/SETUP_DATABASE.sql`
2. 创建 Cloudflare R2 存储桶并获取 API 密钥
3. 在应用内"音乐库"页面点击云朵图标进行配置

### 应用图标更新

如需自定义应用图标，请参考：

📖 **[图标更新指南](docs/UPDATE_ICON_GUIDE.md)**

## 📁 项目结构

```
lib/
├── config/                   # 应用配置
│   └── app_constants.dart    # 常量定义（API、缓存、播放配置等）
├── extensions/               # Dart 扩展
│   ├── duration_extension.dart
│   ├── favorite_song_extension.dart
│   └── ...
├── models/                   # 数据模型
│   ├── song.dart             # 歌曲模型
│   ├── favorite_song.dart    # 收藏歌曲模型
│   ├── play_history.dart     # 播放历史模型
│   ├── audio_quality.dart    # 音质配置
│   └── ...
├── providers/                # 状态管理
│   ├── music_provider.dart   # 音乐播放状态
│   └── theme_provider.dart   # 主题状态
├── screens/                  # 页面
│   ├── home_screen.dart      # 主页（导航框架）
│   ├── discover_screen.dart  # 发现页
│   ├── search_screen.dart    # 搜索页
│   ├── library_screen.dart   # 音乐库
│   ├── favorites_screen.dart # 我喜欢
│   ├── recent_play_screen.dart # 最近播放
│   ├── playlist_detail_screen.dart # 歌单详情
│   ├── player_screen.dart    # 播放器页面
│   ├── storage_config_screen.dart # 云存储配置
│   └── debug_log_screen.dart # 调试日志
├── services/                 # 业务服务
│   ├── music_api_service.dart # 音乐 API 接口
│   ├── audio_handler_service.dart # 音频播放处理
│   ├── favorite_manager_service.dart # 收藏管理
│   ├── play_history_service.dart # 播放历史
│   ├── supabase_service.dart # Supabase 数据库
│   ├── r2_storage_service.dart # R2 对象存储
│   ├── cache_manager_service.dart # 缓存管理
│   ├── lyrics_service.dart   # 歌词服务
│   ├── keyboard_shortcut_service.dart # 键盘快捷键
│   ├── sleep_timer_service.dart # 睡眠定时器
│   └── ...
├── theme/                    # 主题样式
│   └── app_styles.dart       # 应用样式定义
├── utils/                    # 工具类
│   ├── platform_utils.dart   # 平台判断
│   ├── responsive.dart       # 响应式布局
│   ├── logger.dart           # 日志工具
│   ├── error_handler.dart    # 错误处理
│   └── cache_utils.dart      # 缓存工具
├── widgets/                  # 可复用组件
│   ├── mini_player.dart      # 迷你播放器
│   ├── song_card.dart        # 歌曲卡片
│   ├── playlist_card.dart    # 歌单卡片
│   ├── theme_selector.dart   # 主题选择器
│   ├── audio_quality_selector.dart # 音质选择器
│   └── draggable_window_area.dart # 可拖拽窗口区域
└── main.dart                 # 应用入口
```

## 💡 使用说明

### 搜索和播放音乐
1. 打开应用，进入"搜索"页面
2. 输入歌曲名或歌手名
3. 点击搜索结果中的歌曲即可播放
4. 使用底部迷你播放器控制播放
5. 点击迷你播放器可展开完整播放页面

### 收藏歌曲
1. 播放任意歌曲
2. 点击播放器或迷你播放器上的 ❤️ 图标
3. 歌曲将自动添加到"我喜欢"列表
4. 如启用云同步，将自动下载并上传到云端

### 查看收藏
1. 进入"音乐库"页面
2. 点击"❤️ 我喜欢"卡片
3. 查看所有收藏的歌曲
4. 点击"播放全部"可播放所有收藏

### 导入 QQ 音乐歌单
1. 进入"音乐库"页面
2. 首次使用会提示输入 QQ 号
3. 输入后自动加载该 QQ 号的歌单
4. 点击歌单卡片查看和播放歌单内容

### 定时关闭
1. 在播放页面点击右上角菜单（三个点）
2. 选择"定时关闭"
3. 选择时长（15/30/45/60/90 分钟）
4. 到时间后自动暂停播放

### 清理缓存
1. 进入"音乐库"页面
2. 向下滚动找到"缓存管理"区域
3. 查看当前缓存大小
4. 点击"清理缓存"按钮清空缓存

## 🔧 本地存储

应用数据存储位置：

- **Windows**: `C:\Users\<用户名>\Documents\music\`
- **Android**: `/data/data/com.example.hai_music/files/music/`

目录结构：
```
music/
├── audio/          # 音频文件缓存
│   └── <songId>.mp3
└── covers/         # 封面图片缓存
    └── <songId>.jpg
```

## ❓ 常见问题

### 无法播放音乐？
- 检查网络连接是否正常
- 确认音乐 API 服务可访问
- 尝试切换音质后重新播放

### Android 构建缓慢？
- 首次构建需要下载依赖，耗时较长属正常现象
- 后续构建会利用 Gradle 缓存，速度会显著提升
- 可以使用 `--split-per-abi` 参数减小 APK 体积

### Windows 应用图标未更新？
- 确保已替换 `windows/runner/resources/app_icon.ico`
- 重新执行 `flutter build windows --release`
- 清理构建缓存：`flutter clean`

### 云同步无法使用？
- 检查 Supabase 和 R2 配置是否正确
- 确认网络连接正常
- 查看应用日志获取详细错误信息

## 🗺️ 开发路线

**已完成功能：**
- [x] 基础音乐播放功能（播放/暂停/上下曲/进度/音量）
- [x] 在线搜索（腾讯音乐 API）
- [x] 播放模式（顺序/单曲循环/随机）
- [x] 音质选择（标准/HQ/臻品母带）
- [x] 收藏管理和本地存储
- [x] 云端同步（Supabase + Cloudflare R2）
- [x] 最近播放历史（最多 50 条）
- [x] 缓存管理和清理
- [x] 主题切换（浅色/深色）
- [x] 歌词显示（LRC 格式）
- [x] 键盘快捷键（桌面端）
- [x] 定时关闭（15/30/45/60/90 分钟）
- [x] 响应式布局（桌面/移动端自适应）
- [x] 每日推荐和推荐歌单
- [x] QQ 音乐歌单导入
- [x] 后台播放（Android）
- [x] 毛玻璃效果和现代化 UI


## 📄 开源协议

本项目采用 MIT 协议开源，详见 LICENSE 文件。

## 🙏 鸣谢

感谢以下开源项目：
- Flutter 团队及社区
- 所有依赖包的开发者
- 音乐 API 提供方

---

**注意**：本应用仅供学习交流使用，请勿用于商业用途。音乐版权归原作者所有。
