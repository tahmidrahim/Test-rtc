package com.example.hapi

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import com.rtcone.sdk.RtcServiceSdk
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.webrtc.EglBase
import org.webrtc.SurfaceViewRenderer

class FunintRtcPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var rtc: RtcServiceSdk? = null
    private var eventSink: EventChannel.EventSink? = null
    private var isVideoMode = false

    private val activeRemoteUsers = mutableSetOf<String>()
    private val SCREEN_SHARE_REQUEST_CODE = 1001
    private val TAG = "FunintRTC"
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        var localRenderer: SurfaceViewRenderer? = null
        var remoteRenderer: SurfaceViewRenderer? = null
        val rootEglBase: EglBase by lazy { EglBase.create() }
        
        // Flag to prevent multiple attaches
        var renderersAttached = false
    }

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

        binding.platformViewRegistry.registerViewFactory(
            "funint_rtc_video_view",
            RtcVideoViewFactory(binding.applicationContext)
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        releaseRtc()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }
    override fun onDetachedFromActivity() { activity = null }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != SCREEN_SHARE_REQUEST_CODE) return false
        if (resultCode == Activity.RESULT_OK && data != null) {
            rtc?.startScreenShare(data, object : MediaProjection.Callback() {
                override fun onStop() {
                    emit("screenShareStopped")
                }
            })
            emit("screenShareStarted")
        } else {
            emitError("Screen share permission denied")
        }
        return true
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "join" -> handleJoin(call, result)
            "refreshToken" -> handleRefreshToken(call, result)
            "attachRenderers" -> {
                val local = localRenderer
                val remote = remoteRenderer
                if (local != null && remote != null && rtc != null) {
                    if (!renderersAttached) {
                        rtc?.attachRenderers(local, remote)
                        renderersAttached = true
                        Log.d(TAG, "attachRenderers called from Flutter - success")
                        result.success(null)
                    } else {
                        Log.d(TAG, "attachRenderers already attached - skipping")
                        result.success(null)
                    }
                } else {
                    result.error("NOT_READY", "Renderers or RTC not ready", null)
                }
            }
            "leave" -> {
                releaseRtc()
                result.success(null)
            }
            "muteAudio" -> {
                rtc?.muteLocalAudio(call.argument<Boolean>("mute") ?: true)
                result.success(null)
            }
            "setVideoEnabled" -> {
                rtc?.setLocalVideoEnabled(call.argument<Boolean>("enabled") ?: false)
                result.success(null)
            }
            "setNoiseCancellation" -> {
                rtc?.setNoiseCancellationEnabled(call.argument<Boolean>("enabled") ?: true)
                result.success(null)
            }
            "setSpeakerphone" -> {
                rtc?.setSpeakerphoneOn(call.argument<Boolean>("on") ?: true)
                result.success(null)
            }
            "sendMessage" -> {
                val message = call.argument<String>("message")
                if (message.isNullOrEmpty()) {
                    result.error("NO_MESSAGE", "message required", null)
                    return
                }
                rtc?.sendMessage(message)
                result.success(null)
            }
            "startScreenShare" -> {
                val manager = context.getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                        as MediaProjectionManager
                activity?.startActivityForResult(
                    manager.createScreenCaptureIntent(),
                    SCREEN_SHARE_REQUEST_CODE
                ) ?: result.error("NO_ACTIVITY", "Activity not attached", null)
                result.success(null)
            }
            "stopScreenShare" -> {
                rtc?.stopScreenShare()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleJoin(call: MethodCall, result: MethodChannel.Result) {
        val token = call.argument<String>("token")
            ?: return result.error("NO_TOKEN", "token required", null)
        val roomId = call.argument<String>("roomId")
            ?: return result.error("NO_ROOM", "roomId required", null)
        val rtcMode = call.argument<String>("rtcMode") ?: "voice"

        releaseRtc()
        activeRemoteUsers.clear()
        isVideoMode = rtcMode == "video"

        val config = if (isVideoMode) {
            RtcServiceSdk.Config.videoCall("https://funint.online", token, roomId)
        } else {
            RtcServiceSdk.Config.audioRoom("https://funint.online", token, roomId)
        }

        rtc = RtcServiceSdk(context, config, buildListener(roomId))
        
        // Reset attach flag for new session
        renderersAttached = false

        if (isVideoMode) {
            rtc?.connectAndJoinVideoCall(roomId, RtcServiceSdk.VideoEffects.natural().toJson())
        } else {
            rtc?.connectAndJoin()
        }

        result.success(null)
    }

    private fun handleRefreshToken(call: MethodCall, result: MethodChannel.Result) {
        val token = call.argument<String>("token")
            ?: return result.error("NO_TOKEN", "token required", null)
        val roomId = call.argument<String>("roomId")
            ?: return result.error("NO_ROOM", "roomId required", null)
        val rtcMode = call.argument<String>("rtcMode") ?: "voice"

        Log.d(TAG, "Refreshing token for room $roomId")
        releaseRtc()

        val config = if (rtcMode == "video") {
            RtcServiceSdk.Config.videoCall("https://funint.online", token, roomId)
        } else {
            RtcServiceSdk.Config.audioRoom("https://funint.online", token, roomId)
        }

        rtc = RtcServiceSdk(context, config, buildListener(roomId))
        renderersAttached = false
        
        if (isVideoMode) rtc?.connectAndJoinVideoCall(roomId, RtcServiceSdk.VideoEffects.natural().toJson())
        else rtc?.connectAndJoin()

        result.success(null)
    }

    private fun buildListener(roomId: String): RtcServiceSdk.Listener {
        return object : RtcServiceSdk.Listener {
            override fun onConnected(socketId: String) {
                Log.d(TAG, "Socket connected: $socketId")
                emit("connected", mapOf("socketId" to socketId))
            }
            override fun onRoomJoined(roomId: String) {
                Log.d(TAG, "Room joined: $roomId")
                emit("joinedChannel", mapOf("channel" to roomId))
            }
            override fun onLocalStream(stream: org.webrtc.MediaStream) {
                Log.d(TAG, "Local stream ready: ${stream.id}")
                emit("localStream", mapOf("streamId" to stream.id))
            }
            override fun onRemoteStream(stream: org.webrtc.MediaStream) {
                val uid = stream.id
                Log.d(TAG, "Remote stream: $uid")
                if (!activeRemoteUsers.contains(uid)) {
                    activeRemoteUsers.add(uid)
                    emit("remoteUserJoined", mapOf("uid" to uid))
                }
            }
            override fun onRtcConnectionIndicatorChanged(indicator: RtcServiceSdk.ConnectionIndicator) {
                Log.d(TAG, "Connection state: ${indicator.name}")
                emit("connectionState", mapOf("state" to indicator.name))
                if (indicator == RtcServiceSdk.ConnectionIndicator.FAILED ||
                    indicator == RtcServiceSdk.ConnectionIndicator.DISCONNECTED) {
                    val departed = activeRemoteUsers.toList()
                    activeRemoteUsers.clear()
                    departed.forEach { uid ->
                        emit("remoteUserLeft", mapOf("uid" to uid))
                    }
                }
            }
            override fun onError(message: String) {
                Log.e(TAG, "RTC error: $message")
                emitError(message)
            }
        }
    }

    private fun releaseRtc() {
        // Follow the official SDK lifecycle: leaveRoom() then release()
        rtc?.leaveRoom()
        rtc?.release()
        rtc = null
        
        // Clear renderer references
        localRenderer = null
        remoteRenderer = null
        
        // Reset attach flag
        renderersAttached = false
        
        activeRemoteUsers.clear()
        Log.d(TAG, "RTC released and renderers cleared")
    }

    private fun emit(event: String, extra: Map<String, Any?> = emptyMap()) {
        val payload = mutableMapOf<String, Any?>("event" to event)
        payload.putAll(extra)
        mainHandler.post { eventSink?.success(payload) }
    }

    private fun emitError(message: String) {
        emit("error", mapOf("message" to message))
    }
}

