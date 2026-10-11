package com.deafalert.app.deaf_sound_alert_app

import android.content.Context
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.deafalert.app/flashlight"
    private val BG_CHANNEL = "com.deafalert.app/background_service"
    private var cameraManager: CameraManager? = null
    private var cameraId: String? = null
    private val handler = Handler(Looper.getMainLooper())
    private val activeRunnables = mutableListOf<Runnable>()

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                android.view.WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BG_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    BackgroundAudioService.startService(this)
                    result.success(true)
                }
                "stopService" -> {
                    BackgroundAudioService.stopService(this)
                    result.success(true)
                }
                "wakeScreen" -> {
                    BackgroundAudioService.wakeScreen(this)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                        setShowWhenLocked(true)
                        setTurnScreenOn(true)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        try {
            cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val ids = cameraManager?.cameraIdList ?: emptyArray()
            for (id in ids) {
                val characteristics = cameraManager?.getCameraCharacteristics(id)
                val hasFlash = characteristics?.get(android.hardware.camera2.CameraCharacteristics.FLASH_INFO_AVAILABLE)
                if (hasFlash == true) {
                    cameraId = id
                    break
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasFlashlight" -> {
                    result.success(cameraId != null)
                }
                "turnOn" -> {
                    cancelFlashing()
                    setTorchMode(true)
                    result.success(true)
                }
                "turnOff" -> {
                    cancelFlashing()
                    setTorchMode(false)
                    result.success(true)
                }
                "flashPattern" -> {
                    val pattern = call.argument<List<Int>>("pattern")
                    if (pattern != null) {
                        flashPattern(pattern)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setTorchMode(enabled: Boolean) {
        try {
            if (cameraId != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                cameraManager?.setTorchMode(cameraId!!, enabled)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun cancelFlashing() {
        for (r in activeRunnables) {
            handler.removeCallbacks(r)
        }
        activeRunnables.clear()
    }

    private fun flashPattern(pattern: List<Int>) {
        cancelFlashing()
        var totalDelay = 0L
        var isOn = true

        for (duration in pattern) {
            val delay = totalDelay
            val state = isOn
            val r = Runnable {
                setTorchMode(state)
            }
            activeRunnables.add(r)
            handler.postDelayed(r, delay)

            totalDelay += duration.toLong()
            isOn = !isOn
        }

        // Final safety turn off after pattern finishes
        val finalOff = Runnable {
            setTorchMode(false)
        }
        activeRunnables.add(finalOff)
        handler.postDelayed(finalOff, totalDelay)
    }
}

