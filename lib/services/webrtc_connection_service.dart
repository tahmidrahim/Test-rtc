import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hapi/services/rtc_media_service.dart';
import 'package:hapi/services/rtc_signaling_service.dart';

/// Handles WebRTC connection setup and signaling coordination
class WebRtcConnectionService {
  final RtcMediaService? mediaService;
  final RtcSignalingService? signalingService;

  WebRtcConnectionService({
    this.mediaService,
    this.signalingService,
  });

  /// Setup local audio and create peer connection
  Future<RTCPeerConnection> setupLocalConnection({
    required String roomId,
    required String deviceId,
  }) async {
    if (mediaService == null || signalingService == null) {
      throw Exception('Media or Signaling service not initialized');
    }

    // Get local audio stream
    await mediaService!.getLocalAudio();

    // Create peer connection
    final pc = await mediaService!.createRtcPeerConnection(
      roomId: roomId,
      socketId: signalingService!.socketId ?? '',
    );

    // Add local audio to peer connection
    await mediaService!.addLocalAudio(pc);

    return pc;
  }

  /// Send local offer to remote peer
  Future<void> sendOffer(RTCPeerConnection pc) async {
    if (mediaService == null || signalingService == null) {
      throw Exception('Media or Signaling service not initialized');
    }
    final offer = await mediaService!.createOffer(pc);
    signalingService!.sendOffer('broadcast', offer.toMap());
    print('✅ Offer sent');
  }

  /// Handle incoming offer
  Future<void> handleRemoteOffer(
    RTCPeerConnection pc,
    Map<String, dynamic> offerData,
  ) async {
    if (mediaService == null) {
      throw Exception('Media service not initialized');
    }
    try {
      final offer = RTCSessionDescription(
        offerData['sdp'],
        offerData['type'],
      );
      await mediaService!.handleOffer(pc, offer);
      print('✅ Offer handled');
    } catch (e) {
      print('❌ Error handling offer: $e');
      rethrow;
    }
  }

  /// Create and send answer
  Future<void> createAndSendAnswer(
    RTCPeerConnection pc,
    String remoteSocketId,
  ) async {
    if (mediaService == null || signalingService == null) {
      throw Exception('Media or Signaling service not initialized');
    }
    try {
      final answer = await mediaService!.createAnswer(pc);
      signalingService!.sendAnswer(remoteSocketId, answer.toMap());
      print('✅ Answer sent');
    } catch (e) {
      print('❌ Error creating answer: $e');
      rethrow;
    }
  }

  /// Handle incoming answer
  Future<void> handleRemoteAnswer(
    RTCPeerConnection pc,
    Map<String, dynamic> answerData,
  ) async {
    if (mediaService == null) {
      throw Exception('Media service not initialized');
    }
    try {
      final answer = RTCSessionDescription(
        answerData['sdp'],
        answerData['type'],
      );
      await mediaService!.handleAnswer(pc, answer);
      print('✅ Answer handled');
    } catch (e) {
      print('❌ Error handling answer: $e');
      rethrow;
    }
  }

  /// Handle incoming ICE candidate
  Future<void> handleRemoteIceCandidate(
    RTCPeerConnection pc,
    Map<String, dynamic> candidateData,
  ) async {
    if (mediaService == null) {
      return;
    }
    try {
      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'] as int?,
      );
      await mediaService!.handleIceCandidate(pc, candidate);
      print('✅ ICE candidate handled');
    } catch (e) {
      print('❌ Error handling ICE candidate: $e');
    }
  }

  /// Cleanup connection
  Future<void> cleanup() async {
    if (mediaService != null) {
      await mediaService!.dispose();
    }
    if (signalingService != null) {
      signalingService!.disconnect();
    }
  }
}
