abstract class IRTCService {
  Future<void> initialize();
  Future<void> joinChannel(String channelName, String token, String uid);
  Future<void> leaveChannel();
  Future<void> enableLocalAudio(bool enable);
  bool isMuted();
  Stream<Map<String, dynamic>> get events;
  void dispose();
}
