import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeCallProvider = StateNotifierProvider<ActiveCallNotifier, String?>((
  ref,
) {
  return ActiveCallNotifier();
});

class ActiveCallNotifier extends StateNotifier<String?> {
  ActiveCallNotifier() : super(null);

  void startCall(String roomId) {
    state = roomId;
  }

  void endCall() {
    state = null;
  }
}
