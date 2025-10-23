# 云端同步配置指南

## 功能说明

本应用支持将收藏的音乐持久化到云端，包括：
- **Supabase 数据库**：存储歌曲元数据（标题、艺术家、专辑等）
- **Cloudflare R2 对象存储**：存储音频文件和封面图片

当您点击收藏按钮时，歌曲会：
1. 添加到本地收藏列表
2. 下载音频和封面到本地
3. 上传到 Cloudflare R2 存储
4. 元数据保存到 Supabase 数据库

## 配置步骤

### 1. Supabase 配置

#### 1.1 创建 Supabase 项目
1. 访问 [Supabase](https://supabase.com/)
2. 注册并登录
3. 创建新项目
4. 记录项目的 **URL** 和 **anon key**

#### 1.2 创建数据表

**执行步骤：**

1. 打开项目根目录的 `SETUP_DATABASE.sql` 文件
2. 复制全部内容
3. 在 Supabase Dashboard 中：
   - 左侧菜单点击 **SQL Editor**
   - 点击 **New Query**
   - 粘贴 SQL 内容
   - 点击 **Run** 执行

**说明：**
- SQL 脚本会自动创建所需的所有表和索引
- 包含收藏歌曲表、歌词表及相关安全策略
- 如果表已存在，会先删除旧表（注意备份数据）

### 2. Cloudflare R2 配置

#### 2.1 创建 R2 存储桶
1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 选择 **R2** 服务
3. 点击 **创建存储桶**
4. 输入存储桶名称（例如：`my-music-bucket`）
5. 选择区域（建议选择离您最近的区域）

#### 2.2 生成 API 令牌
1. 在 R2 页面，点击 **管理 R2 API 令牌**
2. 点击 **创建 API 令牌**
3. 设置权限：
   - 对象读取
   - 对象写入
4. 记录生成的：
   - **Access Key ID**
   - **Secret Access Key**
   - **Endpoint URL**（格式：`https://xxx.r2.cloudflarestorage.com`）

#### 2.3 配置 CORS（可选）
如果需要从 Web 端访问，需要配置 CORS：

```json
[
  {
    "AllowedOrigins": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
```

### 3. 应用内配置

1. 打开应用
2. 进入 **音乐库** 页面
3. 点击右上角的 **☁️ 云朵图标**
4. 填写配置信息：
   - **Supabase URL**：您的 Supabase 项目 URL
   - **Supabase Anon Key**：您的 Supabase anon key
   - **R2 Endpoint**：您的 R2 endpoint URL
   - **Access Key ID**：R2 API 令牌的 Access Key
   - **Secret Access Key**：R2 API 令牌的 Secret Key
   - **Bucket 名称**：您创建的存储桶名称
   - **Region**：默认为 `auto`
5. 开启 **启用云端同步** 开关
6. 点击 **保存**

## 使用说明

### 收藏歌曲
1. 播放任意歌曲
2. 点击迷你播放器或播放页面的 **❤️ 爱心按钮**
3. 应用会自动：
   - 添加到本地收藏列表
   - 下载音频文件到本地（如果启用云端同步）
   - 下载封面图片到本地（如果启用云端同步）
   - 上传到 R2 存储（如果启用云端同步）
   - 保存元数据到 Supabase（如果启用云端同步）

### 查看我喜欢的歌曲
1. 进入 **音乐库** 页面
2. 点击 **❤️ 我喜欢** 卡片
3. 查看所有收藏的歌曲列表
4. 支持功能：
   - 点击歌曲播放
   - 点击"播放全部"按钮播放所有收藏
   - 点击爱心取消收藏
   - 下拉刷新列表

### 取消收藏
**方式一：在播放器中**
1. 再次点击爱心按钮
2. 歌曲从收藏列表移除

**方式二：在我喜欢列表中**
1. 进入"我喜欢"页面
2. 点击歌曲右侧的爱心按钮
3. 应用会自动：
   - 从本地收藏列表移除
   - 从 Supabase 删除记录（如果启用云端同步）
   - 从 R2 删除文件（如果启用云端同步）
   - 删除本地缓存文件

### 云端同步说明
- **未启用云端同步**：收藏仅保存在本地，重装应用后会丢失
- **已启用云端同步**：收藏会自动同步到 Supabase 和 R2，数据永久保存

## 本地存储路径

应用会将文件存储在以下位置：
- **Windows**: `C:\Users\<用户名>\Documents\music\`
- **Android**: `/data/data/com.example.hai_music/files/music/`
- **iOS**: `<应用沙盒>/Documents/music/`

目录结构：
```
music/
├── audio/          # 音频文件
│   ├── <songId>.mp3
│   └── ...
└── covers/         # 封面图片
    ├── <songId>.jpg
    └── ...
```

## 注意事项

1. **存储空间**：
   - 确保 R2 存储桶有足够空间
   - 每首歌曲约占用 5-10 MB

2. **网络流量**：
   - 首次收藏会下载完整音频文件
   - 建议在 WiFi 环境下使用

3. **安全性**：
   - API 密钥存储在本地加密
   - 建议定期更换 API 令牌
   - 不要分享您的配置信息

4. **费用**：
   - Supabase 免费套餐：500MB 数据库 + 1GB 文件存储
   - Cloudflare R2 免费套餐：10GB 存储 + 每月 1000 万次读取

5. **同步限制**：
   - 仅在启用云端同步时生效
   - 关闭同步后，收藏仅保存在本地

## 故障排除

### 无法连接到 Supabase
- 检查 URL 和 Anon Key 是否正确
- 确认网络连接正常
- 检查 Supabase 项目是否暂停

### 无法上传到 R2
- 检查 API 令牌权限
- 确认存储桶名称正确
- 检查 Endpoint URL 格式

### 收藏后找不到文件
- 检查本地存储权限
- 查看应用日志获取详细错误信息

## 技术架构

```
┌─────────────┐
│   Flutter   │
│     App     │
└──────┬──────┘
       │
       ├──────────────┐
       │              │
       ▼              ▼
┌─────────────┐  ┌─────────────┐
│  Supabase   │  │ Cloudflare  │
│  Database   │  │     R2      │
│  (元数据)    │  │  (文件存储)  │
└─────────────┘  └─────────────┘
```

## 开发者信息

- **数据库服务**: `lib/services/supabase_service.dart`
- **存储服务**: `lib/services/r2_storage_service.dart`
- **收藏管理**: `lib/services/favorite_manager_service.dart`
- **配置界面**: `lib/screens/storage_config_screen.dart`

## 更新日志

### v1.0.0
- ✅ 支持 Supabase 数据库存储
- ✅ 支持 Cloudflare R2 对象存储
- ✅ 自动下载和上传音频文件
- ✅ 自动下载和上传封面图片
- ✅ 可配置化的云端同步
- ✅ 本地缓存机制
