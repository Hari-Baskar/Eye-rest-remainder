package com.reset

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import androidx.core.app.NotificationCompat

/**
 * EyeAlarmReceiver
 *
 * Native Android BroadcastReceiver that handles cumulative eye care reminders.
 * Operates purely via Android's AlarmManager without any persistent status bar notification badge:
 * 1. Android OS wakes this receiver even if the app process has been killed.
 * 2. Checks PowerManager.isInteractive (physical reality check: is the display currently lit up?).
 * 3. Cumulative screen time: If user doesn't rest, alerts escalate (20m, 40m, 60m continuous).
 * 4. If screen is ON: Displays a gentle 25-second auto-dismissing banner.
 * 5. If screen is OFF: Verifies rest duration using kernel hardware clocks.
 * 6. Automatically schedules the next cycle and terminates immediately.
 */
class EyeAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_ALARM = "com.reset.ACTION_EYE_20MIN_ALARM"
        const val CHANNEL_ID = "eye_break_high_priority_v3"
        const val NOTIFICATION_ID = 101
        const val DEFAULT_CYCLE_SECONDS = 1200L // 20 minutes

        fun scheduleAlarm(context: Context, delaySeconds: Long) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, EyeAlarmReceiver::class.java).apply {
                action = ACTION_ALARM
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)

            // Do not force delay up to 1200s if user has a shorter remaining lap
            val effectiveDelay = if (delaySeconds > 0L) delaySeconds else DEFAULT_CYCLE_SECONDS
            val triggerAt = SystemClock.elapsedRealtime() + (effectiveDelay * 1000L)

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
                    } else {
                        // Fallback when exact alarm permission is not granted on Android 12+: wakes while idle reliably
                        alarmManager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
                    }
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
                }
            } catch (_: Exception) {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
                    } else {
                        alarmManager.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
                    }
                } catch (_: Exception) {}
            }
        }

        fun cancelAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, EyeAlarmReceiver::class.java).apply {
                action = ACTION_ALARM
            }
            val flags = PendingIntent.FLAG_NO_CREATE or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
            }
        }

        fun getSafeLong(prefs: SharedPreferences, key: String, defaultVal: Long = 0L): Long {
            return try {
                prefs.getLong(key, defaultVal)
            } catch (_: Exception) {
                try {
                    prefs.getInt(key, defaultVal.toInt()).toLong()
                } catch (_: Exception) {
                    try {
                        prefs.getString(key, null)?.toLongOrNull() ?: defaultVal
                    } catch (_: Exception) {
                        defaultVal
                    }
                }
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "LifeMint:EyeAlarmWakeLock")
        wakeLock?.acquire(15000L) // 15 seconds max guarantee for background CPU execution

        try {
            val isScreenOn = powerManager?.isInteractive ?: false
            val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as? android.app.KeyguardManager
            val isKeyguardLocked = keyguardManager?.isKeyguardLocked ?: false
            // User is actively using the screen ONLY if screen is on AND device is not locked
            val isScreenInteractive = isScreenOn && !isKeyguardLocked

            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // Phone call detection: Mute reminders during active phone calls so user is not interrupted
            val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as? android.telephony.TelephonyManager
            val isInCall = try {
                val callState = telephonyManager?.callState ?: android.telephony.TelephonyManager.CALL_STATE_IDLE
                callState != android.telephony.TelephonyManager.CALL_STATE_IDLE ||
                    prefs.getBoolean("flutter.is_in_call", false) ||
                    prefs.getBoolean("is_in_call", false)
            } catch (_: Exception) {
                prefs.getBoolean("flutter.is_in_call", false) || prefs.getBoolean("is_in_call", false)
            }

            if (isInCall) {
                // Defer reminder while on phone call; re-check in 60 seconds
                scheduleAlarm(context, 60L)
                return
            }

            val cycleSeconds = maxOf(
                getSafeLong(prefs, "flutter.rhythm_cycle_target_seconds"),
                getSafeLong(prefs, "rhythm_cycle_target_seconds")
            )
            val effectiveSeconds = if (cycleSeconds >= 60L) cycleSeconds else DEFAULT_CYCLE_SECONDS

            val restSeconds = maxOf(
                getSafeLong(prefs, "flutter.rhythm_required_rest_seconds"),
                getSafeLong(prefs, "rhythm_required_rest_seconds"),
                120L
            )
            val restThresholdMs = restSeconds * 1000L

            val curUptime = SystemClock.uptimeMillis()
            val curElapsed = SystemClock.elapsedRealtime()
            val nowMs = System.currentTimeMillis()

            if (isScreenInteractive) {
                val lastReminderTimeMs = maxOf(
                    getSafeLong(prefs, "flutter.last_reminder_timestamp_ms"),
                    getSafeLong(prefs, "last_reminder_timestamp_ms")
                )

                // Deduplicate: If Flutter foreground already delivered an alert in the last 40 seconds, skip duplicate
                val isRecentAlert = (nowMs - lastReminderTimeMs) in 0..40000L

                // Accurately compute real continuous screen seconds from kernel usage events or hardware clocks
                val actualContinuousSec = getActualContinuousScreenSeconds(context, restSeconds)
                val effectiveContinuousSec = if (actualContinuousSec > 0L) actualContinuousSec else effectiveSeconds
                val continuousMinutes = maxOf(1L, (effectiveContinuousSec + 30L) / 60L)

                if (!isRecentAlert) {
                    // Show gentle notification with true continuous time and dynamic rest duration
                    showGentleNotification(context, continuousMinutes, restSeconds)

                    // Increment reminders count in SharedPreferences for today and log timestamp
                    try {
                        val todayStr = java.time.LocalDate.now().toString()
                        val savedDate = prefs.getString("flutter.gentle_reminders_date", "")
                            ?: prefs.getString("gentle_reminders_date", "")
                        var currentCount = maxOf(
                            getSafeLong(prefs, "flutter.gentle_reminders_count"),
                            getSafeLong(prefs, "gentle_reminders_count")
                        )
                        if (savedDate == todayStr) {
                            currentCount += 1
                        } else {
                            currentCount = 1
                        }
                        prefs.edit()
                            .putString("flutter.gentle_reminders_date", todayStr)
                            .putString("gentle_reminders_date", todayStr)
                            .putLong("flutter.gentle_reminders_count", currentCount)
                            .putLong("gentle_reminders_count", currentCount)
                            .putLong("flutter.rhythm_continuous_session_seconds", 0L)
                            .putLong("rhythm_continuous_session_seconds", 0L)
                            .putLong("flutter.rhythm_current_session_seconds", 0L)
                            .putLong("rhythm_current_session_seconds", 0L)
                            .putLong("flutter.continuous_screen_seconds", 0L)
                            .putLong("continuous_screen_seconds", 0L)
                            .putLong("flutter.last_reminder_timestamp_ms", nowMs)
                            .putLong("last_reminder_timestamp_ms", nowMs)
                            .putLong("rhythm_last_uptime_ms", curUptime)
                            .putLong("flutter.rhythm_last_uptime_ms", curUptime)
                            .putLong("rhythm_last_elapsed_ms", curElapsed)
                            .putLong("flutter.rhythm_last_elapsed_ms", curElapsed)
                            .apply()
                    } catch (_: Exception) {}
                }

                // Reschedule next cycle
                scheduleAlarm(context, effectiveSeconds)
            } else {
                // Screen was OFF: Check if user has rested for >= restSeconds
                val lastUptime = maxOf(
                    getSafeLong(prefs, "rhythm_last_uptime_ms"),
                    getSafeLong(prefs, "flutter.rhythm_last_uptime_ms")
                )
                val lastElapsed = maxOf(
                    getSafeLong(prefs, "rhythm_last_elapsed_ms"),
                    getSafeLong(prefs, "flutter.rhythm_last_elapsed_ms")
                )

                if (lastUptime > 0L && lastElapsed > 0L && curElapsed >= lastElapsed) {
                    val awakeMs = maxOf(0L, curUptime - lastUptime)
                    val sleepMs = maxOf(0L, (curElapsed - lastElapsed) - awakeMs)
                    if (sleepMs >= restThresholdMs) {
                        // User genuinely rested! Reset continuous session to 0
                        try {
                            prefs.edit()
                                .putLong("flutter.rhythm_continuous_session_seconds", 0L)
                                .putLong("rhythm_continuous_session_seconds", 0L)
                                .putLong("flutter.rhythm_current_session_seconds", 0L)
                                .putLong("rhythm_current_session_seconds", 0L)
                                .putLong("flutter.continuous_screen_seconds", 0L)
                                .putLong("continuous_screen_seconds", 0L)
                                .putLong("rhythm_last_uptime_ms", curUptime)
                                .putLong("flutter.rhythm_last_uptime_ms", curUptime)
                                .putLong("rhythm_last_elapsed_ms", curElapsed)
                                .putLong("flutter.rhythm_last_elapsed_ms", curElapsed)
                                .apply()
                        } catch (_: Exception) {}
                        scheduleAlarm(context, effectiveSeconds)
                    } else {
                        // Screen is only briefly off (< restSeconds): do not wipe session!
                        // Check again in the remaining rest time to see if rest completes
                        val remainingSleepMs = restThresholdMs - sleepMs
                        val waitSec = maxOf(10L, remainingSleepMs / 1000L)
                        scheduleAlarm(context, waitSec)
                    }
                } else {
                    scheduleAlarm(context, effectiveSeconds)
                }
            }
        } finally {
            if (wakeLock?.isHeld == true) {
                try {
                    wakeLock.release()
                } catch (_: Exception) {}
            }
        }
    }

    /**
     * Calculates the true continuous screen-on time in seconds by querying
     * Android kernel UsageEvents, matching the exact logic used by MainActivity.
     */
    private fun getActualContinuousScreenSeconds(context: Context, restThresholdSec: Long): Long {
        // 1. Try UsageStatsManager (kernel-level ground truth)
        try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
            val hasUsage = if (appOps != null) {
                val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    appOps.unsafeCheckOpNoThrow(
                        AppOpsManager.OPSTR_GET_USAGE_STATS,
                        Process.myUid(),
                        context.packageName
                    )
                } else {
                    @Suppress("DEPRECATION")
                    appOps.checkOpNoThrow(
                        AppOpsManager.OPSTR_GET_USAGE_STATS,
                        Process.myUid(),
                        context.packageName
                    )
                }
                mode == AppOpsManager.MODE_ALLOWED
            } else false

            if (hasUsage) {
                val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
                if (usageStatsManager != null) {
                    val now = System.currentTimeMillis()
                    val queryStart = maxOf(0L, now - (4 * 60 * 60 * 1000L)) // Look back 4 hours
                    val events = usageStatsManager.queryEvents(queryStart, now)
                    val event = UsageEvents.Event()

                    val rawIntervals = mutableListOf<Pair<Long, Long>>()
                    val appResumeTimes = mutableMapOf<String, Long>()
                    var lastScreenInteractiveStart: Long? = null

                    while (events.hasNextEvent()) {
                        events.getNextEvent(event)
                        val time = event.timeStamp
                        val pkg = event.packageName ?: ""

                        when (event.eventType) {
                            UsageEvents.Event.SCREEN_INTERACTIVE,
                            UsageEvents.Event.KEYGUARD_HIDDEN -> {
                                lastScreenInteractiveStart = time
                            }
                            UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                            UsageEvents.Event.KEYGUARD_SHOWN -> {
                                val start = lastScreenInteractiveStart ?: appResumeTimes.values.minOrNull()
                                if (start != null && time > start) {
                                    rawIntervals.add(Pair(start, time))
                                }
                                lastScreenInteractiveStart = null
                                for ((_, appStart) in appResumeTimes) {
                                    if (time > appStart) {
                                        rawIntervals.add(Pair(appStart, time))
                                    }
                                }
                                appResumeTimes.clear()
                            }
                            UsageEvents.Event.ACTIVITY_RESUMED -> {
                                appResumeTimes[pkg] = time
                                if (lastScreenInteractiveStart == null) {
                                    lastScreenInteractiveStart = time
                                }
                            }
                            UsageEvents.Event.ACTIVITY_PAUSED,
                            UsageEvents.Event.ACTIVITY_STOPPED -> {
                                val start = appResumeTimes.remove(pkg)
                                if (start != null && time > start) {
                                    rawIntervals.add(Pair(start, time))
                                }
                            }
                        }
                    }

                    val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val isCurrentlyInteractive = powerManager?.isInteractive ?: true
                    if (isCurrentlyInteractive) {
                        val effStart = lastScreenInteractiveStart ?: appResumeTimes.values.minOrNull()
                        if (effStart != null && now > effStart) {
                            rawIntervals.add(Pair(effStart, now))
                        }
                        for ((_, start) in appResumeTimes) {
                            if (now > start) {
                                rawIntervals.add(Pair(start, now))
                            }
                        }
                    }

                    val sorted = rawIntervals.sortedBy { it.first }
                    val merged = mutableListOf<Pair<Long, Long>>()
                    if (sorted.isNotEmpty()) {
                        var curStart = sorted[0].first
                        var curEnd = sorted[0].second
                        for (i in 1 until sorted.size) {
                            val next = sorted[i]
                            if (next.first <= curEnd) {
                                curEnd = maxOf(curEnd, next.second)
                            } else {
                                merged.add(Pair(curStart, curEnd))
                                curStart = next.first
                                curEnd = next.second
                            }
                        }
                        merged.add(Pair(curStart, curEnd))
                    }

                    if (isCurrentlyInteractive && merged.isNotEmpty()) {
                        val lastActive = merged.last()
                        if (now - lastActive.second <= 30000L) {
                            val restThresholdMs = restThresholdSec * 1000L
                            var curContinuousMs = lastActive.second - lastActive.first
                            for (i in merged.size - 2 downTo 0) {
                                val prev = merged[i]
                                val gap = merged[i + 1].first - prev.second
                                if (gap < restThresholdMs) {
                                    curContinuousMs += (prev.second - prev.first)
                                } else {
                                    break
                                }
                            }
                            val resultSec = curContinuousMs / 1000L
                            if (resultSec > 0L) {
                                return resultSec
                            }
                        }
                    }
                }
            }
        } catch (_: Exception) {}

        // 2. Hardware kernel clocks (uptimeMillis & elapsedRealtime) ground truth when Usage Access is not granted
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val restThresholdMs = restThresholdSec * 1000L
        val lastUptime = maxOf(
            getSafeLong(prefs, "rhythm_last_uptime_ms"),
            getSafeLong(prefs, "flutter.rhythm_last_uptime_ms")
        )
        val lastElapsed = maxOf(
            getSafeLong(prefs, "rhythm_last_elapsed_ms"),
            getSafeLong(prefs, "flutter.rhythm_last_elapsed_ms")
        )
        val curUptime = SystemClock.uptimeMillis()
        val curElapsed = SystemClock.elapsedRealtime()

        if (lastUptime > 0L && lastElapsed > 0L && curUptime >= lastUptime && curElapsed >= lastElapsed) {
            val awakeMs = curUptime - lastUptime
            val sleepMs = maxOf(0L, (curElapsed - lastElapsed) - awakeMs)
            if (sleepMs >= restThresholdMs) {
                // Device deep-slept for >= rest threshold: user genuinely rested!
                return 0L
            } else {
                val saved = maxOf(
                    getSafeLong(prefs, "flutter.rhythm_current_session_seconds"),
                    getSafeLong(prefs, "rhythm_current_session_seconds"),
                    getSafeLong(prefs, "flutter.rhythm_continuous_session_seconds"),
                    getSafeLong(prefs, "rhythm_continuous_session_seconds"),
                    getSafeLong(prefs, "flutter.continuous_screen_seconds"),
                    getSafeLong(prefs, "continuous_screen_seconds")
                )
                return saved + (awakeMs / 1000L)
            }
        }

        // 3. Screen transition timestamps fallback
        val nowMs = System.currentTimeMillis()
        val screenOnMs = maxOf(
            getSafeLong(prefs, "flutter.rhythm_screen_on_timestamp_ms"),
            getSafeLong(prefs, "rhythm_screen_on_timestamp_ms"),
            getSafeLong(prefs, "screen_turned_on_ms"),
            getSafeLong(prefs, "flutter.screen_turned_on_ms")
        )
        val screenOffMs = maxOf(
            getSafeLong(prefs, "flutter.rhythm_screen_off_timestamp_ms"),
            getSafeLong(prefs, "rhythm_screen_off_timestamp_ms"),
            getSafeLong(prefs, "screen_turned_off_ms"),
            getSafeLong(prefs, "flutter.screen_turned_off_ms")
        )
        if (screenOnMs > 0L && screenOnMs > screenOffMs) {
            val offGap = if (screenOffMs > 0L) screenOnMs - screenOffMs else restThresholdMs
            if (offGap >= restThresholdMs) {
                return maxOf(0L, (nowMs - screenOnMs) / 1000L)
            }
        }

        // 4. Saved session fallback
        return maxOf(
            getSafeLong(prefs, "flutter.rhythm_current_session_seconds"),
            getSafeLong(prefs, "rhythm_current_session_seconds"),
            getSafeLong(prefs, "flutter.rhythm_continuous_session_seconds"),
            getSafeLong(prefs, "rhythm_continuous_session_seconds"),
            getSafeLong(prefs, "flutter.continuous_screen_seconds"),
            getSafeLong(prefs, "continuous_screen_seconds")
        )
    }

    private fun showGentleNotification(context: Context, continuousMinutes: Long, restSeconds: Long) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Eye Rest Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "High-priority reminders to rest your eyes"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 200, 300)
                setShowBadge(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setSound(soundUri, audioAttributes)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val pendingIntent = if (launchIntent != null) {
            PendingIntent.getActivity(context, 0, launchIntent, flags)
        } else null

        val restText = if (restSeconds >= 60L) {
            val m = restSeconds / 60L
            val s = restSeconds % 60L
            if (s == 0L) "${m}m" else "${m}m ${s}s"
        } else {
            "${restSeconds}s"
        }

        val title = "Eye Rest • $continuousMinutes Minutes 👁️"
        val message = "$continuousMinutes minutes continuous screen time. Rest your eyes for $restText."

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setAutoCancel(true)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setVibrate(longArrayOf(0, 300, 200, 300))
            .setSound(soundUri)
            .setTimeoutAfter(25000L) // Auto-dismisses in 25 seconds if ignored!
            .setContentIntent(pendingIntent)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
