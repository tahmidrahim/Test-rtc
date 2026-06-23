import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hapi/services/room_firestore_service.dart';
import 'package:hapi/services/webrtc_connection_service.dart';

/// Room Firestore service provider
final roomFirestoreServiceProvider = Provider((ref) {
  return RoomFirestoreService();
});

/// WebRTC connection service provider
final webRtcConnectionServiceProvider = Provider((ref) {
  return WebRtcConnectionService();
});
