import 'dart:async';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:livekit_client/livekit_client.dart';
import 'rtc_interface.dart';

class RTCService implements IRTCService {
  static const String _serverUrl = 'wss://hapi-4v10t8s8.livekit.cloud';
  static const String _apiKey = 'APIfRDphoYKHKya';
  static const String _apiSecret =
      'UX2izhBne9oLPDZt2ZWT5Dd28ahFIAx5mqudo5jdZmb';

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

  // ✅ Generate LiveKit JWT token locally — no server needed
  String _generateToken(String roomName, String identity) {
    final now = DateTime.now();
    final jwt = JWT({
      'iss': _apiKey,
      'sub': identity,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': now.add(const Duration(hours: 6)).millisecondsSinceEpoch ~/ 1000,
      'nbf': now.millisecondsSinceEpoch ~/ 1000,
      'video': {
        'roomJoin': true,
        'room': roomName,
        'canPublish': true,
        'canSubscribe': true,
        'canPublishData': true,
      },
      'name': identity,
    });
    return jwt.sign(SecretKey(_apiSecret));
  }

  @override
  Future<void> joinChannel(String channelName, String token, String uid) async {
    if (!_isInitialized) await initialize();

    try {
      // ✅ Generate token locally
      final jwt = _generateToken(channelName, uid);
      print('✅ Token generated for room: $channelName, identity: $uid');

      _room = Room();
      _listener = _room!.createListener();
      _setupListeners();

      // ✅ Connect to LiveKit Cloud
      await _room!.connect(_serverUrl, jwt);
      print('✅ Connected to LiveKit');

      // ✅ Enable microphone
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      print('✅ Microphone enabled');

      // ✅ Handle participants already in room
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
      print('❌ Join failed: $e');
      _eventController.add({'event': 'error', 'message': 'Join failed: $e'});
      rethrow;
    }
  }

  void _setupListeners() {
    _listener!
      ..on<ParticipantConnectedEvent>((event) {
        print('✅ Remote user joined: ${event.participant.identity}');
        _eventController.add({
          'event': 'remoteUserJoined',
          'uid': event.participant.identity,
          'displayName': event.participant.name.isNotEmpty
              ? event.participant.name
              : event.participant.identity,
        });
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        print('👋 Remote user left: ${event.participant.identity}');
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
        print('🔌 Room disconnected');
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