class RtcVideoViewFactory(private val context: Context) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        val isLocal = (args as? Map<*, *>)?.get("isLocal") as? Boolean ?: true
        return RtcVideoView(context, isLocal)
    }
}

class RtcVideoView(context: Context, private val isLocal: Boolean) : PlatformView {
    private val renderer = SurfaceViewRenderer(context)

    init {
        renderer.init(FunintRtcPlugin.rootEglBase.eglBaseContext, null)
        renderer.setEnableHardwareScaler(true)
        renderer.setMirror(isLocal)
        renderer.setZOrderOnTop(true)
        renderer.setZOrderMediaOverlay(true)

        if (isLocal) {
            FunintRtcPlugin.localRenderer = renderer
        } else {
            FunintRtcPlugin.remoteRenderer = renderer
        }
        
        // Try to attach if both renderers exist and SDK is ready
        if (FunintRtcPlugin.localRenderer != null && 
            FunintRtcPlugin.remoteRenderer != null && 
            !FunintRtcPlugin.renderersAttached) {
            // We don't auto-attach here - let Flutter call attachRenderers
        }
    }

    override fun getView(): View = renderer

    override fun dispose() {
        renderer.release()
        if (isLocal && FunintRtcPlugin.localRenderer == renderer) {
            FunintRtcPlugin.localRenderer = null
        }
        if (!isLocal && FunintRtcPlugin.remoteRenderer == renderer) {
            FunintRtcPlugin.remoteRenderer = null
        }
    }
}