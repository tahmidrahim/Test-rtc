import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hapi/services/rtc_api_service.dart' as api;
import 'package:hapi/services/rtc_media_service.dart';

import 'package:hapi/services/rtc_signaling_service.dart';

final rtcMediaProvider = Provider((ref) => RtcMediaService());
final rtcSignalingProvider = Provider((ref) => RtcSignalingService());
// ✅ Simple provider for the API service
final rtcApiServiceProvider = Provider(
  (ref) => api.RtcApiService(),
); // ← USE api.

// ✅ State provider for RTC state
final rtcStateProvider = StateNotifierProvider<RtcNotifier, RtcState>((ref) {
  return RtcNotifier();
});

// ==================== STATE CLASS ====================

class RtcState {
  final bool isLoading;
  final String? error;
  final String? userId;
  final int? roomId;
  final String? rtcToken;
  final List<dynamic>? rooms;
  final bool isConnected;

  RtcState({
    this.isLoading = false,
    this.error,
    this.userId,
    this.roomId,
    this.rtcToken,
    this.rooms,
    this.isConnected = false,
  });

  RtcState copyWith({
    bool? isLoading,
    String? error,
    String? userId,
    int? roomId,
    String? rtcToken,
    List<dynamic>? rooms,
    bool? isConnected,
  }) {
    return RtcState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      userId: userId ?? this.userId,
      roomId: roomId ?? this.roomId,
      rtcToken: rtcToken ?? this.rtcToken,
      rooms: rooms ?? this.rooms,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

// ==================== NOTIFIER ====================

class RtcNotifier extends StateNotifier<RtcState> {
  RtcNotifier() : super(RtcState());

  // 1. Verify API
  Future<void> verifyApi() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await api.RtcApiService.verifyApi(); // ← USE api.
      state = state.copyWith(isLoading: false, isConnected: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // 2. Sync User
  Future<void> syncUser(String name, String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final data = await api.RtcApiService.syncUser(
        // ← USE api.
        externalUserId: userId,
        name: name,
        email: email,
      );
      final externalUserId = data['external_user_id'] ?? userId;
      state = state.copyWith(isLoading: false, userId: externalUserId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // 3. Create Room
  Future<void> createRoom(String roomName) async {
    if (state.userId == null) {
      state = state.copyWith(error: '⚠️ Sync user first!');
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('🔵🔵🔵 createRoom() called with userId: ${state.userId}');
      final data = await api.RtcApiService.createRoom(
        externalUserId: state.userId!,
        name: roomName,
      );
      print('🔵🔵🔵 createRoom() response: $data');
      final roomId = data['room']['id'] as int?;
      state = state.copyWith(isLoading: false, roomId: roomId);
    } catch (e) {
      print('❌ createRoom() error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // 4. Get RTC Token
  Future<void> getToken() async {
    if (state.userId == null || state.roomId == null) {
      state = state.copyWith(error: '⚠️ Sync user and create room first!');
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await api.RtcApiService.getToken(
        // ← USE api.
        externalUserId: state.userId!,
        roomId: state.roomId!,
      );
      final token = data['rtc_token'] as String?;
      state = state.copyWith(isLoading: false, rtcToken: token);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // 5. List Rooms
  Future<void> listRooms() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await api.RtcApiService.listRooms(); // ← USE api.
      final rooms = data['rooms'] as List<dynamic>?;
      state = state.copyWith(isLoading: false, rooms: rooms);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Reset
  void reset() {
    state = RtcState();
  }
}
