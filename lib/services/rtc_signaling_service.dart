import 'package:socket_io_client/socket_io_client.dart' as IO;

class RtcSignalingService {
  static const String _serverUrl = 'https://funint.online';
  static const String _path = '/api/rtc';
  static const String _platform = 'mobile';

  IO.Socket? _socket;
  bool _isConnected = false;

  void connect({
    required String clientAppId,
    required String appUserToken,
    required String deviceId,
  }) {
    if (_socket != null && _socket!.connected) {
      print('✅ Already connected to signaling server');
      return;
    }

    _socket = IO.io(_serverUrl, <String, dynamic>{
      'path': _path,
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {
        'clientAppId': clientAppId,
        'appUserToken': appUserToken,
        'deviceId': deviceId,
        'platform': _platform,
      },
    });

    _socket!.onConnect((_) {
      _isConnected = true;
      print('✅ Connected to signaling server');
    });

    _socket!.onConnectError((error) {
      print('❌ Signaling connection error: $error');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('❌ Disconnected from signaling server');
    });

    _socket!.on('room:joined', (data) {
      print('✅ Room joined: $data');
    });

    _socket!.on('user:joined', (data) {
      print('👤 User joined room: $data');
    });

    _socket!.on('user:left', (data) {
      print('👤 User left room: $data');
    });

    _socket!.on('error', (error) {
      print('❌ Socket error: $error');
    });

    _socket!.connect();
  }

  void sendCommand(String command, Map<String, dynamic> data) {
    if (_socket == null || !_isConnected) {
      print('❌ Not connected to signaling server');
      return;
    }
    _socket!.emit('rtc.command', {'cmd': command, 'data': data});
    print('📤 Command sent: $command');
  }

  // Send WebRTC signals
  void sendOffer(String targetSocketId, Map<String, dynamic> offer) {
    sendCommand('webrtc.offer', {
      'targetSocketId': targetSocketId,
      'offer': offer,
    });
    print('📤 Offer sent to: $targetSocketId');
  }

  void sendAnswer(String targetSocketId, Map<String, dynamic> answer) {
    sendCommand('webrtc.answer', {
      'targetSocketId': targetSocketId,
      'answer': answer,
    });
    print('📤 Answer sent to: $targetSocketId');
  }

  void sendIceCandidate(String targetSocketId, Map<String, dynamic> candidate) {
    sendCommand('webrtc.ice', {
      'targetSocketId': targetSocketId,
      'candidate': candidate,
    });
    print('🧊 ICE candidate sent to: $targetSocketId');
  }

  void joinRoom(String roomId) {
    if (_socket == null || !_isConnected) {
      print('❌ Not connected to signaling server');
      return;
    }
    _socket!.emit('room:join', {'roomId': roomId});
    print('📤 Join room: $roomId');
  }

  void leaveRoom() {
    if (_socket == null) return;
    _socket!.emit('room:leave');
    print('📤 Leave room');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    print('👋 Disconnected from signaling server');
  }

  bool get isConnected => _isConnected;

  // ✅ Socket getter (needed for listening to events)
  IO.Socket? get socket => _socket;

  String? get socketId => _socket?.id;
}
