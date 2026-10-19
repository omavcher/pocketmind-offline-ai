package com.pocketmind.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.StatFs
import android.os.Environment
import java.io.File
import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.content.ContentValues
import android.database.Cursor

class MainActivity: FlutterActivity() {
    private val STORAGE_CHANNEL = "com.pocketmind.app/storage"
    private val DOWNLOAD_CHANNEL = "com.pocketmind.app/download"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getStorageInfo") {
                try {
                    val path: File = getExternalFilesDir(null) ?: Environment.getDataDirectory()
                    val stat = StatFs(path.path)
                    val blockSize = stat.blockSizeLong
                    val totalBlocks = stat.blockCountLong
                    val availableBlocks = stat.availableBlocksLong
                    
                    val storageInfo = mapOf(
                        "total" to (totalBlocks * blockSize).toDouble(),
                        "free" to (availableBlocks * blockSize).toDouble()
                    )
                    result.success(storageInfo)
                } catch (e: Exception) {
                    result.error("STORAGE_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_CHANNEL).setMethodCallHandler { call, result ->
            val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            when (call.method) {
                "enqueueDownload" -> {
                    val url = call.argument<String>("url")
                    val filename = call.argument<String>("filename")
                    val title = call.argument<String>("title") ?: filename
                    
                    if (url == null || filename == null) {
                        result.error("INVALID_ARGS", "URL and filename are required", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        val destinationFile = File(getExternalFilesDir(null), "models/$filename")
                        destinationFile.parentFile?.mkdirs()
                        if (destinationFile.exists()) {
                            destinationFile.delete()
                        }
                        
                        val request = DownloadManager.Request(Uri.parse(url))
                            .setTitle(title)
                            .setDescription("Downloading AI Model...")
                            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                            .setDestinationUri(Uri.fromFile(destinationFile))
                            .setAllowedOverMetered(true)
                            .setAllowedOverRoaming(true)
                            
                        val downloadId = downloadManager.enqueue(request)
                        result.success(downloadId)
                    } catch (e: Exception) {
                        result.error("DOWNLOAD_ERROR", e.message, null)
                    }
                }
                "cancelDownload" -> {
                    val downloadId = call.argument<Number>("downloadId")?.toLong()
                    if (downloadId == null) {
                        result.error("INVALID_ARGS", "Download ID is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val removed = downloadManager.remove(downloadId)
                        result.success(removed > 0)
                    } catch (e: Exception) {
                        result.error("CANCEL_ERROR", e.message, null)
                    }
                }
                "getDownloadStatus" -> {
                    val downloadId = call.argument<Number>("downloadId")?.toLong()
                    if (downloadId == null) {
                        result.error("INVALID_ARGS", "Download ID is required", null)
                        return@setMethodCallHandler
                    }
                    var cursor: Cursor? = null
                    try {
                        val query = DownloadManager.Query().setFilterById(downloadId)
                        cursor = downloadManager.query(query)
                        if (cursor != null && cursor.moveToFirst()) {
                            val statusIdx = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
                            val bytesDownloadedIdx = cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                            val bytesTotalIdx = cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
                            val reasonIdx = cursor.getColumnIndex(DownloadManager.COLUMN_REASON)
                            
                            val status = if (statusIdx >= 0) cursor.getInt(statusIdx) else -1
                            val bytesDownloaded = if (bytesDownloadedIdx >= 0) cursor.getLong(bytesDownloadedIdx) else 0L
                            val bytesTotal = if (bytesTotalIdx >= 0) cursor.getLong(bytesTotalIdx) else 0L
                            val reason = if (reasonIdx >= 0) cursor.getInt(reasonIdx) else 0
                            
                            val statusStr = when (status) {
                                DownloadManager.STATUS_PENDING -> "pending"
                                DownloadManager.STATUS_RUNNING -> "running"
                                DownloadManager.STATUS_PAUSED -> "paused"
                                DownloadManager.STATUS_SUCCESSFUL -> "successful"
                                DownloadManager.STATUS_FAILED -> "failed"
                                else -> "unknown"
                            }
                            
                            result.success(mapOf(
                                "status" to statusStr,
                                "bytesDownloaded" to bytesDownloaded.toDouble(),
                                "bytesTotal" to bytesTotal.toDouble(),
                                "reason" to reason
                            ))
                        } else {
                            result.success(mapOf("status" to "notFound"))
                        }
                    } catch (e: Exception) {
                        result.error("STATUS_ERROR", e.message, null)
                    } finally {
                        cursor?.close()
                    }
                }
                "pauseDownload" -> {
                    val downloadId = call.argument<Number>("downloadId")?.toLong()
                    if (downloadId == null) {
                        result.error("INVALID_ARGS", "Download ID is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val values = ContentValues()
                        values.put("control", 1) // 1 = CONTROL_PAUSED
                        val downloadUri = Uri.parse("content://downloads/my_downloads/$downloadId")
                        val updated = contentResolver.update(downloadUri, values, null, null)
                        result.success(updated > 0)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "resumeDownload" -> {
                    val downloadId = call.argument<Number>("downloadId")?.toLong()
                    if (downloadId == null) {
                        result.error("INVALID_ARGS", "Download ID is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val values = ContentValues()
                        values.put("control", 0) // 0 = CONTROL_RUN
                        val downloadUri = Uri.parse("content://downloads/my_downloads/$downloadId")
                        val updated = contentResolver.update(downloadUri, values, null, null)
                        result.success(updated > 0)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
