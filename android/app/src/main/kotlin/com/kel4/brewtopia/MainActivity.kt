package com.kel4.brewtopia

import android.content.Context
import android.database.ContentObserver
import android.media.AudioManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Menjembatani volume media HP ke Flutter (baca, atur, dan dengarkan perubahan tombol volume)
 * supaya slider volume di Pengaturan selalu sinkron dengan volume HP.
 */
class MainActivity : FlutterActivity() {
    private var observer: ContentObserver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        volumeControlStream = AudioManager.STREAM_MUSIC // tombol volume selalu mengatur volume media
    }

    private fun current(am: AudioManager): Double {
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        return if (max == 0) 0.0 else am.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "brewtopia/volume").setMethodCallHandler { call, result ->
            when (call.method) {
                "get" -> result.success(current(am))
                "set" -> {
                    val v = (call.argument<Double>("value") ?: 0.5).coerceIn(0.0, 1.0)
                    val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    am.setStreamVolume(AudioManager.STREAM_MUSIC, Math.round(v * max).toInt(), 0)
                    result.success(current(am))
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "brewtopia/volume_events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
                    override fun onChange(selfChange: Boolean) {
                        events?.success(current(am))
                    }
                }
                contentResolver.registerContentObserver(Settings.System.CONTENT_URI, true, observer!!)
            }

            override fun onCancel(arguments: Any?) {
                observer?.let { contentResolver.unregisterContentObserver(it) }
                observer = null
            }
        })
    }
}
