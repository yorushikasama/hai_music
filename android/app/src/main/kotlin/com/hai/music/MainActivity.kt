package com.hai.music

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentSender
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.hai.music/media"
    private var pendingDeleteResult: MethodChannel.Result? = null
    private var pendingDeleteUris: List<Uri> = emptyList()
    private var pendingDeletePaths: List<String> = emptyList()

    companion object {
        private const val REQUEST_DELETE_FILES = 1001
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return AudioServicePlugin.getFlutterEngine(context)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanFile" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            handleScanFile(path, result)
                        } else {
                            result.error("INVALID_ARGS", "path is required", null)
                        }
                    }
                    "deleteFile" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            handleDeleteFile(path, result)
                        } else {
                            result.error("INVALID_ARGS", "path is required", null)
                        }
                    }
                    "deleteFiles" -> {
                        val paths = call.argument<List<String>>("paths")
                        if (paths != null) {
                            handleDeleteFiles(paths, result)
                        } else {
                            result.error("INVALID_ARGS", "paths is required", null)
                        }
                    }
                    "checkManageStoragePermission" -> {
                        handleCheckManageStoragePermission(result)
                    }
                    "requestManageStoragePermission" -> {
                        handleRequestManageStoragePermission(result)
                    }
                    "extractCover" -> {
                        val path = call.argument<String>("path")
                        val savePath = call.argument<String>("savePath")
                        if (path != null && savePath != null) {
                            handleExtractCover(path, savePath, result)
                        } else {
                            result.error("INVALID_ARGS", "path and savePath are required", null)
                        }
                    }
                    "getMetadata" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            handleGetMetadata(path, result)
                        } else {
                            result.error("INVALID_ARGS", "path is required", null)
                        }
                    }
                    "saveFile" -> {
                        val targetPath = call.argument<String>("targetPath")
                        val bytes = call.argument<ByteArray>("bytes")
                        if (targetPath != null && bytes != null) {
                            handleSaveFile(targetPath, bytes, result)
                        } else {
                            result.error("INVALID_ARGS", "targetPath and bytes are required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_DELETE_FILES) {
            return
        }

        val result = pendingDeleteResult
        val uris = pendingDeleteUris
        val paths = pendingDeletePaths

        pendingDeleteResult = null
        pendingDeleteUris = emptyList()
        pendingDeletePaths = emptyList()

        if (result == null) {
            return
        }

        if (resultCode != Activity.RESULT_OK) {
            Log.w("HaiMusic", "Delete request cancelled by user")
            result.success(false)
            return
        }

        try {
            var deletedCount = 0
            for (uri in uris) {
                deletedCount += contentResolver.delete(uri, null, null)
            }

            if (paths.isNotEmpty()) {
                MediaScannerConnection.scanFile(this, paths.toTypedArray(), null, null)
            }

            val success = deletedCount > 0 && deletedCount == uris.size
            Log.i("HaiMusic", "Delete request completed: $deletedCount/${uris.size}")
            result.success(success)
        } catch (e: Exception) {
            Log.e("HaiMusic", "Delete request follow-up failed", e)
            result.error("DELETE_FAILED", e.message, null)
        }
    }

    private fun handleScanFile(path: String, result: MethodChannel.Result) {
        try {
            MediaScannerConnection.scanFile(
                this,
                arrayOf(path),
                null
            ) { _, _ ->
                runOnUiThread {
                    result.success(true)
                }
            }
        } catch (e: Exception) {
            result.error("SCAN_FAILED", e.message, null)
        }
    }

    private fun handleCheckManageStoragePermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            result.success(Environment.isExternalStorageManager())
        } else {
            result.success(true)
        }
    }

    private fun handleRequestManageStoragePermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (Environment.isExternalStorageManager()) {
                result.success(true)
                return
            }
            try {
                val intent = Intent(
                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivity(intent)
                result.success(false) // 需要用户手动授权，返回 false 表示尚未授权
            } catch (e: Exception) {
                Log.e("HaiMusic", "Failed to launch manage storage settings", e)
                // 回退到通用设置页面
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    startActivity(intent)
                    result.success(false)
                } catch (e2: Exception) {
                    result.error("SETTINGS_FAILED", e2.message, null)
                }
            }
        } else {
            result.success(true)
        }
    }

    private fun hasManageStoragePermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.R || Environment.isExternalStorageManager()
    }

    private fun handleDeleteFile(path: String, result: MethodChannel.Result) {
        try {
            val file = File(path)

            // 拥有管理存储权限时，直接 File.delete()，无需 MediaStore 权限请求
            if (hasManageStoragePermission()) {
                if (!file.exists() || file.delete()) {
                    MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
                    Log.i("HaiMusic", "File.delete() succeeded (manage storage): $path")
                    result.success(true)
                    return
                }
                Log.w("HaiMusic", "File.delete() failed even with manage storage: $path")
                result.success(false)
                return
            }

            // 无管理存储权限时，回退到 MediaStore 方式
            if (file.exists() && file.delete()) {
                MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
                Log.i("HaiMusic", "File.delete() succeeded: $path")
                result.success(true)
                return
            }

            var uri = findMediaStoreUri(path)
            // 如果文件不在 MediaStore 中，尝试注册
            if (uri == null && file.exists()) {
                uri = registerFileToMediaStore(path)
            }
            if (uri != null) {
                try {
                    val deleted = contentResolver.delete(uri, null, null)
                    if (deleted > 0) {
                        MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
                        Log.i("HaiMusic", "ContentResolver.delete succeeded: $uri")
                        result.success(true)
                        return
                    }
                } catch (e: SecurityException) {
                    Log.w("HaiMusic", "ContentResolver.delete failed (permission): ${e.message}")
                    if (requestDeletePermission(listOf(uri), listOf(path), result)) {
                        return
                    }
                }
            }

            Log.w("HaiMusic", "Delete failed: $path")
            result.success(false)
        } catch (e: Exception) {
            Log.e("HaiMusic", "Delete failed with exception: $path", e)
            result.error("DELETE_FAILED", e.message, null)
        }
    }

    private fun handleDeleteFiles(paths: List<String>, result: MethodChannel.Result) {
        try {
            val deletedPaths = mutableListOf<String>()
            val failedPaths = mutableListOf<String>()

            // 拥有管理存储权限时，全部使用 File.delete()
            if (hasManageStoragePermission()) {
                for (path in paths) {
                    val file = File(path)
                    if (!file.exists() || file.delete()) {
                        deletedPaths.add(path)
                    } else {
                        failedPaths.add(path)
                        Log.w("HaiMusic", "File.delete() failed (manage storage): $path")
                    }
                }
                if (deletedPaths.isNotEmpty()) {
                    MediaScannerConnection.scanFile(this, deletedPaths.toTypedArray(), null, null)
                }
                val success = failedPaths.isEmpty()
                Log.i("HaiMusic", "Batch delete (manage storage): ${deletedPaths.size}/${paths.size} succeeded")
                result.success(success)
                return
            }

            // 无管理存储权限时，回退到 MediaStore 方式
            val permissionRequiredUris = mutableListOf<Uri>()
            val permissionRequiredPaths = mutableListOf<String>()
            val writePermissionRequiredPaths = mutableListOf<String>()

            for (path in paths) {
                val file = File(path)
                if (!file.exists()) {
                    deletedPaths.add(path)
                    continue
                }

                if (file.delete()) {
                    deletedPaths.add(path)
                    continue
                }

                val uri = findMediaStoreUri(path)
                if (uri != null) {
                    try {
                        val deleted = contentResolver.delete(uri, null, null)
                        if (deleted > 0) {
                            deletedPaths.add(path)
                            continue
                        }
                    } catch (e: SecurityException) {
                        Log.w("HaiMusic", "ContentResolver.delete failed: $path, ${e.message}")
                        permissionRequiredUris.add(uri)
                        permissionRequiredPaths.add(path)
                        continue
                    }
                } else {
                    writePermissionRequiredPaths.add(path)
                }
            }

            if (deletedPaths.isNotEmpty()) {
                MediaScannerConnection.scanFile(
                    this, deletedPaths.toTypedArray(), null, null
                )
            }

            for (path in writePermissionRequiredPaths) {
                val scanUri = registerFileToMediaStore(path)
                if (scanUri != null) {
                    permissionRequiredUris.add(scanUri)
                    permissionRequiredPaths.add(path)
                } else {
                    failedPaths.add(path)
                }
            }

            if (permissionRequiredUris.isNotEmpty()) {
                if (requestDeletePermission(permissionRequiredUris, permissionRequiredPaths, result)) {
                    return
                }
                failedPaths.addAll(permissionRequiredPaths)
            }

            if (failedPaths.isEmpty()) {
                Log.i("HaiMusic", "Batch delete completed: ${deletedPaths.size}/${paths.size} succeeded")
                result.success(true)
            } else {
                Log.w("HaiMusic", "Batch delete partial: ${deletedPaths.size}/${paths.size} succeeded, ${failedPaths.size} failed")
                result.success(deletedPaths.size == paths.size)
            }
        } catch (e: Exception) {
            Log.e("HaiMusic", "Batch delete failed with exception", e)
            result.error("DELETE_FAILED", e.message, null)
        }
    }

    /**
     * 将不在 MediaStore 中的文件注册到 MediaStore，以便获取 URI 进行权限请求。
     * 通过 MediaScannerConnection 触发系统扫描，让 MediaStore 索引已存在的文件。
     * 主要用于 .lrc 等非音频/图片文件，这些文件下载后可能未被 MediaStore 索引。
     * 注意：此方法会在后台线程执行扫描等待，避免主线程死锁。
     */
    private fun registerFileToMediaStore(path: String): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return null
        }
        try {
            val file = File(path)
            if (!file.exists()) return null

            // 先检查是否已存在
            val existingUri = findMediaStoreUri(path)
            if (existingUri != null) return existingUri

            // 在后台线程执行扫描等待，避免主线程死锁
            val future = java.util.concurrent.CompletableFuture<Uri?>()
            thread {
                try {
                    val latch = java.util.concurrent.CountDownLatch(1)
                    MediaScannerConnection.scanFile(this, arrayOf(path), null) { _, _ ->
                        latch.countDown()
                    }
                    // 等待扫描完成（最多2秒）
                    latch.await(2, java.util.concurrent.TimeUnit.SECONDS)

                    // 再次查询
                    val uri = findMediaStoreUri(path)
                    if (uri != null) {
                        Log.i("HaiMusic", "Registered file to MediaStore via scan: $path -> $uri")
                    } else {
                        Log.w("HaiMusic", "File still not in MediaStore after scan: $path")
                    }
                    future.complete(uri)
                } catch (e: Exception) {
                    Log.w("HaiMusic", "registerFileToMediaStore failed: $path, ${e.message}")
                    future.complete(null)
                }
            }
            // 等待结果（最多3秒）
            return future.get(3, java.util.concurrent.TimeUnit.SECONDS)
        } catch (e: Exception) {
            Log.w("HaiMusic", "Failed to register file to MediaStore: $path, ${e.message}")
            return null
        }
    }

    private fun findMediaStoreUri(path: String): Uri? {
        val audioId = queryMediaStoreAudioId(path)
        if (audioId != null) {
            return MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                .buildUpon()
                .appendPath(audioId.toString())
                .build()
        }
        val filesId = queryMediaStoreFilesId(path)
        if (filesId != null) {
            return MediaStore.Files.getContentUri("external")
                .buildUpon()
                .appendPath(filesId.toString())
                .build()
        }
        return null
    }

    private fun queryMediaStoreAudioId(path: String): Long? {
        try {
            val resolver = contentResolver
            val uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            val projection = arrayOf(MediaStore.Audio.Media._ID)
            val selection = "${MediaStore.Audio.Media.DATA} = ?"
            val selectionArgs = arrayOf(path)
            resolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                    return cursor.getLong(idColumn)
                }
            }
        } catch (e: Exception) {
            Log.w("HaiMusic", "Query MediaStore.Audio failed: ${e.message}")
        }
        return null
    }

    private fun queryMediaStoreFilesId(path: String): Long? {
        try {
            val resolver = contentResolver
            val uri = MediaStore.Files.getContentUri("external")
            val projection = arrayOf(MediaStore.Files.FileColumns._ID)
            val selection = "${MediaStore.Files.FileColumns.DATA} = ?"
            val selectionArgs = arrayOf(path)
            resolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
                    return cursor.getLong(idColumn)
                }
            }
        } catch (e: Exception) {
            Log.w("HaiMusic", "Query MediaStore.Files failed: ${e.message}")
        }
        return null
    }

    private fun requestDeletePermission(
        uris: List<Uri>,
        paths: List<String>,
        result: MethodChannel.Result
    ): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || uris.isEmpty()) {
            return false
        }

        return try {
            val sender = MediaStore.createDeleteRequest(contentResolver, uris).intentSender
            pendingDeleteResult = result
            pendingDeleteUris = uris
            pendingDeletePaths = paths
            startIntentSenderForResult(
                sender,
                REQUEST_DELETE_FILES,
                null,
                0,
                0,
                0,
                null
            )
            true
        } catch (e: IntentSender.SendIntentException) {
            Log.e("HaiMusic", "Failed to launch delete request", e)
            false
        } catch (e: Exception) {
            Log.e("HaiMusic", "Failed to prepare delete request", e)
            false
        }
    }

    private fun handleExtractCover(audioPath: String, savePath: String, result: MethodChannel.Result) {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(audioPath)
            val embeddedPicture = retriever.embeddedPicture

            if (embeddedPicture != null) {
                val saveFile = File(savePath)
                saveFile.parentFile?.mkdirs()
                saveFile.writeBytes(embeddedPicture)
                result.success(savePath)
            } else {
                result.success(null)
            }
        } catch (e: Exception) {
            result.error("EXTRACT_COVER_FAILED", e.message, null)
        } finally {
            retriever.release()
        }
    }

    private fun handleGetMetadata(audioPath: String, result: MethodChannel.Result) {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(audioPath)
            val title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE) ?: ""
            val artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST) ?: ""
            val album = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM) ?: ""
            val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION) ?: ""
            val metadata = hashMapOf<String, String>(
                "title" to title,
                "artist" to artist,
                "album" to album,
                "duration" to durationStr
            )
            result.success(metadata)
        } catch (e: Exception) {
            result.error("GET_METADATA_FAILED", e.message, null)
        } finally {
            retriever.release()
        }
    }

    private fun handleSaveFile(targetPath: String, bytes: ByteArray, result: MethodChannel.Result) {
        try {
            val file = File(targetPath)
            file.parentFile?.mkdirs()

            try {
                file.writeBytes(bytes)
                Log.i("HaiMusic", "File.writeBytes() succeeded: $targetPath")
                result.success(targetPath)
                return
            } catch (e: Exception) {
                Log.w("HaiMusic", "File.writeBytes() failed, trying MediaStore: ${e.message}")
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val fileName = file.name
                val mimeType = when (file.extension.lowercase()) {
                    "jpg", "jpeg" -> "image/jpeg"
                    "png" -> "image/png"
                    "webp" -> "image/webp"
                    "mp3" -> "audio/mpeg"
                    "m4a" -> "audio/mp4"
                    "flac" -> "audio/flac"
                    "wav" -> "audio/wav"
                    "ogg" -> "audio/ogg"
                    "lrc" -> "text/plain"
                    else -> "application/octet-stream"
                }

                val relativePath = when {
                    mimeType.startsWith("image/") -> "${Environment.DIRECTORY_PICTURES}/HaiMusic/covers"
                    mimeType.startsWith("audio/") -> "${Environment.DIRECTORY_MUSIC}/HaiMusic"
                    else -> "${Environment.DIRECTORY_DOWNLOADS}/HaiMusic"
                }

                val contentValues = ContentValues().apply {
                    put(MediaStore.Files.FileColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.Files.FileColumns.MIME_TYPE, mimeType)
                    put(MediaStore.Files.FileColumns.RELATIVE_PATH, relativePath)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        put(MediaStore.Files.FileColumns.IS_PENDING, 1)
                    }
                }

                val collection = when {
                    mimeType.startsWith("image/") -> MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                    mimeType.startsWith("audio/") -> MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                    else -> MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                }

                val uri = contentResolver.insert(collection, contentValues)
                if (uri != null) {
                    contentResolver.openOutputStream(uri)?.use { outputStream ->
                        outputStream.write(bytes)
                    }

                    contentValues.clear()
                    contentValues.put(MediaStore.Files.FileColumns.IS_PENDING, 0)
                    contentResolver.update(uri, contentValues, null, null)

                    val cursor = contentResolver.query(uri, arrayOf(MediaStore.Files.FileColumns.DATA), null, null, null)
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val dataIndex = it.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
                            val savedPath = it.getString(dataIndex)
                            Log.i("HaiMusic", "MediaStore save succeeded: $savedPath")
                            result.success(savedPath)
                            return
                        }
                    }

                    Log.i("HaiMusic", "MediaStore save succeeded (path unknown): $uri")
                    result.success(targetPath)
                    return
                }
            }

            Log.w("HaiMusic", "All save methods failed: $targetPath")
            result.success(null)
        } catch (e: Exception) {
            Log.e("HaiMusic", "Save file failed: $targetPath", e)
            result.error("SAVE_FAILED", e.message, null)
        }
    }
}
