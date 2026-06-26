import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hapi/services/rtc/funint_rtc_extended_service.dart';

// ─────────────────────────────────────────────
// This wraps FunintRtcExtended for Hapi's voice
// room pattern:
//   - Audio via RTC
//   - Participant presence via Firestore (existing)
//   - In-room chat via RTC (new — not Firestore)
// ─────────────────────────────────────────────

class HapiVoiceRoomService {
  final FunintRtcExtended _rtc;
  final FirebaseFirestore _firestore;

  // Chat messages received via RTC (not Firestore)
  final _chatController =
      StreamController<RtcChatMessage>.broadcast();

  Stream<RtcChatMessage> get chatMessages => _chatController.stream;

  StreamSubscription? _eventSub;

  HapiVoiceRoomService({
    FunintRtcExtended? rtcService,
    FirebaseFirestore? firestore,
  })  : _rtc = rtcService ?? FunintRtcExtended(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  bool get isMuted => _rtc.isMuted;
  bool get isInRoom => _rtc.isInRoom;

  // ─────────────────────────────────────────────
  // Join
  // ─────────────────────────────────────────────

  Future<void> joinRoom(String roomId, String userId,
      {String? displayName}) async {
    await _rtc.initialize();

    // Wire up event listeners before joining
    _eventSub?.cancel();
    _eventSub = _rtc.events.listen(_handleRtcEvent);

    // Join RTC audio channel
    await _rtc.joinVoiceRoom(roomId, userId);

    // Update Firestore presence (existing Hapi pattern)
    await _updateFirestorePresence(
        roomId, userId, displayName, joined: true);
  }

  // ─────────────────────────────────────────────
  // Leave
  // ─────────────────────────────────────────────

  Future<void> leaveRoom(String roomId, String userId) async {
    await _rtc.leaveRoom();
    await _updateFirestorePresence(roomId, userId, null, joined: false);
    _eventSub?.cancel();
    _eventSub = null;
  }

  // ─────────────────────────────────────────────
  // Audio
  // ─────────────────────────────────────────────

  Future<void> toggleMute() => _rtc.toggleMute();
  Future<void> muteLocalAudio(bool mute) => _rtc.muteLocalAudio(mute);
  Future<void> setSpeakerphone(bool on) => _rtc.setSpeakerphone(on);
  Future<void> setNoiseCancellation(bool enabled) =>
      _rtc.setNoiseCancellation(enabled);

  // ─────────────────────────────────────────────
  // Messaging via RTC
  // ─────────────────────────────────────────────

  Future<void> sendMessage(String text, {required String senderId}) async {
    await _rtc.sendMessage(text);
    // Local echo is handled by FunintRtcExtended emitting messageSent event
  }

  Future<void> sendEmoji(String emoji) => _rtc.sendEmoji(emoji);

  // ─────────────────────────────────────────────
  // RTC event handler
  // ─────────────────────────────────────────────

  void _handleRtcEvent(FunintRtcEventData event) {
    switch (event.event) {
      case FunintRtcEvent.messageReceived:
        _chatController.add(RtcChatMessage(
          sender: event.sender ?? 'participant',
          text: event.message ?? '',
          isLocal: false,
        ));

      case FunintRtcEvent.messageSent:
        _chatController.add(RtcChatMessage(
          sender: event.sender ?? 'me',
          text: event.message ?? '',
          isLocal: true,
        ));

      case FunintRtcEvent.remoteUserJoined:
      // Hapi uses Firestore for participant grid — no action needed here
      // But you could trigger a refresh if needed
        break;

      case FunintRtcEvent.remoteUserLeft:
      // Same — Firestore handles presence
        break;

      case FunintRtcEvent.error:
      // Bubble up if needed via a separate error stream
        break;

      default:
        break;
    }
  }

  // ─────────────────────────────────────────────
  // Firestore presence (existing Hapi pattern)
  // ─────────────────────────────────────────────

  Future<void> _updateFirestorePresence(
    String roomId,
    String userId,
    String? displayName, {
    required bool joined,
  }) async {
    final roomRef =
        _firestore.collection('rooms').doc(roomId);
    final participantRef =
        roomRef.collection('participants').doc(userId);

    if (joined) {
      await participantRef.set({
        'userId': userId,
        'displayName': ?displayName,
        'joinedAt': FieldValue.serverTimestamp(),
        'isMuted': false,
        'isActive': true,
      }, SetOptions(merge: true));
    } else {
      await participantRef.update({
        'isActive': false,
        'leftAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ─────────────────────────────────────────────
  // Dispose
  // ─────────────────────────────────────────────

  Future<void> dispose() async {
    _eventSub?.cancel();
    _rtc.dispose();
    await _chatController.close();
  }
}

// ─────────────────────────────────────────────
// Chat message model
// ─────────────────────────────────────────────

class RtcChatMessage {
  final String sender;
  final String text;
  final bool isLocal;
  final DateTime timestamp;

  RtcChatMessage({
    required this.sender,
    required this.text,
    required this.isLocal,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isEmoji =>
      text.runes.length == 1 ||
      RegExp(r'^[\u{1F000}-\u{1FFFF}]+$', unicode: true).hasMatch(text);
}