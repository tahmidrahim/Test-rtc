import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rtc/rtc_factory.dart';
import '../services/rtc/rtc_interface.dart';

final rtcProvider = ChangeNotifierProvider<RTCProvider>((ref) {
  return RTCProvider();
});

class RTCProvider extends ChangeNotifier {
  late IRTCService _rtcService;

  List<Map<String, dynamic>> _remoteUsers = [];
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isInitialized = false;
  String? _errorMessage;

  RTCProvider() {
    _rtcService = RTCFactory.create();
    _listenToEvents();
  }

  void _listenToEvents() {
    _rtcService.events.listen((event) {
      switch (event['event']) {
        case 'initialized':
          _isInitialized = true;
          _errorMessage = null;
          notifyListeners();
          break;

        case 'joinedChannel':
          // Do nothing – connection status is based on remote users
          break;

        case 'remoteUserJoined':
          final uid = event['uid'].toString();
          final displayName = event['displayName'] ?? uid;
          if (!_remoteUsers.any((u) => u['uid'] == uid)) {
            _remoteUsers.add({
              'uid': uid,
              'displayName': displayName,
              'isMuted': false,
            });
            // ✅ A real remote user has joined – we are now connected
            _isConnected = true;
            _errorMessage = null;
            notifyListeners();
          }
          break;

        case 'remoteUserLeft':
          final uid = event['uid'].toString();
          _remoteUsers.removeWhere((u) => u['uid'] == uid);
          // ✅ If no remote users left, we are not connected
          if (_remoteUsers.isEmpty) {
            _isConnected = false;
          }
          notifyListeners();
          break;

        case 'userMuteAudio':
          final uid = event['uid'].toString();
          final muted = event['muted'] ?? false;
          if (uid == 'local') {
            _isMuted = muted;
          } else {
            final index = _remoteUsers.indexWhere((u) => u['uid'] == uid);
            if (index != -1) {
              _remoteUsers[index]['isMuted'] = muted;
              notifyListeners();
            }
          }
          break;

        // ❌ Ignore connectionState – it gives false positives
        case 'connectionState':
          // Just log it for debugging, but don't change _isConnected
          print('WebRTC connection state: ${event['state']}');
          break;

        case 'leftChannel':
          _isConnected = false;
          _remoteUsers.clear();
          _isMuted = false;
          _errorMessage = null;
          notifyListeners();
          break;

        case 'error':
          _errorMessage = event['message'] ?? 'Unknown error';
          notifyListeners();
          break;
      }
    });
  }

  Future<void> initializeRTC() async {
    if (_isInitialized) return;
    try {
      await _rtcService.initialize();
    } catch (e) {
      _errorMessage = 'Failed to initialize: $e';
      _isInitialized = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> joinRoom(String roomId) async {
    if (!_isInitialized) await initializeRTC();
    final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _rtcService.joinChannel(roomId, '', uid);
    } catch (e) {
      _errorMessage = 'Failed to join room: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> leaveRoom() async {
    try {
      await _rtcService.leaveChannel();
    } catch (e) {
      print('Error leaving room: $e');
    }
  }

  Future<void> toggleMute() async {
    try {
      _isMuted = !_isMuted;
      await _rtcService.enableLocalAudio(!_isMuted);
      notifyListeners();
    } catch (e) {
      _isMuted = !_isMuted;
      _errorMessage = 'Failed to toggle mute: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  List<Map<String, dynamic>> get remoteUsers => _remoteUsers;
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  @override
  void dispose() {
    _rtcService.dispose();
    super.dispose();
  }
}
