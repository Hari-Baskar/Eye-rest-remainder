package com.reset

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * BootReceiver
 *
 * Listens for system boot and device power on events.
 * Reschedules the exact 20-minute gentle eye reminder alarm.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val cycleSeconds = prefs.getLong("flutter.rhythm_cycle_target_seconds", EyeAlarmReceiver.DEFAULT_CYCLE_SECONDS)
        EyeAlarmReceiver.scheduleAlarm(context, cycleSeconds)
    }
}
