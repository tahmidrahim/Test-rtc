import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hapi/services/auth_service.dart';
import 'package:hapi/services/game_api_service.dart';
import 'package:hapi/services/room_firestore_service.dart';

// Auth Service
final authServiceProvider = Provider((ref) {
  return AuthService();
});

// Room Firestore Service
final roomFirestoreServiceProvider = Provider((ref) {
  return RoomFirestoreService();
});

// Game API Service
final gameApiServiceProvider = Provider((ref) {
  return GameApiService();
});
