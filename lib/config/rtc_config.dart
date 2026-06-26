class RtcConfig {
  // ── Chadnichok RTC Server ─────────────────────────────
  static const String serverUrl = 'wss://chadnichok.com';
  static const String apiKey = 'ap_201fdec1ecebb8804d32b0a4';
  static const String apiSecret = 'YOUR_APP_SECRET';
  static const String sdkTokenUrl = 'https://chadnichok.com/auth/sdkTokens';
  static const String livekitTokenUrl =
      'https://chadnichok.com/auth/livekitTokens';

  // ── SDK Headers ───────────────────────────────────────
  static const String sdkClient = 'flutter';
  static const String sdkVersion = '1.0.0';

  // ── Room settings ─────────────────────────────────────
  static const int maxParticipants = 10;
  static const bool enableLogging = true;
}
