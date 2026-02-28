package com.rakib.dirxplore

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.nexus/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    val url = call.argument<String>("url") ?: ""
                    val filename = call.argument<String>("filename") ?: ""
                    val id = call.argument<Int>("id") ?: 0
                    
                    val intent = Intent(this, DownloadService::class.java).apply {
                        action = "START_DOWNLOAD"
                        putExtra("url", url)
                        putExtra("filename", filename)
                        putExtra("id", id)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopForegroundService" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val intent = Intent(this, DownloadService::class.java).apply {
                        action = "STOP_DOWNLOAD"
                        putExtra("id", id)
                    }
                    startService(intent)
                    result.success(true)
                }
                "updateProgress" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val progress = call.argument<Int>("progress") ?: 0
                    val speedStr = call.argument<String>("speed") ?: ""
                    val intent = Intent(this, DownloadService::class.java).apply {
                        action = "UPDATE_PROGRESS"
                        putExtra("id", id)
                        putExtra("progress", progress)
                        putExtra("speed", speedStr)
                    }
                    startService(intent)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
