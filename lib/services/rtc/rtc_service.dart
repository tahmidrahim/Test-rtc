import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hapi/config/rtc_config.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'rtc_interface.dart';

class RTCService implements IRTCService {
  // Chadnichok credentials
  static const String _serverUrl = RtcConfig.serverUrl;
  static const String _apiKey = RtcConfig.apiKey;
  static const String _apiSecret = RtcConfig.apiSecret;
  static const String _sdkTokenUrl = 'https://chadnichok.com/auth/sdkTokens';
  static const String _livekitTokenUrl =
      'https://chadnichok.com/auth/livekitTokens';

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isInitialized = false;
  bool _isMuted = false;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    _eventController.add({'event': 'initialized'});
  }

  // ── Step 1: Get SDK access token using API key + secret ───
  Future<String> _getAccessToken() async {
    final response = await http.post(
      Uri.parse(_sdkTokenUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-SDK-Client': 'flutter',
        'X-SDK-Version': '1.0.0',
      },
      body: jsonEncode({'app_id': _apiKey, 'app_secret': _apiSecret}),
    );

    debugPrint('SDK token response: ${response.statusCode} ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(
        'SDK auth failed: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final token = data['access_token'] ?? data['token'];
    if (token == null) {
      throw Exception('access_token not found in response: ${response.body}');
    }
    return token as String;
  }

  // ── Step 2: Get LiveKit room token using access token ─────
  Future<String> _fetchToken(String roomName, String identity) async {
    final accessToken = await _getAccessToken();
    debugPrint('✅ SDK access token received');

    final response = await http.post(
      Uri.parse(_livekitTokenUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'room': roomName,
        'identity': identity,
        'name': identity,
      }),
    );

    debugPrint(
      'LiveKit token response: ${response.statusCode} ${response.body}',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'LiveKit token failed: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final token =
        data['token'] ??
        data['livekit_token'] ??
        data['livekitToken'] ??
        data['jwt'];

    if (token == null) {
      throw Exception('Token field not found in response: ${response.body}');
    }
    return token as String;
  }

  @override
  Future<void> joinChannel(String channelName, String token, String uid) async {
    if (!_isInitialized) await initialize();

    try {
      final jwt = await _fetchToken(channelName, uid);
      debugPrint('✅ LiveKit token received');

      _room = Room();
      _listener = _room!.createListener();
      _setupListeners();

      await _room!.connect(_serverUrl, jwt);
      debugPrint(' Connected to $_serverUrl');

      await _room!.localParticipant?.setMicrophoneEnabled(true);
      debugPrint(' Microphone enabled');

      // Handle participants already in room
      for (final p in _room!.remoteParticipants.values) {
        _eventController.add({
          'event': 'remoteUserJoined',
          'uid': p.identity,
          'displayName': p.name.isNotEmpty ? p.name : p.identity,
        });
      }

      _eventController.add({
        'event': 'joinedChannel',
        'channel': channelName,
        'uid': uid,
      });
    } catch (e) {
      debugPrint('❌ Join failed: $e');
      _eventController.add({'event': 'error', 'message': 'Join failed: $e'});
      rethrow;
    }
  }

  void _setupListeners() {
    _listener!
      ..on<ParticipantConnectedEvent>((event) {
        debugPrint('✅ Remote user joined: ${event.participant.identity}');
        _eventController.add({
          'event': 'remoteUserJoined',
          'uid': event.participant.identity,
          'displayName': event.participant.name.isNotEmpty
              ? event.participant.name
              : event.participant.identity,
        });
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        debugPrint('👋 Remote user left: ${event.participant.identity}');
        _eventController.add({
          'event': 'remoteUserLeft',
          'uid': event.participant.identity,
        });
      })
      ..on<TrackMutedEvent>((event) {
        _eventController.add({
          'event': 'userMuteAudio',
          'uid': event.participant.identity,
          'muted': true,
        });
      })
      ..on<TrackUnmutedEvent>((event) {
        _eventController.add({
          'event': 'userMuteAudio',
          'uid': event.participant.identity,
          'muted': false,
        });
      })
      ..on<RoomDisconnectedEvent>((_) {
        debugPrint('🔌 Room disconnected');
        _eventController.add({'event': 'leftChannel'});
      });
  }

  @override
  Future<void> leaveChannel() async {
    await _listener?.dispose();
    _listener = null;
    await _room?.localParticipant?.setMicrophoneEnabled(false);
    await _room?.disconnect();
    _room?.dispose();
    _room = null;
    _eventController.add({'event': 'leftChannel'});
  }

  @override
  Future<void> enableLocalAudio(bool enable) async {
    await _room?.localParticipant?.setMicrophoneEnabled(enable);
    _isMuted = !enable;
    _eventController.add({
      'event': 'userMuteAudio',
      'uid': 'local',
      'muted': !enable,
    });
  }

  @override
  bool isMuted() => _isMuted;

  @override
  void dispose() {
    leaveChannel();
    _eventController.close();
    _isInitialized = false;
  }
}
