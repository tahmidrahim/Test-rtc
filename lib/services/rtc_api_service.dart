import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hapi/config/rtc_config.dart';

class RtcApiService {
  static String get _baseUrl => RtcConfig.apiBaseUrl;
  static String get _apiKey => RtcConfig.rtcClientApiKey;

  static Map<String, String> get _headers => {
    'x-rtc-api-key': _apiKey,
    'Content-Type': 'application/json',
  };

  // 1. Verify API key
  static Future<Map<String, dynamic>> verifyApi() async {
    print('🔵🔵🔵 VERIFY API CALLED');
    print('🔵 URL: $_baseUrl/client/me');
    print('🔵 Headers: $_headers');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/client/me'),
        headers: _headers,
      );
      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Verify API failed: ${response.statusCode} - ${response.body}',
        );
      }

      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Verify API error: $e');
      rethrow;
    }
  }

  // 2. Sync user
  static Future<Map<String, dynamic>> syncUser({
    required String externalUserId,
    required String name,
    String? email,
    String? avatarUrl,
  }) async {
    print('🔵🔵🔵 SYNC USER CALLED');
    print('🔵 externalUserId: $externalUserId');
    print('🔵 URL: $_baseUrl/client/users/sync');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/client/users/sync'),
        headers: _headers,
        body: jsonEncode({
          'external_user_id': externalUserId,
          'name': name,
          'email': email,
          'avatar_url': avatarUrl,
        }),
      );
      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Sync user failed: ${response.statusCode} - ${response.body}',
        );
      }

      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Sync user error: $e');
      rethrow;
    }
  }

  // 3. Create room
  static Future<Map<String, dynamic>> createRoom({
    required String externalUserId,
    required String name,
    String roomType = 'audio',
    String privacyType = 'public',
    bool chatEnabled = true,
  }) async {
    print('🔵🔵🔵 CREATE ROOM CALLED');
    print('🔵 externalUserId: $externalUserId');
    print('🔵 name: $name');
    print('🔵 URL: $_baseUrl/client/rooms');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/client/rooms'),
        headers: _headers,
        body: jsonEncode({
          'external_user_id': externalUserId,
          'name': name,
          'room_type': roomType,
          'privacy_type': privacyType,
          'chat_enabled': chatEnabled,
        }),
      );
      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Create room failed: ${response.statusCode} - ${response.body}',
        );
      }

      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Create room error: $e');
      rethrow;
    }
  }

  // 4. Get RTC token
  static Future<Map<String, dynamic>> getToken({
    required String externalUserId,
    required int roomId,
    String role = 'publisher',
    String rtcMode = 'audio',
    List<String> permissions = const ['join', 'publish_audio', 'chat'],
  }) async {
    print('🔵🔵🔵 GET TOKEN CALLED');
    print('🔵 externalUserId: $externalUserId');
    print('🔵 roomId: $roomId');
    print('🔵 URL: $_baseUrl/client/rtc/token');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/client/rtc/token'),
        headers: _headers,
        body: jsonEncode({
          'external_user_id': externalUserId,
          'room_id': roomId,
          'role': role,
          'rtc_mode': rtcMode,
          'permissions': permissions,
        }),
      );
      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Get token failed: ${response.statusCode} - ${response.body}',
        );
      }

      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Get token error: $e');
      rethrow;
    }
  }

  // 5. List rooms
  static Future<Map<String, dynamic>> listRooms() async {
    print('🔵🔵🔵 LIST ROOMS CALLED');
    print('🔵 URL: $_baseUrl/client/rooms');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/client/rooms'),
        headers: _headers,
      );
      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'List rooms failed: ${response.statusCode} - ${response.body}',
        );
      }

      return jsonDecode(response.body);
    } catch (e) {
      print('❌ List rooms error: $e');
      rethrow;
    }
  }
}
