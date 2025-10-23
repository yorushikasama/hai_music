# Hai Music

跨平台音乐播放器，支持 Windows、Android（可拓展到 Web）。内置收藏、云同步、最近播放与缓存管理，界面简洁现代。

## 功能特性

- **[播放]** 播放/暂停/上一首/下一首，进度、音量与播放模式（顺序/单曲/随机）
- **[收藏]** 一键收藏/取消收藏，支持本地与云端同步
- **[云同步]** 对接 Supabase + Cloudflare R2，同步封面与音频文件
- **[最近播放]** 自动记录最近播放历史，可清空、删除单条
- **[歌单]** 歌单详情与播放（歌单条目默认不显示时长）
- **[缓存]** 一键清理音频与封面缓存，查看缓存大小
- **[UI]** 现代化卡片、毛玻璃与阴影，支持浅/深色主题

## 技术栈

- Flutter 3 / Dart 3
- Provider（状态管理）
- Supabase（Postgres + 存储/接口）
- Cloudflare R2（对象存储）
- Dio / http（网络）

## 快速开始

### 环境要求

- Flutter SDK 3.0+
- Dart 3.0+
- Android SDK（Android 构建）
- Visual Studio（Windows 构建，含 C++ 桌面开发组件）

### 安装依赖

```bash
flutter pub get
```

### 运行

```bash
# Windows
flutter run -d windows

# Android（连接设备或启动模拟器）
flutter run -d android
```

## 构建与发布

```bash
# Windows Release
flutter build windows --release

# Android Release APK
flutter build apk --release

# 可选：按 ABI 拆分，减小体积
flutter build apk --release --split-per-abi
```

产物位置：
- Windows：`build/windows/x64/runner/Release/hai_music.exe`
- Android：`build/app/outputs/flutter-apk/app-release.apk`

## 云同步配置

应用支持“收藏同步到云端”，需要先完成云端配置。详见：`CLOUD_SYNC_GUIDE.md`

- 数据库脚本：`SETUP_DATABASE.sql`
- 建议单用户先关闭 RLS；多用户开启 RLS 并配置策略

## 图标更新

提供完整的图标更新操作手册，包含 Windows 与 Android：`UPDATE_ICON_GUIDE.md`

要点：
- Windows：替换 `windows/runner/resources/app_icon.ico` 并重新构建
- Android：使用 `flutter_launcher_icons` 生成 `mipmap-*/ic_launcher.png`

## 缓存与存储

- 音频缓存：`<AppDocDir>/music/audio/`
- 封面缓存：`<AppDocDir>/music/covers/`
- 设置页面提供“一键清理缓存”入口

## 常见问题（FAQ）

- **APK 图标看起来没变？** Windows 资源管理器不会显示 APK 内部图标，请安装到 Android 设备查看桌面图标。
- **Android 构建慢？** 已启用 Gradle Daemon/缓存/并行。首次构建较慢属正常，后续会显著加速。
- **R8/文件占用错误？** 结束 `java.exe` 进程后重试：`taskkill /F /IM java.exe`。

## 目录结构

```
lib/
├── main.dart                 # 应用入口
├── models/                   # 数据模型（歌曲、收藏、播放历史等）
├── providers/                # 全局状态（播放、主题、收藏）
├── screens/                  # 页面（发现、歌单、我喜欢、最近播放等）
├── services/                 # 业务服务（云同步、R2、Supabase、缓存、API）
├── theme/                    # 主题与样式
└── widgets/                  # 复用组件
```

## Roadmap

- [x] 收藏与云同步（Supabase + R2）
- [x] 最近播放与清空
- [x] 缓存清理与容量统计
- [x] 现代化 UI/UX（卡片、阴影、渐变按钮）
- [ ] 更多平台支持（Web/iOS）
- [ ] 歌词增强与滚动优化

## 许可与鸣谢

- 依赖与插件见 `pubspec.yaml`
- 如用于二次开发，请保留原始版权信息
