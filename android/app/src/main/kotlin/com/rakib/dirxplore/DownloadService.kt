package com.rakib.dirxplore

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class DownloadService : Service() {
    private val CHANNEL_ID = "DownloadServiceChannel"
    private val notificationManager: NotificationManager by lazy {
        getSystemService(NOTIFICATION_SERVICE) as NotificationManager
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        val id = intent?.getIntExtra("id", 0) ?: 0

        when (action) {
            "START_DOWNLOAD" -> {
                val filename = intent.getStringExtra("filename") ?: "Unknown File"
                startForeground(id, createNotification(filename, 0, "Starting..."))
            }
            "UPDATE_PROGRESS" -> {
                val progress = intent.getIntExtra("progress", 0)
                val speed = intent.getStringExtra("speed") ?: ""
                // Just use the notification manager to update the existing notification ID
                notificationManager.notify(id, createNotification("Downloading...", progress, speed))
            }
            "STOP_DOWNLOAD" -> {
                stopForeground(true)
                stopSelfResult(startId)
            }
        }
        return START_NOT_STICKY
    }

    private fun createNotification(title: String, progress: Int, contentText: String): android.app.Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, pendingIntentFlags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setProgress(100, progress, progress == 0) // Indeterminate if progress is 0
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Download Service Channel",
                NotificationManager.IMPORTANCE_LOW 
            )
            notificationManager.createNotificationChannel(serviceChannel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
