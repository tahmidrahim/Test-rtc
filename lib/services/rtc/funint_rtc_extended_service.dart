import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────
// RTC event types emitted from the Kotlin plugin
// ─────────────────────────────────────────────
enum FunintRtcEvent {
  initialized,
  connected,
  joinedChannel,
  localStream,
  remoteUserJoined,
  remoteUserLeft,
  connectionState,
  messageReceived,
  messageSent,
  screenShareStarted,
  screenShareStopped,
  userMuteAudio,
  leftChannel,
  error,
  unknown,
}

class FunintRtcEventData {
  final FunintRtcEvent event;
  final Map<String, dynamic> raw;

  FunintRtcEventData(this.event, this.raw);

  String? get channel => raw['channel'] as String?;
  String? get uid => raw['uid'] as String?;
  String? get message => raw['message'] as String?;
  String? get sender => raw['sender'] as String?;
  String? get state => raw['state'] as String?;
  bool? get muted => raw['muted'] as bool?;
}

// ─────────────────────────────────────────────
// Permission sets per mode
// ─────────────────────────────────────────────
class _Permissions {
  static const voice = ['join', 'publish_audio', 'chat', 'signal'];

  static const video = [
    'join',
    'publish_audio',
    'publish_video',
    'chat',
    'signal',
  ];

  static const videoWithScreenShare = [
    'join',
    'publish_audio',
    'publish_video',
    'screen_share',
    'chat',
    'signal',
  ];
}

// ─────────────────────────────────────────────
// Main service
// ─────────────────────────────────────────────
class FunintRtcExtended {
  static const _methodChannel = MethodChannel('funint_rtc/methods');
  static const _eventChannel = EventChannel('funint_rtc/events');

  // ── Credentials (keep on backend in production) ──
  static const _apiBase = 'https://funint.online';
  static const _apiKey =
      'rtc_4e9a6e6fd43145b0b73b91194b4aafe4a0fbd908ef874457bf7767962978a6dc';
  static const _appName = 'hapi-app-01';

  // ── State ──
  bool _initialized = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  String? _currentRoomId;
  String? _currentUserId;
  String? _currentMode;
  DateTime? _tokenIssuedAt;
  Timer? _tokenRefreshTimer;

  final _eventController = StreamController<FunintRtcEventData>.broadcast();

  Stream<FunintRtcEventData> get events => _eventController.stream;

  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isInRoom => _currentRoomId != null;
  String? get currentRoomId => _currentRoomId;

