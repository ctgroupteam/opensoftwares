package com.opensoftwares.crm

import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.opensoftwares.crm/audio"
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "playSound") {
                val soundName = call.argument<String>("sound") ?: "sound_reminder"
                try {
                    mediaPlayer?.release()
                    val resId = resources.getIdentifier(soundName, "raw", packageName)
                    if (resId != 0) {
                        mediaPlayer = MediaPlayer.create(this, resId)
                        mediaPlayer?.start()
                        mediaPlayer?.setOnCompletionListener {
                            it.release()
                            mediaPlayer = null
                        }
                        result.success(true)
                    } else {
                        result.error("NOT_FOUND", "Sound resource not found", null)
                    }
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        mediaPlayer?.release()
        mediaPlayer = null
        super.onDestroy()
    }
}
