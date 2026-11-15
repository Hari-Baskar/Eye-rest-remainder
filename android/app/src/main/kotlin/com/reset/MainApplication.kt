package com.reset

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.AudioPlaybackConfiguration
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager

/**
 * MainApplication
 *
 * Persistent Android Application instance that lives throughout the process lifecycle.
 * Manages system-level:
 * 1. Screen state (ACTION_SCREEN_ON, ACTION_SCREEN_OFF, ACTION_USER_PRESENT)
 * 2. Media/Video playback detection (AudioPlaybackCallback)
 * 3. Telephony call state (TelephonyCallback / PhoneStateListener)
 * 4. Proximity sensor (phone at ear or in pocket)
 *
 * Persists all four states directly to FlutterSharedPreferences so that
 * Screen Time and Eye Rest monitoring continue working accurately across
 * background and killed/terminated app states.
 */
class MainApplication : Application(), SensorEventListener {

    companion object {
        var instance: MainApplication? = null
            private set
    }

    var isInCall = false
        private set
    var isProximityNear = false
        private set
    var isScreenInteractive = true
        private set
    var isMediaPlaying = false
        private set

    var onStateChangedListener: ((Boolean, Boolean, Boolean, Boolean) -> Unit)? = null

    private var screenReceiver: BroadcastReceiver? = null
    private var sensorManager: SensorManager? = null
    private var proximitySensor: Sensor? = null
    private var telephonyManager: TelephonyManager? = null
    private var audioManager: AudioManager? = null
    private var audioPlaybackCallback: AudioManager.AudioPlaybackCallback? = null
    private var powerManager: PowerManager? = null

    override fun onCreate() {
        super.onCreate()
        instance = this

        powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        proximitySensor = sensorManager?.getDefaultSensor(Sensor.TYPE_PROXIMITY)
        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager

        // Read initial screen and media states
        isScreenInteractive = powerManager?.isInteractive ?: true
        isMediaPlaying = checkIsMediaActive()

        // Initialize screen-on timestamp if not already set (do not overwrite existing)
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val hasOn = prefs.contains("flutter.screen_turned_on_ms") || prefs.contains("screen_turned_on_ms")
            if (!hasOn && isScreenInteractive) {
                prefs.edit()
                    .putLong("flutter.screen_turned_on_ms", now)
                    .putLong("screen_turned_on_ms", now)
                    .putLong("flutter.rhythm_screen_on_timestamp_ms", now)
                    .putLong("rhythm_screen_on_timestamp_ms", now)
                    .apply()
            }
        } catch (_: Exception) {}

        registerScreenLifecycleReceiver()
        registerAudioPlaybackListener()
        registerTelephonyListener()
        registerProximitySensor()

