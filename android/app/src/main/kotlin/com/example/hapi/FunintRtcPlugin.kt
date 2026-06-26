package com.example.hapi

import android.content.Context
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import com.rtcone.sdk.RtcServiceSdk
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FunintRtcPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private var rtc: RtcServiceSdk? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "funint_rtc/methods")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "funint_rtc/events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        rtc?.leaveRoom()
        rtc?.release()
        rtc = null
    }

    private fun forceAudioToSpeaker() {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        audioManager.isSpeakerphoneOn = true
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL)
        audioManager.setStreamVolume(AudioManager.STREAM_VOICE_CALL, maxVolume, 0)
        rtc?.setSpeakerphoneOn(true)
        rtc?.setNoiseCancellationEnabled(true)
        android.util.Log.d("FunintRTC", "forceAudioToSpeaker: mode=${audioManager.mode} speaker=${audioManager.isSpeakerphoneOn} vol=$maxVolume")
    }

    private fun resetAudio() {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.mode = AudioManager.MODE_NORMAL
        audioManager.isSpeakerphoneOn = false
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "join" -> {
                val token = call.argument<String>("token") ?: return result.error("NO_TOKEN", "token required", null)
                val roomId = call.argument<String>("roomId") ?: return result.error("NO_ROOM", "roomId required", null)

                rtc?.release()
                rtc = RtcServiceSdk(
                    context = context,
                    config = RtcServiceSdk.Config.audioRoom(
                        signalingUrl = "https://funint.online",
                        accessToken = token,
                        roomId = roomId
                    ),
                    listener = object : RtcServiceSdk.Listener {
                        override fun onConnected(socketId: String) {
                            Handler(Looper.getMainLooper()).post {
                                eventSink?.success(mapOf("event" to "connected", "socketId" to socketId))
                            }
                        }
                        override fun onRoomJoined(roomId: String) {
                            Handler(Looper.getMainLooper()).postDelayed({
                                forceAudioToSpeaker()
                            }, 1000)
                            Handler(Looper.getMainLooper()).post {
                                eventSink?.success(mapOf("event" to "joinedChannel", "channel" to roomId))
                            }
                        }
                        override fun onLocalStream(stream: org.webrtc.MediaStream) {
                            Handler(Looper.getMainLooper()).post {
                                eventSink?.success(mapOf("event" to "localStream"))
                            }
                        }
                        override fun onRemoteStream(stream: org.webrtc.MediaStream) {
                            Handler(Looper.getMainLooper()).post {
                                eventSink?.success(mapOf("event" to "remoteUserJoined", "uid" to stream.id))
                            }
                        }
                        override fun onRtcConnectionIndicatorChanged(indicator: RtcServiceSdk.ConnectionIndicator) {
                            if (indicator.name == "PEER_CONNECTED") {
                                Handler(Looper.getMainLooper()).postDelayed({
                                    forceAudioToSpeaker()
                                }, 500)
                            }
                            Handler(Looper.getMainLooper()).post {
                                eventSink?.success(mapOf("event" to "connectionState", "state" to indicator.name))
                            }
                        }
                        override fun onError(message: String) {
                            Handler(Looper.getMainLooper()).post {
                                eventSink?.success(mapOf("event" to "error", "message" to message))
                            }
                        }
                    }
                )
                rtc?.connectAndJoin()
                result.success(null)
            }

            "leave" -> {
                rtc?.leaveRoom()
                rtc?.release()
                rtc = null
                resetAudio()
                result.success(null)
            }

            "muteAudio" -> {
                val mute = call.argument<Boolean>("mute") ?: true
                rtc?.muteLocalAudio(mute)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}