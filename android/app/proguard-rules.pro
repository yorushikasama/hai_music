# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Audio Service & Just Audio
-keep class com.google.android.exoplayer2.** { *; }
-keep class xyz.xdnm.beautifulaudio.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Audio Metadata Reader
-keep class org.jaudiotagger.** { *; }
-dontwarn org.jaudiotagger.**

# Supabase
-keep class io.supabase.** { *; }
-keep class com.google.** { *; }
-dontwarn io.supabase.**
-dontwarn com.google.**

# Provider
-keep class androidx.lifecycle.** { *; }
-keep class androidx.arch.core.** { *; }

# SharedPreferences
-keep class androidx.preference.** { *; }

# MinIO (对象存储)
-keep class io.minio.** { *; }
-dontwarn io.minio.**
-dontwarn org.conscrypt.**
-dontwarn org.codehaus.mojo.**
-dontwarn org.slf4j.**
-dontwarn okhttp3.**
-dontwarn okio.**

# OkHttp & Okio
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Dio (网络库)
-keep class io.dio.** { *; }
-dontwarn io.dio.**

# Cached Network Image
-keep class com.bumptech.glide.** { *; }
-keep class com.bumptech.glide.load.engine.** { *; }
-dontwarn com.bumptech.glide.**

# Google Fonts
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# On Audio Query (本地音频查询)
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }

# 保持 Native 方法
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保持 JavaScript 接口
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# 保持你的应用包名
-keep class com.example.hai_music.** { *; }
-keepclassmembers class com.example.hai_music.** { *; }

# 模型类不混淆（用于 JSON 序列化）
-keep class com.example.hai_music.models.** { *; }
-keepclassmembers class com.example.hai_music.models.** { *; }