        persistStates()
    }

    private fun registerScreenLifecycleReceiver() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }

        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val interactive = when (intent?.action) {
                    Intent.ACTION_SCREEN_OFF -> false
                    Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> true
                    else -> powerManager?.isInteractive ?: true
                }
                val stateChanged = (interactive != isScreenInteractive)
                isScreenInteractive = interactive
                if (stateChanged) {
                    recordScreenTransition(interactive)
                }
                // Also re-verify media state on screen toggle
                isMediaPlaying = checkIsMediaActive()
                persistStates()
                notifyListener()
            }
        }
        registerReceiver(screenReceiver, filter)
    }

    private fun registerAudioPlaybackListener() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                audioPlaybackCallback = object : AudioManager.AudioPlaybackCallback() {
                    override fun onPlaybackConfigChanged(configs: MutableList<AudioPlaybackConfiguration>?) {
                        super.onPlaybackConfigChanged(configs)
                        val active = checkIsMediaActive()
                        if (active != isMediaPlaying) {
                            isMediaPlaying = active
                            persistStates()
                            notifyListener()
                        }
                    }
                }
                audioManager?.registerAudioPlaybackCallback(
                    audioPlaybackCallback!!,
                    Handler(Looper.getMainLooper())
                )
            } catch (_: Exception) {}
        }
    }

    fun checkIsGameActive(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val configs = audioManager?.activePlaybackConfigurations
                configs?.any { config ->
                    config.audioAttributes.usage == AudioAttributes.USAGE_GAME
                } == true
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
    }

    fun checkIsMediaActive(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val configs = audioManager?.activePlaybackConfigurations
                val hasMediaConfig = configs?.any { config ->
                    val usage = config.audioAttributes.usage
                    usage == AudioAttributes.USAGE_MEDIA ||
                    usage == AudioAttributes.USAGE_GAME ||
                    usage == AudioAttributes.USAGE_UNKNOWN
                } == true
                hasMediaConfig || (audioManager?.isMusicActive == true)
            } else {
                audioManager?.isMusicActive == true
            }
        } catch (_: Exception) {
            audioManager?.isMusicActive == true
        }
    }

    private fun registerTelephonyListener() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                telephonyManager?.registerTelephonyCallback(
                    mainExecutor,
                    object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                        override fun onCallStateChanged(state: Int) {
                            val inCall = (state != TelephonyManager.CALL_STATE_IDLE)
                            if (inCall != isInCall) {
                                isInCall = inCall
                                persistStates()
                                notifyListener()
                            }
                        }
                    }
                )
            } else {
                @Suppress("DEPRECATION")
                telephonyManager?.listen(object : PhoneStateListener() {
                    @Deprecated("Deprecated in Java")
                    override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                        val inCall = (state != TelephonyManager.CALL_STATE_IDLE)
                        if (inCall != isInCall) {
                            isInCall = inCall
                            persistStates()
                            notifyListener()
                        }
                    }
                }, PhoneStateListener.LISTEN_CALL_STATE)
            }
        } catch (_: Exception) {}
    }

    private fun registerProximitySensor() {
        proximitySensor?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }


    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return
        if (event.sensor.type == Sensor.TYPE_PROXIMITY) {
            val distance = event.values[0]
            val maxRange = proximitySensor?.maximumRange ?: 5f
            val near = distance < 1.0f || (distance < maxRange && distance <= 1.5f)
            if (near != isProximityNear) {
                isProximityNear = near
                persistStates()
                notifyListener()
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    fun recordScreenTransition(screenOn: Boolean) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val uptime = android.os.SystemClock.uptimeMillis()
            val elapsed = android.os.SystemClock.elapsedRealtime()
            val editor = prefs.edit()
            editor.putLong("rhythm_last_uptime_ms", uptime)
            editor.putLong("flutter.rhythm_last_uptime_ms", uptime)
            editor.putLong("rhythm_last_elapsed_ms", elapsed)
            editor.putLong("flutter.rhythm_last_elapsed_ms", elapsed)
            if (screenOn) {
                editor.putLong("flutter.screen_turned_on_ms", now)
                editor.putLong("screen_turned_on_ms", now)
                editor.putLong("flutter.rhythm_screen_on_timestamp_ms", now)
                editor.putLong("rhythm_screen_on_timestamp_ms", now)
            } else {
                editor.putLong("flutter.screen_turned_off_ms", now)
                editor.putLong("screen_turned_off_ms", now)
                editor.putLong("flutter.rhythm_screen_off_timestamp_ms", now)
                editor.putLong("rhythm_screen_off_timestamp_ms", now)
            }
            editor.apply()
        } catch (_: Exception) {}
    }

    fun persistStates() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            editor.putBoolean("flutter.is_screen_interactive", isScreenInteractive)
            editor.putBoolean("is_screen_interactive", isScreenInteractive)
            editor.putBoolean("flutter.is_media_playing", isMediaPlaying)
            editor.putBoolean("is_media_playing", isMediaPlaying)
            editor.putBoolean("flutter.is_proximity_near", isProximityNear)
            editor.putBoolean("is_proximity_near", isProximityNear)
            editor.putBoolean("flutter.is_in_call", isInCall)
            editor.putBoolean("is_in_call", isInCall)
            editor.apply()
        } catch (_: Exception) {}
    }

    private fun notifyListener() {
        try {
            onStateChangedListener?.invoke(isInCall, isProximityNear, isScreenInteractive, isMediaPlaying)
        } catch (_: Exception) {}
    }
}
