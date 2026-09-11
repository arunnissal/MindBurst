package org.mindburst.mindburst_app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.speech.tts.TextToSpeech
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val CHANNEL = "org.mindburst.mindburst_app/native"
    private val NOTIF_CHANNEL_ID = "mindburst_reminders"
    private var tts: TextToSpeech? = null
    private var isTtsReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize Text to Speech
        tts = TextToSpeech(this, this)

        // Create Notification Channel on Android 8.0+
        createNotificationChannel()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openMaps" -> {
                    val place = call.argument<String>("place") ?: ""
                    openPlaceInMaps(place)
                    result.success(true)
                }
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: "MindBurst Reminder"
                    val body = call.argument<String>("body") ?: ""
                    val id = call.argument<Int>("id") ?: (System.currentTimeMillis() % 100000).toInt()
                    showNativeNotification(title, body, id)
                    result.success(true)
                }
                "scheduleNotification" -> {
                    val id = call.argument<Int>("id") ?: (System.currentTimeMillis() % 100000).toInt()
                    val title = call.argument<String>("title") ?: "MindBurst Reminder"
                    val body = call.argument<String>("body") ?: ""
                    val triggerAtMillis = (call.argument<Number>("triggerAtMillis"))?.toLong() ?: 0L
                    scheduleNativeNotification(id, title, body, triggerAtMillis)
                    result.success(true)
                }
                "cancelNotification" -> {
                    val id = call.argument<Int>("id") ?: 0
                    cancelNativeNotification(id)
                    result.success(true)
                }
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    speakText(text)
                    result.success(true)
                }
                "stopSpeaking" -> {
                    stopSpeaking()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            // Set locale to English or Indian English for Tanglish phonetics
            val result = tts?.setLanguage(Locale("en", "IN"))
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                tts?.setLanguage(Locale.US)
            }
            tts?.setSpeechRate(0.95f)
            isTtsReady = true
        }
    }

    private fun speakText(text: String) {
        if (isTtsReady && text.isNotEmpty()) {
            tts?.stop()
            // Clean markdown asterisks and bullets for smooth speech
            val cleanText = text.replace("*", "").replace("•", "").replace("#", "")
            tts?.speak(cleanText, TextToSpeech.QUEUE_FLUSH, null, "mindburst_tts")
        }
    }

    private fun stopSpeaking() {
        tts?.stop()
    }

    private fun openPlaceInMaps(place: String) {
        if (place.trim().isEmpty()) return
        try {
            val encoded = Uri.encode(place.trim())
            val gmmIntentUri = Uri.parse("geo:0,0?q=$encoded")
            val mapIntent = Intent(Intent.ACTION_VIEW, gmmIntentUri)
            mapIntent.setPackage("com.google.android.apps.maps")
            if (mapIntent.resolveActivity(packageManager) != null) {
                startActivity(mapIntent)
            } else {
                val browserUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encoded")
                val browserIntent = Intent(Intent.ACTION_VIEW, browserUri)
                startActivity(browserIntent)
            }
        } catch (e: Exception) {
            val browserUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=" + Uri.encode(place))
            val browserIntent = Intent(Intent.ACTION_VIEW, browserUri)
            startActivity(browserIntent)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "MindBurst Reminders"
            val descriptionText = "Reminders, tasks, and place alerts"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(NOTIF_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableVibration(true)
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showNativeNotification(title: String, body: String, id: Int = (System.currentTimeMillis() % 100000).toInt()) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val builder = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)

        notificationManager.notify(id, builder.build())
    }

    private fun scheduleNativeNotification(id: Int, title: String, body: String, triggerAtMillis: Long) {
        val now = System.currentTimeMillis()
        if (triggerAtMillis <= now + 2000L) {
            // Trigger immediately if time is in past or within 2 seconds
            showNativeNotification(title, body, id)
            return
        }

        try {
            val intent = Intent(this, NotificationReceiver::class.java).apply {
                putExtra("id", id)
                putExtra("title", title)
                putExtra("body", body)
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getBroadcast(this, id, intent, flags)
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
        } catch (e: Exception) {
            showNativeNotification(title, body, id)
        }
    }

    private fun cancelNativeNotification(id: Int) {
        try {
            val intent = Intent(this, NotificationReceiver::class.java)
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_NO_CREATE
            }
            val pendingIntent = PendingIntent.getBroadcast(this, id, intent, flags)
            if (pendingIntent != null) {
                val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
        } catch (e: Exception) {}
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        super.onDestroy()
    }
}
