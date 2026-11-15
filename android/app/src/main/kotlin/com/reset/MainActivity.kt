package com.reset

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import androidx.activity.result.ActivityResultLauncher
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.os.Process
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.os.PowerManager
import android.media.AudioManager
import android.media.AudioPlaybackConfiguration
import android.media.AudioAttributes
import android.os.Handler
import android.os.Looper
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream

/**
 * MainActivity
 *
 * Native Android activity establishing platform channels for:
 * 1. Telephony call state monitoring (to mute alerts during phone calls)
 * 2. Proximity sensor detection (to detect when held at ear or in pocket)
 * 3. Screen ON/OFF interactive monitoring
 * 4. Active media/video playback detection (for movie watching screen tracking)
 * 5. Health Connect client step tracking with READ_STEPS permission
 * 6. Device UsageStatsManager screen time aggregation
 */
class MainActivity : FlutterFragmentActivity(), SensorEventListener {

    private data class ParsedUsageEvent(
        val timeStamp: Long,
        val eventType: Int,
        val packageName: String,
        val className: String
    )

    private val METHOD_CHANNEL = "com.reset/call_proximity"
    private val EVENT_CHANNEL = "com.reset/call_proximity_events"
    private val PERMISSION_REQUEST_ACTIVITY_RECOGNITION = 1001

    // Health Connect permissions (strictly READ_STEPS only)
    private val HEALTH_PERMISSIONS = setOf(
        HealthPermission.getReadPermission(StepsRecord::class)
    )

    private var sensorManager: SensorManager? = null
    private var proximitySensor: Sensor? = null
    private var telephonyManager: TelephonyManager? = null
    private var powerManager: PowerManager? = null
    private var screenReceiver: BroadcastReceiver? = null
    private var audioManager: AudioManager? = null
    private var audioPlaybackCallback: AudioManager.AudioPlaybackCallback? = null

    private var isInCall = false
    private var isProximityNear = false
    private var isScreenInteractive = true
    private var isMediaPlaying = false
    private var eventSink: EventChannel.EventSink? = null

    private var pendingPermissionResult: MethodChannel.Result? = null

