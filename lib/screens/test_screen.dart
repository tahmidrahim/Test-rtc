import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hapi/providers/rtc_provider.dart';

class TestRtcScreen extends ConsumerStatefulWidget {
  const TestRtcScreen({super.key});

  @override
  ConsumerState<TestRtcScreen> createState() => _TestRtcScreenState();
}

class _TestRtcScreenState extends ConsumerState<TestRtcScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _responseData;
  String? _error;
  String _step = 'Ready';

  @override
  void initState() {
    super.initState();
    _testSdk();
  }

  Future<void> _testSdk() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _responseData = null;
    });

    try {
      final sdk = ref.read(rtcSdkProvider);
      final userId = 'test_user_${DateTime.now().millisecondsSinceEpoch}';

      // Step 1: Sync user (skip verifyKey)
      _step = 'Syncing user...';
      print('🔄 Syncing user...');
      final syncResponse = await sdk.syncExternalUser(
        externalUserId: userId,
        name: 'Test User',
        email: 'test@example.com',
      );
      print('✅ User synced: $syncResponse');

      // Step 2: Create room
      _step = 'Creating room...';
      print('🔄 Creating room...');
      final roomResponse = await sdk.createRoom(
        externalUserId: userId,
        name: 'Test Room',
        roomType: 'voice',
      );
      print('✅ Room created: $roomResponse');
      setState(() => _responseData = roomResponse);

      // Step 3: Get token
      _step = 'Getting token...';
      print('🔄 Getting token...');
      final tokenResponse = await sdk.issueRtcToken(
        externalUserId: userId,
        roomId: roomResponse['room']['id'],
        role: 'publisher',
        rtcMode: 'voice',
      );
      setState(() => _responseData = tokenResponse);

      print('✅ SDK Test Successful!');
      print('Room ID: ${roomResponse['room']['id']}');
      print('Token: ${tokenResponse['rtc_token']?.substring(0, 30)}...');
    } catch (e) {
      setState(() => _error = e.toString());
      print('❌ Error at step $_step: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RTC SDK Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Step: $_step',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (_isLoading) const CircularProgressIndicator(),

            if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('❌ Error: $_error'),
                ),
              ),

            if (_responseData != null)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('✅ Success!'),
                      const SizedBox(height: 8),
                      Text(
                        'Response: ${_responseData!.toString().substring(0, 100)}...',
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _testSdk,
              child: const Text('Re-Test SDK'),
            ),
          ],
        ),
      ),
    );
  }
}