  // ─────────────────────────────────────────────
  // Initialize — call once, e.g. in app startup
  // ─────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _eventChannel.receiveBroadcastStream().listen((raw) {
      if (raw is! Map) return;
      final data = Map<String, dynamic>.from(raw);
      final eventName = data['event'] as String? ?? '';
      final event = _parseEvent(eventName);
      _eventController.add(FunintRtcEventData(event, data));
    }, onError: (e) => _emitError('EventChannel error: $e'));

    _eventController.add(
      FunintRtcEventData(FunintRtcEvent.initialized, {'event': 'initialized'}),
    );
  }

  FunintRtcEvent _parseEvent(String name) {
    switch (name) {
      case 'initialized':
        return FunintRtcEvent.initialized;
      case 'connected':
        return FunintRtcEvent.connected;
      case 'joinedChannel':
        return FunintRtcEvent.joinedChannel;
      case 'localStream':
        return FunintRtcEvent.localStream;
      case 'remoteUserJoined':
        return FunintRtcEvent.remoteUserJoined;
      case 'remoteUserLeft':
        return FunintRtcEvent.remoteUserLeft;
      case 'connectionState':
        return FunintRtcEvent.connectionState;
      case 'messageReceived':
        return FunintRtcEvent.messageReceived;
      case 'messageSent':
        return FunintRtcEvent.messageSent;
      case 'screenShareStarted':
        return FunintRtcEvent.screenShareStarted;
      case 'screenShareStopped':
        return FunintRtcEvent.screenShareStopped;
      case 'userMuteAudio':
        return FunintRtcEvent.userMuteAudio;
      case 'leftChannel':
        return FunintRtcEvent.leftChannel;
      case 'error':
        return FunintRtcEvent.error;
      default:
        return FunintRtcEvent.unknown;
    }
  }

  // ─────────────────────────────────────────────
  // Token fetch — separate permission sets per mode
  // ─────────────────────────────────────────────
  Future<String> _fetchToken(
    String roomId,
    String userId,
    String rtcMode, {
    bool withScreenShare = false,
  }) async {
    final permissions = switch (rtcMode) {
      'video' =>
        withScreenShare
            ? _Permissions.videoWithScreenShare
            : _Permissions.video,
      _ => _Permissions.voice, // 'voice' or 'audio'
    };

    final response = await http
        .post(
          Uri.parse('$_apiBase/client/rtc/token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'app_name': _appName,
            'external_user_id': userId,
            'room_id': roomId,
            'role': 'publisher',
            'rtc_mode': rtcMode,
            'permissions': permissions,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Token fetch failed [${response.statusCode}]: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'] ?? data['accessToken'] ?? data['token'];
    if (token == null) throw Exception('No token field in response: $data');

    _tokenIssuedAt = DateTime.now();
    _scheduleTokenRefresh(roomId, userId, rtcMode);
    return token as String;
  }

  // Refresh 5 minutes before the 1h expiry
  void _scheduleTokenRefresh(String roomId, String userId, String rtcMode) {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = Timer(const Duration(minutes: 55), () async {
      if (!isInRoom) return;
      try {
        final newToken = await _fetchToken(roomId, userId, rtcMode);
        // Re-join with fresh token (SDK requires new instance per token)
        await _methodChannel.invokeMethod('refreshToken', {
          'token': newToken,
          'roomId': roomId,
          'rtcMode': rtcMode,
        });
      } catch (e) {
        _emitError('Token refresh failed: $e');
      }
    });
  }

  // ─────────────────────────────────────────────
  // Join — voice room (Hapi's primary use case)
  // ─────────────────────────────────────────────
  Future<void> joinVoiceRoom(String roomId, String userId) async {
    await _join(roomId, userId, 'voice');
  }

  // ─────────────────────────────────────────────
  // Join — video call
  // ─────────────────────────────────────────────
  Future<void> joinVideoRoom(
    String roomId,
    String userId, {
    bool withScreenShare = false,
  }) async {
    await _join(roomId, userId, 'video', withScreenShare: withScreenShare);
  }

  Future<void> _join(
    String roomId,
    String userId,
    String rtcMode, {
    bool withScreenShare = false,
  }) async {
    if (!_initialized) await initialize();

    _currentRoomId = roomId;
    _currentUserId = userId;
    _currentMode = rtcMode;

    try {
      final token = await _fetchToken(
        roomId,
        userId,
        rtcMode,
        withScreenShare: withScreenShare,
      );
      await _methodChannel.invokeMethod('join', {
        'token': token,
        'roomId': roomId,
        'rtcMode': rtcMode,
      });
    } catch (e) {
      _currentRoomId = null;
      _currentUserId = null;
      _currentMode = null;
      _emitError('Join failed: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // Leave
  // ─────────────────────────────────────────────
  Future<void> leaveRoom() async {
    _tokenRefreshTimer?.cancel();
    _currentRoomId = null;
    _currentUserId = null;
    _currentMode = null;
    _isMuted = false;
    _isVideoEnabled = true;
    await _methodChannel.invokeMethod('leave');
  }

  // ─────────────────────────────────────────────
  // Audio controls
  // ─────────────────────────────────────────────
  Future<void> muteLocalAudio(bool mute) async {
    await _methodChannel.invokeMethod('muteAudio', {'mute': mute});
    _isMuted = mute;
    _eventController.add(
      FunintRtcEventData(FunintRtcEvent.userMuteAudio, {
        'event': 'userMuteAudio',
        'uid': 'local',
        'muted': mute,
      }),
    );
  }

  Future<void> toggleMute() => muteLocalAudio(!_isMuted);

  Future<void> setSpeakerphone(bool on) async {
    await _methodChannel.invokeMethod('setSpeakerphone', {'on': on});
  }

  Future<void> setNoiseCancellation(bool enabled) async {
    await _methodChannel.invokeMethod('setNoiseCancellation', {
      'enabled': enabled,
    });
  }

  // ─────────────────────────────────────────────
  // Video controls
  // ─────────────────────────────────────────────
  Future<void> setVideoEnabled(bool enabled) async {
    await _methodChannel.invokeMethod('setVideoEnabled', {'enabled': enabled});
    _isVideoEnabled = enabled;
  }

  Future<void> toggleVideo() => setVideoEnabled(!_isVideoEnabled);

  Future<void> attachRenderers() async {
    await _methodChannel.invokeMethod('attachRenderers');
  }

  // ─────────────────────────────────────────────
  // Screen share
  // ─────────────────────────────────────────────
  Future<void> startScreenShare() async {
    await _methodChannel.invokeMethod('startScreenShare');
  }

  Future<void> stopScreenShare() async {
    await _methodChannel.invokeMethod('stopScreenShare');
  }

  // ─────────────────────────────────────────────
  // Messaging via RTC (not Firestore)
  // ─────────────────────────────────────────────
  Future<void> sendMessage(String text) async {
    if (!isInRoom) return;
    await _methodChannel.invokeMethod('sendMessage', {'message': text});
    // Emit locally so sender sees their own message immediately
    _eventController.add(
      FunintRtcEventData(FunintRtcEvent.messageSent, {
        'event': 'messageSent',
        'message': text,
        'sender': _currentUserId ?? 'me',
      }),
    );
  }

  Future<void> sendEmoji(String emoji) => sendMessage(emoji);

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────
  void _emitError(String message) {
    _eventController.add(
      FunintRtcEventData(FunintRtcEvent.error, {
        'event': 'error',
        'message': message,
      }),
    );
  }

  void dispose() {
    _tokenRefreshTimer?.cancel();
    leaveRoom();
    _eventController.close();
    _initialized = false;
  }
}
