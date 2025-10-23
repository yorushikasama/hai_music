# 应用图标更新指南

本文档说明如何更新 Hai Music 应用的图标。

## 📋 准备工作

### 1. 准备图标文件

在 `logo/` 目录下准备以下文件：

- **logo.png** - PNG 格式，建议尺寸 1024x1024 像素
- **logo.ico** - ICO 格式，包含多个尺寸（16x16, 32x32, 48x48, 256x256）

### 2. 图标设计建议

- 简洁现代的设计
- 使用应用主题色
- 音乐相关元素（音符、耳机、播放按钮等）
- 背景可以是透明或纯色

---

## 🪟 更新 Windows 图标

### 步骤 1：复制图标文件

```powershell
Copy-Item -Path logo\logo.ico -Destination windows\runner\resources\app_icon.ico -Force
```

### 步骤 2：清理构建缓存

```powershell
Remove-Item -Path build\windows -Recurse -Force
```

或者使用：

```powershell
flutter clean
```

### 步骤 3：重新构建

```powershell
flutter build windows --release
```

### 步骤 4：验证图标

构建完成后，检查：
- 文件位置：`build\windows\x64\runner\Release\hai_music.exe`
- 右键点击 → 属性 → 查看图标

**注意**：如果图标显示还是旧的，可能是 Windows 资源管理器缓存问题，重启资源管理器即可。

---

## 📱 更新 Android 图标

### 步骤 1：确保配置正确

检查 `pubspec.yaml` 中的配置：

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: false
  image_path: "logo/logo.png"
  adaptive_icon_background: "#191919"
  adaptive_icon_foreground: "logo/logo.png"
  min_sdk_android: 21
```

### 步骤 2：安装依赖

```powershell
flutter pub get
```

### 步骤 3：生成图标

```powershell
flutter pub run flutter_launcher_icons
```

这会自动生成以下文件：
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` (48x48)
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` (72x72)
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` (96x96)
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` (144x144)
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (192x192)

### 步骤 4：清理构建缓存

```powershell
flutter clean
```

### 步骤 5：重新构建 APK

```powershell
flutter build apk --release
```

### 步骤 6：验证图标

**重要**：APK 文件在 Windows 资源管理器中显示的图标不是应用真正的图标！

要验证图标是否更新：
1. 将 APK 安装到 Android 设备
2. 查看桌面上的应用图标
3. 或在应用列表中查看

---

## 🔧 常见问题

### 问题 1：Windows 图标没有更新

**原因**：Windows 缓存了旧图标

**解决方案**：
1. 删除 `build\windows` 目录
2. 运行 `flutter clean`
3. 重新构建
4. 如果还是旧的，重启资源管理器或重启电脑

### 问题 2：Android 构建失败（文件被占用）

**错误信息**：
```
java.nio.file.FileSystemException: 另一个程序正在使用此文件
```

**解决方案**：
```powershell
# 结束所有 Java 进程
taskkill /F /IM java.exe

# 等待几秒
Start-Sleep -Seconds 10

# 重新构建
flutter build apk
```

### 问题 3：Android 图标生成失败

**解决方案**：
1. 确保 `logo/logo.png` 文件存在且格式正确
2. 检查 `pubspec.yaml` 配置
3. 删除 `android/app/src/main/res/mipmap-*` 目录
4. 重新运行 `flutter pub run flutter_launcher_icons`

### 问题 4：APK 文件图标不对

**说明**：这是正常的！APK 文件在 Windows 上的图标由系统决定，不是应用真正的图标。

**验证方法**：安装到 Android 设备后查看桌面图标。

---

## 📦 完整更新流程

### 一键更新所有平台图标

```powershell
# 1. 复制 Windows 图标
Copy-Item -Path logo\logo.ico -Destination windows\runner\resources\app_icon.ico -Force

# 2. 生成 Android 图标
flutter pub get
flutter pub run flutter_launcher_icons

# 3. 清理缓存
flutter clean

# 4. 构建 Windows
flutter build windows --release

# 5. 构建 Android（可选：结束 Java 进程避免文件占用）
taskkill /F /IM java.exe 2>$null
Start-Sleep -Seconds 5
flutter build apk --release
```

---

## 📂 文件位置

### 源文件
- `logo/logo.png` - Android 图标源文件
- `logo/logo.ico` - Windows 图标源文件

### Windows
- `windows/runner/resources/app_icon.ico` - Windows 图标
- `build/windows/x64/runner/Release/hai_music.exe` - 构建产物

### Android
- `android/app/src/main/res/mipmap-*/ic_launcher.png` - 各密度图标
- `build/app/outputs/flutter-apk/app-release.apk` - 构建产物

---

## 🎨 图标设计工具推荐

### 在线工具
- **ICO 转换**：https://www.icoconverter.com/
- **图标生成**：https://icon.kitchen/
- **图标编辑**：https://www.photopea.com/

### 桌面工具
- **Photoshop** - 专业图像编辑
- **GIMP** - 免费开源图像编辑
- **Figma** - 在线设计工具

---

## ✅ 检查清单

更新图标前，确保：

- [ ] 准备了 1024x1024 的 PNG 图标
- [ ] 准备了包含多尺寸的 ICO 图标
- [ ] 图标设计清晰，在小尺寸下也能识别
- [ ] 已安装 `flutter_launcher_icons` 插件
- [ ] `pubspec.yaml` 配置正确

更新图标后，验证：

- [ ] Windows exe 文件图标已更新
- [ ] Android APK 安装后桌面图标已更新
- [ ] 图标在不同密度屏幕上显示正常
- [ ] 图标在深色/浅色主题下都清晰可见

---

## 📝 注意事项

1. **Windows 图标缓存**：Windows 会缓存图标，如果更新后看不到新图标，尝试重启资源管理器或重启电脑。

2. **Android 图标验证**：不要通过 APK 文件图标判断，必须安装到设备后查看。

3. **构建缓存**：更新图标后建议运行 `flutter clean` 清理缓存。

4. **文件占用**：Android 构建时如果遇到文件占用错误，结束 Java 进程即可。

5. **图标尺寸**：确保原图足够大（建议 1024x1024），避免缩小后模糊。

6. **自适应图标**：Android 会根据设备自动裁剪图标为圆形、方形等，设计时注意重要元素不要太靠边缘。

---

## 🔗 相关文档

- [Flutter 官方文档 - 应用图标](https://docs.flutter.dev/deployment/android#adding-a-launcher-icon)
- [flutter_launcher_icons 插件](https://pub.dev/packages/flutter_launcher_icons)
- [Android 图标设计指南](https://developer.android.com/guide/practices/ui_guidelines/icon_design_launcher)

---

**最后更新时间**：2025年10月23日
