package com.example.jobhunt

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    /**
     * Creates the notification channel that FCM uses to deliver messages.
     *
     * On Android 8.0+ (API 26+) every notification MUST belong to a channel.
     * If the channel doesn't exist when FCM tries to post a notification,
     * the notification is silently dropped — this is the most common reason
     * push notifications never appear on Android.
     *
     * The channel id here must match:
     *   1. AndroidManifest.xml  → com.google.firebase.messaging.default_notification_channel_id
     *   2. main.dart            → AndroidNotificationDetails channelId
     *   3. Backend FCM payload  → android.notification.channel_id (if set)
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId   = "job_posting_channel"
            val channelName = "Job Alerts"
            val description = "Notifications for job application updates and new matches"
            val importance  = NotificationManager.IMPORTANCE_HIGH

            val channel = NotificationChannel(channelId, channelName, importance).apply {
                this.description     = description
                enableLights(true)
                lightColor           = Color.parseColor("#6C63FF")   // accent color
                enableVibration(true)
                vibrationPattern     = longArrayOf(0, 250, 250, 250)
                setShowBadge(true)
            }

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
