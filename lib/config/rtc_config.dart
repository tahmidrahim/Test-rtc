class RtcConfig {
  // WebRTC STUN Servers
  static const List<String> stunServers = [
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
    'stun:stun2.l.google.com:19302',
  ];

  static List<Map<String, dynamic>> get iceServers {
    return stunServers.map((url) => {'urls': url}).toList();
  }

  // Feature flags
  static const bool enableLogging = true;
  static const bool enableSimulation = true; // For UI testing

  // Room settings
  static const int maxRemoteUsers = 10;
}
