import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hapi/providers/call_provider.dart';
import 'package:hapi/providers/navigation_provider.dart';
import 'package:hapi/providers/services_provider.dart';
import 'package:hapi/providers/user_provider.dart';
import 'package:hapi/screens/home/home_screen.dart';
import 'package:hapi/services/rtc_api_service.dart';
import 'package:hapi/services/rtc_media_service.dart';
import 'package:hapi/widgets/custom/hapi_dialog.dart';
import 'package:hapi/widgets/game/game_selector.dart';
import 'package:hapi/widgets/voice_room_header.dart';
import 'package:hapi/widgets/host_section.dart';
import 'package:hapi/widgets/participants_grid.dart';
import 'package:hapi/widgets/voice_room_toolbar.dart';
import 'package:hapi/widgets/chat_and_announcement_section.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRoomScreen extends ConsumerStatefulWidget {
  final String? roomId;
  final bool isCreating;

  const VoiceRoomScreen({super.key, this.roomId, this.isCreating = false});

  @override
  ConsumerState<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends ConsumerState<VoiceRoomScreen>
    with TickerProviderStateMixin {
  // State variables
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isConnected = false;
  String _connectionStatus = 'Connecting...';
  String? _currentRoomId;
  int _participantCount = 1;
  List<String> _participants = [];
  String? _floatingEmoji;
  Timer? _emojiTimer;

  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _micWaveController;
  late Animation<double> _micWaveAnimation;
  StreamSubscription? _participantsSubscription;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initVoiceChat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeCallProvider.notifier).startCall(widget.roomId ?? 'call');
    });
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCirc),
    );

    _micWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _micWaveAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _micWaveController, curve: Curves.easeIn),
    );
  }

  void _listenToParticipants() {
    final channelName = widget.roomId ?? _currentRoomId;
    if (channelName == null) return;

    final roomService = ref.read(roomFirestoreServiceProvider);
    _participantsSubscription = roomService.streamRoom(channelName).listen(
      (snapshot) {
        final roomData = snapshot.data() as Map<String, dynamic>?;
        if (roomData != null && mounted) {
          final participants = List<String>.from(
            roomData['participants'] ?? [],
          );
          setState(() {
            _participants = participants;
            _participantCount = participants.length;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _micWaveController.dispose();
    _participantsSubscription?.cancel();
    _emojiTimer?.cancel();
    super.dispose();
  }

  Future<void> _initVoiceChat() async {
    final micStatus = await Permission.microphone.request();
    if (micStatus.isDenied) {
      setState(() => _connectionStatus = 'Microphone permission denied');
      return;
    }

    try {
      setState(() => _connectionStatus = 'Initializing...');
      final user = ref.read(userProvider);
      
      // Verify API connection
      await RtcApiService.verifyApi();
      print('✅ API verified');

      // Initialize WebRTC media service
      final mediaService = RtcMediaService();
      await mediaService.getLocalAudio();
      print('✅ Local audio initialized');

      setState(() => _connectionStatus = 'Joining channel...');
      final channelName =
          widget.roomId ?? "room_${DateTime.now().millisecondsSinceEpoch}";
      _currentRoomId = channelName;

      // Create room via API (only if creating)
      if (widget.isCreating) {
        final roomResponse = await RtcApiService.createRoom(
          externalUserId: user.id,
          name: channelName,
          roomType: 'audio',
        );
        print('✅ Room created: ${roomResponse['room_id']}');
      }

      if (mounted) {
        setState(() {
          _isConnected = true;
          _connectionStatus = 'Connected';
        });

        if (widget.isCreating) {
          await _saveRoomToFirestore(channelName);
        } else {
          await _joinExistingRoom(channelName);
        }
        _listenToParticipants();
      }
    } catch (e) {
      debugPrint("Detailed Error: $e");
      if (mounted) {
        setState(() => _connectionStatus = 'Connection failed');
      }
    }
  }

  Future<void> _saveRoomToFirestore(String channelName) async {
    final user = ref.read(userProvider);
    
    await FirebaseFirestore.instance.collection('rooms').add({
      'roomId': channelName,
      'roomName': widget.roomId ?? 'My Room',
      'hostId': user.id,
      'hostName': user.name,
      'hostPhotoUrl': user.photoUrl ?? '',
      'participants': [user.id],
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _joinExistingRoom(String channelName) async {
    final user = ref.read(userProvider);
    try {
      final roomService = ref.read(roomFirestoreServiceProvider);
      await roomService.addParticipant(channelName, user.id);
    } catch (e) {
      print('Error joining room: $e');
    }
  }

  Future<void> _updateRoomOnExit() async {
    final user = ref.read(userProvider);
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .where('hostId', isEqualTo: user.id)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      for (var doc in querySnapshot.docs) {
        final participants = List<String>.from(doc['participants'] ?? []);
        participants.remove(user.id);
        if (participants.isEmpty) {
          await doc.reference.delete();
        } else {
          await doc.reference.update({
            'participants': participants,
            'isActive': participants.isNotEmpty,
          });
        }
      }
    } catch (e) {
      print('Error updating room on exit: $e');
    }
  }

  void _toggleMute() async {
    _isMuted = !_isMuted;
    final mediaService = RtcMediaService();
    mediaService.muteAudio(_isMuted);
    setState(() {});
  }

  void _toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    // Speaker control is handled by Flutter WebRTC internally
    // _isSpeakerOn state is for UI display
    setState(() {});
  }

  Future<void> _exitRoom() async {
    await _updateRoomOnExit();
    final mediaService = RtcMediaService();
    await mediaService.dispose();
    ref.read(activeCallProvider.notifier).endCall();
    if (mounted) {
      ref.read(navigationProvider.notifier).goToHome();
    }
  }

  void _showExitOptions() {
    HapiDialog.showConfirm(
      context: context,
      title: 'Exit Room',
      message: 'Do you want to end the call?',
      confirmText: 'Exit',
      cancelText: 'Stay',
    ).then((shouldExit) {
      if (shouldExit == true) {
        _exitRoom();
      }
    });
  }

  void _openGameSelector() {
    final user = ref.read(userProvider);
    GameSelector.show(context, user.id);
  }

  void _showEmojiPicker() {
    final roomId = _currentRoomId ?? widget.roomId;
    if (roomId == null || roomId.trim().isEmpty) {
      _showRoomNotice('Room is not ready yet', isError: true);
      return;
    }

    const emojiOptions = [
      '😀', '😂', '😍', '😎', '🥳', '👏', '🔥', '💯',
      '❤️', '👍', '🙏', '🎉',
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: Color(0xFF161616),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Reactions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: emojiOptions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final emoji = emojiOptions[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _sendEmojiReaction(roomId, emoji);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendEmojiReaction(String roomId, String emoji) async {
    final user = ref.read(userProvider);
    final roomService = ref.read(roomFirestoreServiceProvider);
    try {
      await roomService.sendMessage(
        roomDocumentId: roomId,
        senderId: user.id,
        senderName: user.name,
        message: emoji,
        type: 'emoji',
      );
      _showFloatingEmoji(emoji);
      _showRoomNotice('Emoji sent');
    } catch (e) {
      debugPrint('Error sending emoji: $e');
    }
  }

  void _showFloatingEmoji(String emoji) {
    if (!mounted) return;
    _emojiTimer?.cancel();
    setState(() => _floatingEmoji = emoji);
    _emojiTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _floatingEmoji = null);
      }
    });
  }

  void _showRoomNotice(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
        backgroundColor: isError ? Colors.red : const Color(0xFF1DE9B6),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 108),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final bool isSpeaking = _isConnected && !_isMuted;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final shouldEnd = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave Room'),
            content: const Text('What do you want to do?'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Keep Call',
                  style: TextStyle(color: Colors.green),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'End Call',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );

        if (shouldEnd == true) {
          final mediaService = RtcMediaService();
          await mediaService.dispose();
          ref.read(activeCallProvider.notifier).endCall();
        }

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/bg.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // Dark overlay
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),

            // Main content
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    VoiceRoomHeader(
                      user: user,
                      participantCount: _participantCount,
                      connectionStatus: _connectionStatus,
                      isConnected: _isConnected,
                      onSettingsTap: () {},
                      onShareTap: () {},
                      onExitTap: _showExitOptions,
                    ),
                    const SizedBox(height: 8),
                    HostSection(user: user),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ParticipantsGrid(
                          participants: _participants,
                          isSpeaking: isSpeaking,
                          isMuted: _isMuted,
                          pulseAnimation: _pulseAnimation,
                          micWaveAnimation: _micWaveAnimation,
                        ),
                      ),
                    ),
                    const SizedBox(height: 220),
                  ],
                ),
              ),
            ),

            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChatAndAnnouncementSection(
                        roomId: _currentRoomId ?? widget.roomId,
                        user: user,
                      ),
                      const SizedBox(height: 10),
                      VoiceRoomToolbar(
                        isMuted: _isMuted,
                        isSpeakerOn: _isSpeakerOn,
                        onSpeakerToggle: _toggleSpeaker,
                        onMicToggle: _toggleMute,
                        onEmojiTap: _showEmojiPicker,
                        onExitTap: _showExitOptions,
                        onGameTap: _openGameSelector,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Floating emoji
            if (_floatingEmoji != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedScale(
                      scale: 1.0,
                      duration: const Duration(milliseconds: 160),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.42),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          _floatingEmoji!,
                          style: const TextStyle(fontSize: 54),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
