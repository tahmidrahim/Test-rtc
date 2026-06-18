import 'package:http/http.dart' as http;
import 'dart:convert';

class RtcEnterpriseClientSdk {
  final String apiBaseUrl;
  final String apiKey;
  final http.Client _client = http.Client();

  RtcEnterpriseClientSdk({required this.apiBaseUrl, required this.apiKey});

  // 1. Verify API Key (GET /client/me)
  Future<Map<String, dynamic>> verifyKey() async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/client/me'), // ← Added /client/
      headers: _getHeaders(),
    );
    return _handleResponse(response);
  }

  // 2. Sync external user (POST /client/users/sync)
  Future<Map<String, dynamic>> syncExternalUser({
    required String externalUserId,
    required String name,
    required String email,
    String? avatarUrl,
    String status = 'active',
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/client/users/sync'), // ← Added /client/
      headers: _getHeaders(),
      body: json.encode({
        'external_user_id': externalUserId,
        'name': name,
        'email': email,
        'avatar_url': avatarUrl,
        'status': status,
        'metadata': metadata ?? {},
      }),
    );
    return _handleResponse(response);
  }

  // 3. Create room (POST /client/rooms)
  Future<Map<String, dynamic>> createRoom({
    required String externalUserId,
    required String name,
    String roomType = 'voice',
    String privacyType = 'public',
    int maxMicCount = 8,
    bool chatEnabled = true,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/client/rooms'), // ← Added /client/
      headers: _getHeaders(),
      body: json.encode({
        'external_user_id': externalUserId,
        'name': name,
        'room_type': roomType,
        'privacy_type': privacyType,
        'max_mic_count': maxMicCount,
        'chat_enabled': chatEnabled,
      }),
    );
    return _handleResponse(response);
  }

  // 4. Issue RTC token (POST /client/rtc/token)
  Future<Map<String, dynamic>> issueRtcToken({
    required String externalUserId,
    required int roomId,
    required String role,
    required String rtcMode,
    List<String>? permissions,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/client/rtc/token'), // ← Added /client/
      headers: _getHeaders(),
      body: json.encode({
        'external_user_id': externalUserId,
        'room_id': roomId,
        'role': role,
        'rtc_mode': rtcMode,
        'permissions': permissions ?? ['join', 'publish_audio', 'chat'],
      }),
    );
    return _handleResponse(response);
  }

  // 5. Start session (POST /client/rtc/session/start)
  Future<Map<String, dynamic>> startSession({
    required String externalUserId,
    required int roomId,
    required String role,
    required String rtcMode,
    bool micEnabled = true,
    bool cameraEnabled = true,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/client/rtc/session/start'), // ← Added /client/
      headers: _getHeaders(),
      body: json.encode({
        'external_user_id': externalUserId,
        'room_id': roomId,
        'role': role,
        'rtc_mode': rtcMode,
        'mic_enabled': micEnabled,
        'camera_enabled': cameraEnabled,
      }),
    );
    return _handleResponse(response);
  }

  // 6. End session (POST /client/rtc/session/end)
  Future<void> endSession({
    required String externalUserId,
    required int roomId,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/client/rtc/session/end'), // ← Added /client/
      headers: _getHeaders(),
      body: json.encode({
        'external_user_id': externalUserId,
        'room_id': roomId,
      }),
    );
    _handleResponse(response);
  }

  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }
}
