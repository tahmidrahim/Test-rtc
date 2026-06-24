import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'rtc_interface.dart';

class RTCService implements IRTCService {
  static const String _serverUrl = 'wss://chadnichok.com';
  static const String _apiKey = 'ap_201fdec1ecebb8804d32b0a4'; // Api key

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

  // Future<String> _fetchToken(String roomName, String identity) async {
  //   final response = await http.post(
  //     Uri.parse('https://chadnichok.com/auth/token'),
  //     headers: {
  //       'Authorization': 'Bearer $_apiKey',
  //       'Content-Type': 'application/json',
  //     },
  //     body: jsonEncode({'room': roomName, 'identity': identity}),
  //   );

  //   if (response.statusCode == 200) {
  //     final data = jsonDecode(response.body);
  //     return data['token'] as String;
  //   } else {
  //     throw Exception(
  //       'Token fetch failed: ${response.statusCode} ${response.body}',
  //     );
  //   }
  // }
  Future<String> _fetchToken(String roomName, String identity) async {
    // Step 1: Login to get session token
    final loginResponse = await http.post(
      Uri.parse('https://chadnichok.com/auth/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': 'tahmidrahim2003@gmail.com', // ←  portal email
        'password': '01234567', // ← portal password
      }),
    );

    if (loginResponse.statusCode != 200) {
      throw Exception('Login failed: ${loginResponse.body}');
    }

    final sessionToken = jsonDecode(loginResponse.body)['token'];

    // Step 2: Use session token to get room token
    final tokenResponse = await http.post(
      Uri.parse('https://chadnichok.com/auth/token'),

      headers: {
        'Authorization': 'Bearer $sessionToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'room': roomName, 'identity': identity}),
    );

    if (tokenResponse.statusCode == 200) {
      final data = jsonDecode(tokenResponse.body);
      return data['token'] as String;
    } else {
      throw Exception(
        'Token fetch failed: ${tokenResponse.statusCode} ${tokenResponse.body}',
      );
    }
  }

  @override
  Future<void> joinChannel(String channelName, String token, String uid) async {
    if (!_isInitialized) await initialize();

    try {
      final jwt = await _fetchToken(channelName, uid);

      _room = Room();
      _listener = _room!.createListener();
      _setupListeners();

      await _room!.connect(_serverUrl, jwt);
      await _room!.localParticipant?.setMicrophoneEnabled(true);

      // Notify anyone already in room when we join
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
      _eventController.add({'event': 'error', 'message': 'Join failed: $e'});
      rethrow;
    }
  }

  void _setupListeners() {
    _listener!
      ..on<ParticipantConnectedEvent>((event) {
        _eventController.add({
          'event': 'remoteUserJoined',
          'uid': event.participant.identity,
          'displayName': event.participant.name.isNotEmpty
              ? event.participant.name
              : event.participant.identity,
        });
      })
      ..on<ParticipantDisconnectedEvent>((event) {
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