    // Register ActivityResultLauncher for Health Connect runtime permissions
    private val requestPermissionContract: ActivityResultLauncher<Set<String>> =
        registerForActivityResult(PermissionController.createRequestPermissionResultContract()) { grantedPermissions: Set<String> ->
            val isGranted = grantedPermissions.containsAll(HEALTH_PERMISSIONS)
            pendingPermissionResult?.success(isGranted)
            pendingPermissionResult = null
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize Android System Services & Proximity Sensor
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        proximitySensor = sensorManager?.getDefaultSensor(Sensor.TYPE_PROXIMITY)
        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        isScreenInteractive = powerManager?.isInteractive ?: true
        isMediaPlaying = checkIsMediaActive()

        registerSensors()
        registerScreenReceiver()
        registerAudioPlaybackListener()

        // MethodChannel for immediate state queries & Health Connect operations
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCallProximityState" -> {
                        isMediaPlaying = checkIsMediaActive()
                        val interactive = powerManager?.isInteractive ?: isScreenInteractive
                        val data = mapOf(
                            "isInCall" to isInCall,
                            "isProximityNear" to isProximityNear,
                            "isScreenInteractive" to interactive,
                            "isMediaPlaying" to isMediaPlaying
                        )
                        result.success(data)
                    }
                    "isMediaPlaying" -> {
                        result.success(checkIsMediaActive())
                    }
                    "isGameActive" -> {
                        result.success(checkIsGameActive())
                    }
                    "isScreenInteractive" -> {
                        val interactive = powerManager?.isInteractive ?: isScreenInteractive
                        result.success(interactive)
                    }
                    "getSystemClocks" -> {
                        val data = mapOf(
                            "uptimeMs" to android.os.SystemClock.uptimeMillis(),
                            "elapsedRealtimeMs" to android.os.SystemClock.elapsedRealtime()
                        )
                        result.success(data)
                    }
                    "checkHealthConnectStatus" -> {
                        val status = getHealthConnectStatus()
                        result.success(status)
                    }
                    "hasHealthPermissions" -> {
                        lifecycleScope.launch {
                            val granted = checkHealthPermissionsGranted()
                            result.success(granted)
                        }
                    }
                    "requestActivityRecognitionPermission" -> {
                        requestActivityRecognitionOnly()
                        result.success(true)
                    }
                    "requestHealthPermissions" -> {
                        lifecycleScope.launch {
                            val status = getHealthConnectStatus()
                            if (status != "available") {
                                // Health Connect not directly available, attempt fallback launch
                                openHealthConnectOrSettings()
                                result.success(false)
                                return@launch
                            }

                            val alreadyGranted = checkHealthPermissionsGranted()
                            if (alreadyGranted) {
                                result.success(true)
                                return@launch
                            }

                            try {
                                pendingPermissionResult = result
                                requestPermissionContract.launch(HEALTH_PERMISSIONS)
                            } catch (e: Exception) {
                                pendingPermissionResult = null
                                openHealthConnectOrSettings()
                                result.success(false)
                            }
                        }
                    }
                    "getHealthConnectSteps" -> {
                        lifecycleScope.launch {
                            val status = getHealthConnectStatus()
                            val isAvailable = (status == "available")
                            if (!isAvailable) {
                                result.success(
                                    mapOf(
                                        "isInstalled" to (status != "not_installed"),
                                        "isConnected" to false,
                                        "steps" to 0,
                                        "distanceKm" to 0.0,
                                        "activeMinutes" to 0
                                    )
                                )
                                return@launch
                            }

                            val isGranted = checkHealthPermissionsGranted()
                            if (!isGranted) {
                                result.success(
                                    mapOf(
                                        "isInstalled" to true,
                                        "isConnected" to false,
                                        "steps" to 0,
                                        "distanceKm" to 0.0,
                                        "activeMinutes" to 0
                                    )
                                )
                                return@launch
                            }

                            val stepsCount = readTodaySteps()
                            val distanceKm = stepsCount * 0.00075
                            val activeMinutes = (stepsCount / 100).toInt()

                            result.success(
                                mapOf(
                                    "isInstalled" to true,
                                    "isConnected" to true,
                                    "steps" to stepsCount.toInt(),
                                    "distanceKm" to distanceKm,
                                    "activeMinutes" to activeMinutes
                                )
                            )
                        }
                    }
                    "getStepsInWindow" -> {
                        val startMs = (call.argument<Number>("startTimeMs"))?.toLong() ?: (System.currentTimeMillis() - 45 * 60 * 1000)
                        val endMs = (call.argument<Number>("endTimeMs"))?.toLong() ?: System.currentTimeMillis()
                        lifecycleScope.launch {
                            val steps = readStepsInWindow(startMs, endMs)
                            result.success(steps.toInt())
                        }
                    }
                    "getHealthConnectStepIntervals" -> {
                        lifecycleScope.launch {
                            val intervals = readTodayStepIntervals()
                            result.success(intervals)
                        }
                    }
                    "hasUsageStatsPermission" -> {
                        val hasPermission = hasUsageStatsPermission()
                        result.success(hasPermission)
                    }
                    "getDeviceDailyScreenTime" -> {
                        lifecycleScope.launch {
                            val seconds = getDeviceDailyScreenTimeSeconds()
                            result.success(seconds)
                        }
                    }
                    "getAppInstallTime" -> {
                        try {
                            val info = packageManager.getPackageInfo(packageName, 0)
                            result.success(info.firstInstallTime)
                        } catch (e: Exception) {
                            result.success(0L)
                        }
                    }
                    "getDeviceScreenAndRestBlocks" -> {
                        val startMs = (call.argument<Number>("startTimeMs"))?.toLong() ?: 0L
                        val endMs = (call.argument<Number>("endTimeMs"))?.toLong() ?: System.currentTimeMillis()
                        val restSec = (call.argument<Number>("requiredRestSeconds"))?.toLong() ?: 120L
                        lifecycleScope.launch {
                            val data = getDeviceScreenAndRestBlocks(startMs, endMs, restSec * 1000L)
                            result.success(data)
                        }
                    }
                    "getAppIcon" -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        if (pkg.isEmpty() || pkg.contains("launcher") || pkg.contains("systemui") || pkg == "android") {
                            result.success(null)
                        } else {
                            lifecycleScope.launch {
                                val bytes = withContext(Dispatchers.IO) {
                                    getAppIconBytes(pkg)
                                }
                                result.success(bytes)
                            }
                        }
                    }
                    "scheduleExactEyeReminder" -> {
                        val seconds = (call.argument<Number>("seconds"))?.toLong() ?: EyeAlarmReceiver.DEFAULT_CYCLE_SECONDS
                        val effectiveSec = if (seconds > 0L) seconds else EyeAlarmReceiver.DEFAULT_CYCLE_SECONDS
                        EyeAlarmReceiver.scheduleAlarm(this@MainActivity, effectiveSec)
                        result.success(true)
                    }
                    "cancelExactEyeReminder" -> {
                        EyeAlarmReceiver.cancelAlarm(this@MainActivity)
                        result.success(true)
                    }
                    "openUsageSettings" -> {
                        openUsageSettings()
                        result.success(true)
                    }
                    "openHealthConnect" -> {
                        openHealthConnectOrSettings()
                        result.success(true)
                    }
                    "openPlayStoreHealthConnect" -> {
                        openPlayStoreForHealthConnect()
                        result.success(true)
                    }
                    "areNotificationsEnabled" -> {
                        val areEnabled = androidx.core.app.NotificationManagerCompat.from(this@MainActivity).areNotificationsEnabled()
                        result.success(areEnabled)
                    }
                    "openNotificationSettings" -> {
                        try {
                            val intent = Intent().apply {
                                action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$packageName")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(fallback)
                                result.success(true)
                            } catch (_: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        val isIgnoring = pm?.isIgnoringBatteryOptimizations(packageName) ?: false
                        result.success(isIgnoring)
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val fallback = Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(fallback)
                                result.success(true)
                            } catch (_: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // EventChannel for real-time reactive telephony/proximity streaming to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    MainApplication.instance?.onStateChangedListener = { inCall, proxNear, screenOn, mediaActive ->
                        isInCall = inCall
                        isProximityNear = proxNear
                        isScreenInteractive = screenOn
                        isMediaPlaying = mediaActive
                        emitCurrentState()
                    }
                    emitCurrentState()
                }

                override fun onCancel(arguments: Any?) {
                    MainApplication.instance?.onStateChangedListener = null
                    eventSink = null
                }
            })
    }

    private fun registerScreenReceiver() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_SCREEN_OFF -> {
                        isScreenInteractive = false
                        emitCurrentState()
                    }
                    Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> {
                        isScreenInteractive = true
                        emitCurrentState()
                    }
                }
            }
        }
        registerReceiver(screenReceiver, filter)
    }

    private fun registerSensors() {
        proximitySensor?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    private fun requestActivityRecognitionOnly() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val permissionStatus = ContextCompat.checkSelfPermission(this, Manifest.permission.ACTIVITY_RECOGNITION)
            if (permissionStatus != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
                    PERMISSION_REQUEST_ACTIVITY_RECOGNITION
                )
            }
        }
    }

    private fun registerTelephonyListener() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                telephonyManager?.registerTelephonyCallback(
                    mainExecutor,
                    object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                        override fun onCallStateChanged(state: Int) {
                            isInCall = (state != TelephonyManager.CALL_STATE_IDLE)
                            emitCurrentState()
                        }
                    }
                )
            } else {
                @Suppress("DEPRECATION")
                telephonyManager?.listen(object : PhoneStateListener() {
                    @Deprecated("Deprecated in Java")
                    override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                        isInCall = (state != TelephonyManager.CALL_STATE_IDLE)
                        emitCurrentState()
                    }
                }, PhoneStateListener.LISTEN_CALL_STATE)
            }
        } catch (_: Exception) {}
    }

    private fun unregisterTelephonyListener() {
        // Automatically cleaned up on destroy
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return
        if (event.sensor.type == Sensor.TYPE_PROXIMITY) {
            val distance = event.values[0]
            val maxRange = proximitySensor?.maximumRange ?: 5f
            // True physical proximity: either 0 cm or strictly close (< 1.5 cm and less than maxRange)
            val near = distance < 1.0f || (distance < maxRange && distance <= 1.5f)
            if (near != isProximityNear) {
                isProximityNear = near
                emitCurrentState()
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun registerAudioPlaybackListener() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                audioPlaybackCallback = object : AudioManager.AudioPlaybackCallback() {
                    override fun onPlaybackConfigChanged(configs: MutableList<AudioPlaybackConfiguration>?) {
                        super.onPlaybackConfigChanged(configs)
                        val active = checkIsMediaActive()
                        if (active != isMediaPlaying) {
                            isMediaPlaying = active
                            emitCurrentState()
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

    private fun checkIsGameActive(): Boolean {
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

    private fun checkIsMediaActive(): Boolean {
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

    private fun emitCurrentState() {
        val app = MainApplication.instance
        if (app != null) {
            isInCall = app.isInCall
            isProximityNear = app.isProximityNear
            isScreenInteractive = app.isScreenInteractive
            isMediaPlaying = app.isMediaPlaying
        } else {
            isMediaPlaying = checkIsMediaActive()
            isScreenInteractive = powerManager?.isInteractive ?: isScreenInteractive
        }

        runOnUiThread {
            eventSink?.success(
                mapOf(
                    "isInCall" to isInCall,
                    "isProximityNear" to isProximityNear,
                    "isScreenInteractive" to isScreenInteractive,
                    "isMediaPlaying" to isMediaPlaying
                )
            )
        }
    }

    // Health Connect status check using official HealthConnectClient SDK status
    private fun getHealthConnectStatus(): String {
        return try {
            val availability = HealthConnectClient.getSdkStatus(this)
            when (availability) {
                HealthConnectClient.SDK_AVAILABLE -> "available"
                HealthConnectClient.SDK_UNAVAILABLE -> "not_supported"
                HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "not_installed"
                else -> "not_supported"
            }
        } catch (_: Exception) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                "available"
            } else {
                "not_installed"
            }
        }
    }

    // Checks if READ_STEPS permission is currently granted
    private suspend fun checkHealthPermissionsGranted(): Boolean = withContext(Dispatchers.IO) {
        try {
            val client = HealthConnectClient.getOrCreate(this@MainActivity)
            val granted = client.permissionController.getGrantedPermissions()
            granted.containsAll(HEALTH_PERMISSIONS)
        } catch (_: Exception) {
            false
        }
    }

    // Aggregates today's total steps from Health Connect (from 00:00:00 to now)
    private suspend fun readTodaySteps(): Long = withContext(Dispatchers.IO) {
        try {
            val client = HealthConnectClient.getOrCreate(this@MainActivity)
            val now = Instant.now()
            val startOfDay = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant()

            val response = client.aggregate(
                AggregateRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                )
            )
            response[StepsRecord.COUNT_TOTAL] ?: 0L
        } catch (e: Exception) {
            0L
        }
    }

    // Aggregates total steps in a custom historical window (e.g. past 45 minutes)
    private suspend fun readStepsInWindow(startTimeMs: Long, endTimeMs: Long): Long = withContext(Dispatchers.IO) {
        try {
            val client = HealthConnectClient.getOrCreate(this@MainActivity)
            val start = Instant.ofEpochMilli(startTimeMs)
            val end = Instant.ofEpochMilli(endTimeMs)

            val response = client.aggregate(
                AggregateRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(start, end)
                )
            )
            response[StepsRecord.COUNT_TOTAL] ?: 0L
        } catch (e: Exception) {
            0L
        }
    }

    private suspend fun readTodayStepIntervals(): List<Map<String, Any>> = withContext(Dispatchers.IO) {
        try {
            val client = HealthConnectClient.getOrCreate(this@MainActivity)
            val now = Instant.now()
            val startOfDay = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant()

            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                )
            )
            response.records.map { record ->
                mapOf(
                    "startTimeMs" to record.startTime.toEpochMilli(),
                    "endTimeMs" to record.endTime.toEpochMilli(),
                    "steps" to record.count
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun openHealthConnectOrSettings() {
        val healthConnectPackage = "com.google.android.apps.healthdata"
        val intentsToTry = mutableListOf<Intent>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            intentsToTry.add(
                Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS").apply {
                    putExtra(Intent.EXTRA_PACKAGE_NAME, packageName)
                }
            )
            intentsToTry.add(Intent("android.health.connect.action.HEALTH_CONNECT_SETTINGS"))
        }

        intentsToTry.add(
            Intent("androidx.health.ACTION_MANAGE_HEALTH_PERMISSIONS").apply {
                putExtra(Intent.EXTRA_PACKAGE_NAME, packageName)
            }
        )
        intentsToTry.add(Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS"))

        packageManager.getLaunchIntentForPackage(healthConnectPackage)?.let {
            intentsToTry.add(it)
        }

        for (intent in intentsToTry) {
            try {
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    return
                }
            } catch (_: Exception) {}
        }

        try {
            val appSettingsIntent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
            }
            startActivity(appSettingsIntent)
        } catch (_: Exception) {
            try {
                val settingsIntent = Intent(android.provider.Settings.ACTION_SETTINGS)
                startActivity(settingsIntent)
            } catch (_: Exception) {}
        }
    }

    private fun openPlayStoreForHealthConnect() {
        val healthConnectPackage = "com.google.android.apps.healthdata"
        try {
            val marketIntent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("market://details?id=$healthConnectPackage")
            ).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(marketIntent)
        } catch (_: Exception) {
            val webIntent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("https://play.google.com/store/apps/details?id=$healthConnectPackage")
            ).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(webIntent)
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private suspend fun getDeviceDailyScreenTimeSeconds(): Long = withContext(Dispatchers.IO) {
        if (!hasUsageStatsPermission()) return@withContext 0L
        val calendar = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val startOfDay = calendar.timeInMillis
        val now = System.currentTimeMillis()
        if (now <= startOfDay) return@withContext 0L
        val data = getDeviceScreenAndRestBlocks(startOfDay, now)
        (data["activeScreenSeconds"] as? Long) ?: 0L
    }

    private suspend fun getDeviceScreenAndRestBlocks(startTimeMs: Long, endTimeMs: Long, requiredRestDurationMs: Long = 120000L): Map<String, Any> = withContext(Dispatchers.IO) {
        if (!hasUsageStatsPermission()) {
            return@withContext mapOf(
                "activeScreenSeconds" to 0L,
                "phoneRestSeconds" to 0L,
                "blocks" to emptyList<Map<String, Any>>()
            )
        }
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return@withContext mapOf(
                "activeScreenSeconds" to 0L,
                "phoneRestSeconds" to 0L,
                "blocks" to emptyList<Map<String, Any>>()
            )

        val queryStart = maxOf(0L, startTimeMs - (24 * 60 * 60 * 1000L))
        val now = System.currentTimeMillis()
        val queryEnd = minOf(endTimeMs, now)
        if (queryEnd <= startTimeMs) {
            return@withContext mapOf(
                "activeScreenSeconds" to 0L,
                "phoneRestSeconds" to 0L,
                "blocks" to emptyList<Map<String, Any>>()
            )
        }

        try {
            val events = usageStatsManager.queryEvents(queryStart, queryEnd)
            val event = UsageEvents.Event()

            val rawIntervals = mutableListOf<Pair<Long, Long>>()
            val appResumeTimes = mutableMapOf<String, Long>()
            val allAppSessions = mutableListOf<Triple<String, Long, Long>>()
            var lastScreenInteractiveStart: Long? = null
            var lastMusicPkg: String? = null
            var currentForegroundPkg: String? = null
            var currentForegroundStart: Long? = null

            val appNameCache = mutableMapOf<String, String>()
            fun resolveAppName(pkg: String): String {
                if (appNameCache.containsKey(pkg)) return appNameCache[pkg]!!
                val lower = pkg.lowercase()

                // Special system packages
                if (lower.contains("launcher") || lower.contains("home") || lower == "android" || lower.contains("systemui")) {
                    appNameCache[pkg] = "Home Screen"
                    return "Home Screen"
                }

                // Known apps dictionary for guaranteed, clean display names
                val knownName = when {
                    lower.contains("reset") || lower.contains("lifemint") || lower == "com.reset" -> "LifeMint"
                    lower.contains("bard") || lower.contains("gemini") -> "Gemini"
                    lower.contains("instagram") -> "Instagram"
                    lower.contains("w4b") || (lower.contains("whatsapp") && lower.contains("business")) -> "WhatsApp Business"
                    lower.contains("whatsapp") -> "WhatsApp"
                    lower.contains("messaging") || lower.contains("mms") || lower.contains(".message") -> "Messages"
                    lower.contains("youtube.music") || (lower.contains("youtube") && lower.contains("music")) -> "YouTube Music"
                    lower.contains("youtube") -> "YouTube"
                    lower.contains("chrome") -> "Chrome"
                    lower.contains("spotify") -> "Spotify"
                    lower.contains("gmail") || lower == "com.google.android.gm" -> "Gmail"
                    lower.contains("telegram") -> "Telegram"
                    lower.contains("netflix") -> "Netflix"
                    lower.contains("facebook.katana") || (lower.contains("facebook") && !lower.contains("orca")) -> "Facebook"
                    lower.contains("facebook.orca") || lower.contains("messenger") -> "Messenger"
                    lower.contains("snapchat") -> "Snapchat"
                    lower.contains("reddit") -> "Reddit"
                    lower.contains("twitter") || lower == "com.x.android" -> "X (Twitter)"
                    lower.contains("camera") -> "Camera"
                    lower.contains("gallery") || lower.contains("photos") -> "Photos"
                    lower.contains("dialer") || lower.contains("incallui") || lower.contains("telecom") || lower == "com.android.phone" -> "Phone"
                    else -> null
                }
                if (knownName != null) {
                    appNameCache[pkg] = knownName
                    return knownName
                }

                // Try resolving application label from PackageManager
                val label = try {
                    val appInfo = packageManager.getApplicationInfo(pkg, 0)
                    packageManager.getApplicationLabel(appInfo).toString()
                } catch (_: Exception) {
                    // Smart fallback: extract sensible name from package reverse-domain
                    val parts = pkg.split('.')
                    var candidate = parts.lastOrNull() ?: pkg
                    if (candidate.equals("android", ignoreCase = true) || 
                        candidate.equals("app", ignoreCase = true) || 
                        candidate.equals("mobile", ignoreCase = true) ||
                        candidate.equals("client", ignoreCase = true) ||
                        candidate.equals("ui", ignoreCase = true)) {
                        if (parts.size >= 2) {
                            candidate = parts[parts.size - 2]
                        }
                    }
                    if (candidate.isNotEmpty()) candidate.replaceFirstChar { it.uppercase() } else pkg
                }
                appNameCache[pkg] = label
                return label
            }

            // Track active activities per package to preserve multi-activity sessions (e.g. Feed <-> Reels)
            val resumedActivities = mutableMapOf<String, MutableSet<String>>()
            var isScreenOn = false

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                val time = event.timeStamp
                var pkg = event.packageName ?: ""
                val cls = event.className ?: ""

                // Detect Gemini / Bard running inside Google Search or as a companion
                if (pkg.contains("bard", ignoreCase = true) ||
                    (pkg == "com.google.android.googlequicksearchbox" && (cls.contains("gemini", ignoreCase = true) || cls.contains("bard", ignoreCase = true)))) {
                    pkg = "com.google.android.apps.bard"
                }

                if (pkg.contains("spotify") || pkg.contains("music") || pkg.contains("podcast") || pkg.contains("audio")) {
                    lastMusicPkg = pkg
                }

                when (event.eventType) {
                    UsageEvents.Event.SCREEN_INTERACTIVE,
                    UsageEvents.Event.KEYGUARD_HIDDEN -> {
                        isScreenOn = true
                        lastScreenInteractiveStart = time
                        if (currentForegroundPkg != null && currentForegroundStart == null) {
                            currentForegroundStart = time
                        }
                    }

                    UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                    UsageEvents.Event.KEYGUARD_SHOWN -> {
                        isScreenOn = false
                        val start = lastScreenInteractiveStart ?: currentForegroundStart
                        if (start != null && time > start) {
                            val clampedStart = maxOf(start, startTimeMs)
                            val clampedEnd = minOf(time, queryEnd)
                            if (clampedEnd > clampedStart) {
                                rawIntervals.add(Pair(clampedStart, clampedEnd))
                            }
                        }
                        lastScreenInteractiveStart = null

                        // Close active foreground app on screen lock
                        if (currentForegroundPkg != null && currentForegroundStart != null && time > currentForegroundStart!!) {
                            val clampedStart = maxOf(currentForegroundStart!!, startTimeMs)
                            val clampedEnd = minOf(time, queryEnd)
                            if (clampedEnd > clampedStart) {
                                rawIntervals.add(Pair(clampedStart, clampedEnd))
                                allAppSessions.add(Triple(currentForegroundPkg!!, clampedStart, clampedEnd))
                            }
                        }
                        currentForegroundPkg = null
                        currentForegroundStart = null
                        resumedActivities.clear()
                    }

                    UsageEvents.Event.ACTIVITY_RESUMED -> {
                        if (pkg.isNotEmpty()) {
                            val effectiveCls = if (cls.isNotEmpty()) cls else "Main"
                            resumedActivities.getOrPut(pkg) { mutableSetOf() }.add(effectiveCls)

                            if (isScreenOn || lastScreenInteractiveStart != null) {
                                if (pkg != currentForegroundPkg) {
                                    // Switching from old app to new app: close previous app
                                    if (currentForegroundPkg != null && currentForegroundStart != null && time > currentForegroundStart!!) {
                                        val clampedStart = maxOf(currentForegroundStart!!, startTimeMs)
                                        val clampedEnd = minOf(time, queryEnd)
                                        if (clampedEnd > clampedStart) {
                                            rawIntervals.add(Pair(clampedStart, clampedEnd))
                                            allAppSessions.add(Triple(currentForegroundPkg!!, clampedStart, clampedEnd))
                                        }
                                    }
                                    currentForegroundPkg = pkg
                                    currentForegroundStart = time
                                } else {
                                    // Same app resumed another activity (e.g. Feed -> Reels)
                                    if (currentForegroundStart == null) {
                                        currentForegroundStart = time
                                    }
                                }
                            } else {
                                isScreenOn = true
                                lastScreenInteractiveStart = time
                                currentForegroundPkg = pkg
                                currentForegroundStart = time
                            }
                        }
                    }

                    UsageEvents.Event.ACTIVITY_PAUSED,
                    UsageEvents.Event.ACTIVITY_STOPPED -> {
                        if (pkg.isNotEmpty()) {
                            val effectiveCls = if (cls.isNotEmpty()) cls else "Main"
                            val actSet = resumedActivities[pkg]
                            if (actSet != null) {
                                actSet.remove(effectiveCls)
                                // Only close the app if NO activities of this package remain active!
                                if (actSet.isEmpty()) {
                                    resumedActivities.remove(pkg)
                                    if (pkg == currentForegroundPkg && currentForegroundStart != null && time > currentForegroundStart!!) {
                                        val clampedStart = maxOf(currentForegroundStart!!, startTimeMs)
                                        val clampedEnd = minOf(time, queryEnd)
                                        if (clampedEnd > clampedStart) {
                                            rawIntervals.add(Pair(clampedStart, clampedEnd))
                                            allAppSessions.add(Triple(pkg, clampedStart, clampedEnd))
                                        }
                                        currentForegroundPkg = null
                                        currentForegroundStart = null
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Close any currently active sessions if screen is on
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            val isQueryingNow = (now - queryEnd) < 60000L
            val isCurrentlyInteractive = isQueryingNow && (powerManager?.isInteractive ?: true)
            if (isCurrentlyInteractive) {
                val effectiveStart = lastScreenInteractiveStart ?: currentForegroundStart
                if (effectiveStart != null && queryEnd > effectiveStart) {
                    val clampedStart = maxOf(effectiveStart, startTimeMs)
                    rawIntervals.add(Pair(clampedStart, queryEnd))
                }
                if (currentForegroundPkg != null && currentForegroundStart != null && queryEnd > currentForegroundStart!!) {
                    val clampedStart = maxOf(currentForegroundStart!!, startTimeMs)
                    rawIntervals.add(Pair(clampedStart, queryEnd))
                    allAppSessions.add(Triple(currentForegroundPkg!!, clampedStart, queryEnd))
                } else if (effectiveStart != null && queryEnd > effectiveStart) {
                    val clampedStart = maxOf(effectiveStart, startTimeMs)
                    rawIntervals.add(Pair(clampedStart, queryEnd))
                    allAppSessions.add(Triple(packageName, clampedStart, queryEnd))
                }
            }

            // Merge overlapping active intervals
            val sortedActive = rawIntervals.sortedBy { it.first }
            val mergedActive = mutableListOf<Pair<Long, Long>>()
            if (sortedActive.isNotEmpty()) {
                var curStart = sortedActive[0].first
                var curEnd = sortedActive[0].second
                for (i in 1 until sortedActive.size) {
                    val next = sortedActive[i]
                    if (next.first <= curEnd) {
                        curEnd = maxOf(curEnd, next.second)
                    } else {
                        mergedActive.add(Pair(curStart, curEnd))
                        curStart = next.first
                        curEnd = next.second
                    }
                }
                mergedActive.add(Pair(curStart, curEnd))
            }

            val isAudioActiveNow = audioManager?.isMusicActive == true

            // Contiguously partition the timeline into Phone Rest and Active Screen blocks!
            val allBlocks = mutableListOf<Map<String, Any>>()
            var cursor = startTimeMs
            var totalActiveMs = 0L
            var totalRestMs = 0L

            for (active in mergedActive) {
                if (active.first > cursor) {
                    val restDurationMs = active.first - cursor
                    if (restDurationMs >= 5000L) {
                        totalRestMs += restDurationMs
                        val isRecentRest = (queryEnd - active.first) < 120000L
                        val hasBgAudio = isRecentRest && isAudioActiveNow
                        allBlocks.add(
                            mapOf(
                                "startTime" to java.time.Instant.ofEpochMilli(cursor).toString(),
                                "endTime" to java.time.Instant.ofEpochMilli(active.first).toString(),
                                "type" to "phoneRest",
                                "durationSeconds" to (restDurationMs / 1000L).toInt(),
                                "hasBackgroundAudio" to hasBgAudio,
                                "audioAppName" to if (hasBgAudio) (lastMusicPkg?.let { resolveAppName(it) } ?: "Audio") else "",
                                "topApps" to emptyList<Map<String, Any>>()
                            )
                        )
                    }
                }

                val activeDurationMs = active.second - active.first
                if (activeDurationMs >= 3000L) {
                    totalActiveMs += activeDurationMs

                    // Calculate per-app breakdown inside this active screen window
                    val appsInBlock = mutableMapOf<String, Long>()
                    for (session in allAppSessions) {
                        val overlap = maxOf(0L, minOf(session.third, active.second) - maxOf(session.second, active.first))
                        if (overlap >= 1000L) {
                            appsInBlock[session.first] = (appsInBlock[session.first] ?: 0L) + overlap
                        }
                    }

                    val topAppsList = if (appsInBlock.isNotEmpty()) {
                        appsInBlock.entries
                            .sortedByDescending { it.value }
                            .take(4)
                            .map { entry ->
                                mapOf(
                                    "name" to resolveAppName(entry.key),
                                    "package" to entry.key,
                                    "seconds" to (entry.value / 1000L).toInt()
                                )
                            }
                    } else {
                        val isRecent = (now - active.second) < 60000L
                        listOf(
                            mapOf(
                                "name" to if (isRecent) "LifeMint" else "Screen Active",
                                "package" to if (isRecent) packageName else "",
                                "seconds" to (activeDurationMs / 1000L).toInt()
                            )
                        )
                    }

                    val isOverrun = activeDurationMs >= 2400000L // 40m+ marathon

                    allBlocks.add(
                        mapOf(
                            "startTime" to java.time.Instant.ofEpochMilli(active.first).toString(),
                            "endTime" to java.time.Instant.ofEpochMilli(active.second).toString(),
                            "type" to "activeScreen",
                            "durationSeconds" to (activeDurationMs / 1000L).toInt(),
                            "hasBackgroundAudio" to false,
                            "audioAppName" to "",
                            "isOverrun" to isOverrun,
                            "topApps" to topAppsList
                        )
                    )
                }
                cursor = maxOf(cursor, active.second)
            }

            // Trailing rest block up to queryEnd
            if (cursor < queryEnd) {
                val trailingRestMs = queryEnd - cursor
                if (trailingRestMs >= 5000L) {
                    totalRestMs += trailingRestMs
                    val hasBgAudio = isAudioActiveNow
                    allBlocks.add(
                        mapOf(
                            "startTime" to java.time.Instant.ofEpochMilli(cursor).toString(),
                            "endTime" to java.time.Instant.ofEpochMilli(queryEnd).toString(),
                            "type" to "phoneRest",
                            "durationSeconds" to (trailingRestMs / 1000L).toInt(),
                            "hasBackgroundAudio" to hasBgAudio,
                            "audioAppName" to if (hasBgAudio) (lastMusicPkg?.let { resolveAppName(it) } ?: "Audio") else "",
                            "topApps" to emptyList<Map<String, Any>>()
                        )
                    )
                }
            }

            // Compute current continuous active screen time (since last rest >= required rest duration)
            var continuousActiveSec = 0L
            if (isCurrentlyInteractive && mergedActive.isNotEmpty()) {
                val lastActive = mergedActive.last()
                if (queryEnd - lastActive.second <= 15000L) {
                    var curContinuousMs = lastActive.second - lastActive.first
                    for (i in mergedActive.size - 2 downTo 0) {
                        val prev = mergedActive[i]
                        val gap = mergedActive[i + 1].first - prev.second
                        if (gap < requiredRestDurationMs) {
                            curContinuousMs += (prev.second - prev.first)
                        } else {
                            break
                        }
                    }
                    continuousActiveSec = curContinuousMs / 1000L
                }
            }

            // Aggregate all individual app sessions across the day into cumulative app summary with intervals
            val appIntervalsMap = mutableMapOf<String, MutableList<Pair<Long, Long>>>()
            for (session in allAppSessions) {
                val pkg = session.first
                val lower = pkg.lowercase()
                // Map system launcher / home packages to normalized "com.android.launcher"
                val effectivePkg = if (lower.contains("launcher") || lower.contains("home") || lower == "android" || lower.contains("systemui")) {
                    "com.android.launcher"
                } else {
                    pkg
                }
                val start = session.second
                val end = session.third
                if (end > start) {
                    appIntervalsMap.getOrPut(effectivePkg) { mutableListOf() }.add(Pair(start, end))
                }
            }

            val appSummaryList = appIntervalsMap.entries.mapNotNull { entry ->
                val pkg = entry.key
                val rawList = entry.value
                if (rawList.isEmpty()) return@mapNotNull null

                // 1. Sort raw intervals chronologically
                val sorted = rawList.sortedBy { it.first }

                // 2. Merge overlapping or sub-activity transition intervals (<= 3.5s gap within same app)
                val merged = mutableListOf<Pair<Long, Long>>()
                var curStart = sorted[0].first
                var curEnd = sorted[0].second

                for (i in 1 until sorted.size) {
                    val next = sorted[i]
                    if (next.first <= curEnd + 3500L) {
                        curEnd = maxOf(curEnd, next.second)
                    } else {
                        merged.add(Pair(curStart, curEnd))
                        curStart = next.first
                        curEnd = next.second
                    }
                }
                merged.add(Pair(curStart, curEnd))

                if (merged.isEmpty()) return@mapNotNull null

                val totalSec = merged.sumOf { (it.second - it.first) / 1000L }.toInt()
                if (totalSec < 5) return@mapNotNull null

                mapOf(
                    "name" to resolveAppName(pkg),
                    "package" to pkg,
                    "totalSeconds" to totalSec,
                    "intervals" to merged.map { interval ->
                        mapOf(
                            "startTime" to java.time.Instant.ofEpochMilli(interval.first).toString(),
                            "endTime" to java.time.Instant.ofEpochMilli(interval.second).toString(),
                            "durationSeconds" to ((interval.second - interval.first) / 1000L).toInt()
                        )
                    }
                )
            }.sortedByDescending { it["totalSeconds"] as Int }

            mapOf(
                "activeScreenSeconds" to (totalActiveMs / 1000L),
                "phoneRestSeconds" to (totalRestMs / 1000L),
                "currentContinuousActiveSeconds" to continuousActiveSec,
                "blocks" to allBlocks,
                "appSummary" to appSummaryList
            )
        } catch (e: Exception) {
            mapOf(
                "activeScreenSeconds" to 0L,
                "phoneRestSeconds" to 0L,
                "currentContinuousActiveSeconds" to 0L,
                "blocks" to emptyList<Map<String, Any>>(),
                "appSummary" to emptyList<Map<String, Any>>()
            )
        }
    }

    private fun getAppIconBytes(packageName: String): ByteArray? {
        return try {
            var drawable: Drawable? = null
            val isGemini = packageName == "com.google.android.apps.bard" ||
                    packageName.contains("bard", ignoreCase = true) ||
                    packageName.contains("gemini", ignoreCase = true)

            if (isGemini) {
                // 1. Try getApplicationIcon for com.google.android.apps.bard
                try {
                    drawable = packageManager.getApplicationIcon("com.google.android.apps.bard")
                } catch (_: Exception) {}

                // 2. Try getLaunchIntentForPackage
                if (drawable == null) {
                    try {
                        val launchIntent = packageManager.getLaunchIntentForPackage("com.google.android.apps.bard")
                        if (launchIntent != null) {
                            drawable = packageManager.getActivityIcon(launchIntent)
                        }
                    } catch (_: Exception) {}
                }

                // 3. Search launcher activities for Gemini
                if (drawable == null) {
                    try {
                        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_LAUNCHER)
                        }
                        val resolveList = packageManager.queryIntentActivities(launcherIntent, 0)
                        val geminiResolve = resolveList.firstOrNull { ri ->
                            ri.activityInfo.packageName.contains("bard") ||
                            ri.activityInfo.packageName.contains("gemini") ||
                            ri.activityInfo.name.contains("gemini", ignoreCase = true) ||
                            ri.activityInfo.name.contains("bard", ignoreCase = true) ||
                            ri.loadLabel(packageManager).toString().equals("Gemini", ignoreCase = true)
                        }
                        if (geminiResolve != null) {
                            drawable = geminiResolve.loadIcon(packageManager)
                        }
                    } catch (_: Exception) {}
                }

                // 4. Query all activities in com.google.android.googlequicksearchbox
                if (drawable == null) {
                    try {
                        val pkgInfo = packageManager.getPackageInfo("com.google.android.googlequicksearchbox", PackageManager.GET_ACTIVITIES)
                        val geminiAct = pkgInfo.activities?.firstOrNull { act ->
                            act.name.contains("gemini", ignoreCase = true) || act.name.contains("bard", ignoreCase = true)
                        }
                        if (geminiAct != null) {
                            drawable = geminiAct.loadIcon(packageManager)
                        }
                    } catch (_: Exception) {}
                }
            } else {
                try {
                    drawable = packageManager.getApplicationIcon(packageName)
                } catch (_: Exception) {}

                if (drawable == null) {
                    try {
                        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                        if (launchIntent != null) {
                            drawable = packageManager.getActivityIcon(launchIntent)
                        }
                    } catch (_: Exception) {}
                }
            }

            if (drawable == null) return null

            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth.coerceIn(48, 192) else 96
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight.coerceIn(48, 192) else 96
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, width, height)
            drawable.draw(canvas)

            val outputStream = ByteArrayOutputStream()
            bmp.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            outputStream.toByteArray()
        } catch (_: Exception) {
            null
        }
    }

    private fun openUsageSettings() {
        val fragmentArgs = Bundle().apply {
            putString(":settings:fragment_args_key", packageName)
            putString("package", packageName)
            putString(Intent.EXTRA_PACKAGE_NAME, packageName)
            putString("app_package", packageName)
        }

        // ACTION_USAGE_ACCESS_SETTINGS with package target data & indication extras.
        // Samsung One UI requires 'data = Uri.fromParts("package", ...)' and package extras
        // to recognize the target app and trigger the blue highlight/indication animation.
        try {
            val intent = Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
                putExtra(":settings:fragment_args_key", packageName)
                putExtra(":settings:show_fragment_args", fragmentArgs)
                putExtra(Intent.EXTRA_PACKAGE_NAME, packageName)
                putExtra("package", packageName)
                putExtra("app_package", packageName)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return
            }
        } catch (_: Exception) {}

        // Fallback to general settings
        try {
            val intent = Intent(android.provider.Settings.ACTION_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        } catch (_: Exception) {}
    }

    override fun onPause() {
        super.onPause()
        persistSessionAndClocksOnBackground()
    }

    override fun onStop() {
        super.onStop()
        persistSessionAndClocksOnBackground()
    }

    private fun persistSessionAndClocksOnBackground() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val uptime = android.os.SystemClock.uptimeMillis()
            val elapsed = android.os.SystemClock.elapsedRealtime()
            val now = System.currentTimeMillis()
            val editor = prefs.edit()
            editor.putLong("rhythm_last_uptime_ms", uptime)
            editor.putLong("flutter.rhythm_last_uptime_ms", uptime)
            editor.putLong("rhythm_last_elapsed_ms", elapsed)
            editor.putLong("flutter.rhythm_last_elapsed_ms", elapsed)
            editor.putLong("rhythm_last_active_timestamp_ms", now)
            editor.putLong("flutter.rhythm_last_active_timestamp_ms", now)
            editor.apply()

            val targetSec = maxOf(
                EyeAlarmReceiver.getSafeLong(prefs, "flutter.rhythm_cycle_target_seconds"),
                EyeAlarmReceiver.getSafeLong(prefs, "rhythm_cycle_target_seconds"),
                EyeAlarmReceiver.DEFAULT_CYCLE_SECONDS
            )
            val currentSession = maxOf(
                EyeAlarmReceiver.getSafeLong(prefs, "flutter.rhythm_current_session_seconds"),
                EyeAlarmReceiver.getSafeLong(prefs, "rhythm_current_session_seconds"),
                EyeAlarmReceiver.getSafeLong(prefs, "continuous_screen_seconds")
            )
            val cycleLap = if (targetSec > 0L) (targetSec - (currentSession % targetSec)) else targetSec
            val remaining = if (cycleLap > 5L) cycleLap else targetSec
            EyeAlarmReceiver.scheduleAlarm(this, remaining)
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        MainApplication.instance?.onStateChangedListener = null
        eventSink = null
        super.onDestroy()
    }
}
