import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

class RtcMediaService {
  rtc.MediaStream? _localStream;
  rtc.RTCPeerConnection? _peerConnection;

  final List<rtc.RTCPeerConnection> _peerConnections = [];
  final List<rtc.RTCVideoRenderer> _remoteRenderers = [];

  // Callbacks
  Function(rtc.MediaStream)? onRemoteStream;
  Function(String)? onConnectionState;

  // ICE callback for signaling
  Function(Map<String, dynamic>)? onIceCandidate;

  /// Get local microphone stream
  Future<rtc.MediaStream> getLocalAudio() async {
    if (_localStream != null) return _localStream!;

    _localStream = await rtc.navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    print('🎤 Local audio stream created');
    return _localStream!;
  }

  /// Create peer connection
  Future<rtc.RTCPeerConnection> createRtcPeerConnection({
    required String roomId,
    required String socketId,
  }) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    final pc = await rtc.createPeerConnection(config);

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        final data = {
          'roomId': roomId,
          'targetSocketId': socketId,
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        };

        print('🧊 ICE Candidate Generated');
        onIceCandidate?.call(data);
      }
    };

    pc.onConnectionState = (state) {
      print('🔌 Connection State: $state');
      onConnectionState?.call(state.toString());
    };

    pc.onTrack = (event) {
      print('📡 Track Received: ${event.track.kind}');

      if (event.streams.isNotEmpty) {
        final stream = event.streams.first;

        print('🎧 Remote stream received');
        onRemoteStream?.call(stream);
      }
    };

    _peerConnection = pc;
    _peerConnections.add(pc);

    return pc;
  }

  /// Add local audio track
  Future<void> addLocalAudio(rtc.RTCPeerConnection pc) async {
    final stream = await getLocalAudio();

    for (final track in stream.getAudioTracks()) {
      await pc.addTrack(track, stream);
    }

    print('🎤 Local audio added');
  }

  /// Create offer
  Future<rtc.RTCSessionDescription> createOffer(
    rtc.RTCPeerConnection pc,
  ) async {
    final offer = await pc.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });

    await pc.setLocalDescription(offer);

    print('📤 Offer created');

    return offer;
  }

  /// Create answer
  Future<rtc.RTCSessionDescription> createAnswer(
    rtc.RTCPeerConnection pc,
  ) async {
    final answer = await pc.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });

    await pc.setLocalDescription(answer);

    print('📤 Answer created');

    return answer;
  }

  /// Handle incoming offer
  Future<void> handleOffer(
    rtc.RTCPeerConnection pc,
    rtc.RTCSessionDescription offer,
  ) async {
    await pc.setRemoteDescription(offer);

    print('📥 Remote offer set');
  }

  /// Handle incoming answer
  Future<void> handleAnswer(
    rtc.RTCPeerConnection pc,
    rtc.RTCSessionDescription answer,
  ) async {
    await pc.setRemoteDescription(answer);

    print('📥 Remote answer set');
  }

  /// Add remote ICE candidate
  Future<void> handleIceCandidate(
    rtc.RTCPeerConnection pc,
    rtc.RTCIceCandidate candidate,
  ) async {
    await pc.addCandidate(candidate);

    print('🧊 Remote ICE candidate added');
  }

  /// Mute / Unmute microphone
  void muteAudio(bool muted) {
    if (_localStream == null) return;

    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !muted;
    }

    print(muted ? '🔇 Microphone muted' : '🎤 Microphone unmuted');
  }

  /// Create renderer
  Future<rtc.RTCVideoRenderer> createRemoteRenderer() async {
    final renderer = rtc.RTCVideoRenderer();

    await renderer.initialize();

    _remoteRenderers.add(renderer);

    return renderer;
  }

  /// Attach stream to renderer
  void attachRemoteStream(
    rtc.MediaStream stream,
    rtc.RTCVideoRenderer renderer,
  ) {
    renderer.srcObject = stream;

    print('🎧 Stream attached');
  }

  /// Remove renderer
  Future<void> removeRemoteRenderer(rtc.RTCVideoRenderer renderer) async {
    renderer.srcObject = null;

    await renderer.dispose();

    _remoteRenderers.remove(renderer);
  }

  /// Dispose everything
  Future<void> dispose() async {
    for (final pc in _peerConnections) {
      await pc.close();
      await pc.dispose();
    }

    _peerConnections.clear();

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        track.stop();
      }

      await _localStream!.dispose();
      _localStream = null;
    }

    for (final renderer in _remoteRenderers) {
      renderer.srcObject = null;
      await renderer.dispose();
    }

    _remoteRenderers.clear();

    print('🔇 RTC Media Service disposed');
  }

  rtc.RTCPeerConnection? get peerConnection => _peerConnection;

  rtc.MediaStream? get localStream => _localStream;

  List<rtc.RTCVideoRenderer> get remoteRenderers => _remoteRenderers;
}
