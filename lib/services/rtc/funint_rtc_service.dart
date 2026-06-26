import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'rtc_interface.dart';

class FunintRtcService implements IRTCService {
  static const _methodChannel = MethodChannel('funint_rtc/methods');
  static const _eventChannel = EventChannel('funint_rtc/events');

  static const String _apiBase = 'https://funint.online';
  static const String _apiKey =
      'rtc_4e9a6e6fd43145b0b73b91194b4aafe4a0fbd908ef874457bf7767962978a6dc';
  static const String _appName = 'hapi-app-01';

  bool _isInitialized = false;
  bool _isMuted = false;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        _eventController.add(Map<String, dynamic>.from(event));
      }
    });
    _eventController.add({'event': 'initialized'});
  }

  Future<String> _fetchToken(String roomId, String userId) async {
    final response = await http.post(
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
        'rtc_mode': 'voice',
        'permissions': ['join', 'publish_audio', 'chat', 'signal'],
      }),
    );

    debugPrint('Funint token: ${response.statusCode} ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Token failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    final token = data['access_token'] ?? data['accessToken'] ?? data['token'];
    if (token == null)
      throw Exception('No token in response: ${response.body}');
    return token as String;
  }

  @override
  Future<void> joinChannel(String channelName, String token, String uid) async {
    if (!_isInitialized) await initialize();
    try {
      final accessToken = await _fetchToken(channelName, uid);
      await _methodChannel.invokeMethod('join', {
        'token': accessToken,
        'roomId': channelName,
      });
    } catch (e) {
      debugPrint('❌ Funint join failed: $e');
      _eventController.add({'event': 'error', 'message': 'Join failed: $e'});
      rethrow;
    }
  }

  @override
  Future<void> leaveChannel() async {
    await _methodChannel.invokeMethod('leave');
    _eventController.add({'event': 'leftChannel'});
  }

  @override
  Future<void> enableLocalAudio(bool enable) async {
    await _methodChannel.invokeMethod('muteAudio', {'mute': !enable});
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
