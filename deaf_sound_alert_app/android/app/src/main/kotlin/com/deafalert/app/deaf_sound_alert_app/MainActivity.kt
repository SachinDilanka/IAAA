package com.deafalert.app.deaf_sound_alert_app

import android.content.Context
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), RecognitionListener {
    private val FLASHLIGHT_CHANNEL = "com.deafalert.app/flashlight"
    private val SPEECH_CHANNEL = "com.deafalert.app/speech"
    private val SPEECH_EVENTS_CHANNEL = "com.deafalert.app/speech/events"

    private var cameraManager: CameraManager? = null
    private var cameraId: String? = null
    private val handler = Handler(Looper.getMainLooper())
    private val activeRunnables = mutableListOf<Runnable>()
    private var speechRecognizer: SpeechRecognizer? = null
    private var speechEventSink: EventChannel.EventSink? = null
    private var isListening = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Flashlight Channel Setup
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLASHLIGHT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasFlashlight" -> result.success(cameraId != null)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "isAvailable" -> result.success(
                            SpeechRecognizer.isRecognitionAvailable(applicationContext)
                        )
                        "startListening" -> {
                            isListening = true
                            startSpeechRecognizer()
                            result.success(true)
                        }
                        "stopListening" -> {
                            isListening = false
                            stopSpeechRecognizer()
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_EVENTS_CHANNEL)
                .setStreamHandler(object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        speechEventSink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        speechEventSink = null
                    }
                })
        }

        private fun startSpeechRecognizer() {
            handler.post {
                if (!isListening) return@post
                try {
                    if (speechRecognizer == null) {
                        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(applicationContext)
                        speechRecognizer?.setRecognitionListener(this)
                    }
                    val intent = android.content.Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "en-US")
                        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
                        putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                    }
                    speechRecognizer?.startListening(intent)
                } catch (error: Exception) {
                    speechEventSink?.success(mapOf("type" to "error", "text" to error.message))
                }
            }
        }

        private fun stopSpeechRecognizer() {
            handler.post {
                try {
                    speechRecognizer?.cancel()
                    speechRecognizer?.destroy()
                } finally {
                    speechRecognizer = null
                }
            }
        }

        private fun emitSpeech(type: String, text: String) {
            if (isListening) {
                speechEventSink?.success(mapOf("type" to type, "text" to text))
            }
        }

        override fun onPartialResults(results: Bundle?) {
            results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull()?.let { emitSpeech("partialResult", it) }
        }

        override fun onResults(results: Bundle?) {
            results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull()?.let { emitSpeech("finalResult", it) }
            if (isListening) {
                handler.postDelayed({ startSpeechRecognizer() }, 250)
            }
        }

        override fun onError(error: Int) {
            if (isListening) {
                handler.postDelayed({ startSpeechRecognizer() }, 500)
            }
        }

        override fun onReadyForSpeech(params: Bundle?) {}
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onEvent(eventType: Int, params: Bundle?) {}

    // Flashlight Helpers
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

        val finalOff = Runnable {
            setTorchMode(false)
        }
        activeRunnables.add(finalOff)
        handler.postDelayed(finalOff, totalDelay)
    }
}
