import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hapi/providers/call_provider.dart';
import 'package:hapi/providers/navigation_provider.dart';
import 'package:hapi/providers/user_provider.dart';
import 'package:hapi/screens/home/home_screen.dart';
import 'package:hapi/services/agora_service.dart';
import 'package:hapi/widgets/animated_avatar.dart';
import 'package:hapi/widgets/custom/hapi_dialog.dart';
import 'package:hapi/widgets/custom/voice_chat_widget.dart';
import 'package:hapi/widgets/game/game_selector.dart';
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
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isConnected = false;
  String _connectionStatus = 'Connecting...';
  String? _currentRoomId;
  bool _isExiting = false;
  int _participantCount = 1;
  List<String> _participants = [];

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

    _participantsSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .where('roomId', isEqualTo: channelName)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty && mounted) {
            final roomData = snapshot.docs.first.data();
            final participants = List<String>.from(
              roomData['participants'] ?? [],
            );
            setState(() {
              _participants = participants;
              _participantCount = participants.length;
            });
          }
        });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _micWaveController.dispose();
    _participantsSubscription?.cancel();
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
      await AgoraService.initialize();

      setState(() => _connectionStatus = 'Joining channel...');
      final channelName =
          widget.roomId ?? "room_${DateTime.now().millisecondsSinceEpoch}";
      _currentRoomId = channelName;

      await AgoraService.joinChannel(
        channelName: channelName,
        token: "",
        uid: 0,
      );

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
      final querySnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .where('roomId', isEqualTo: channelName)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        await doc.reference.update({
          'participants': FieldValue.arrayUnion([user.id]),
        });
      }
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
    await AgoraService.muteLocalAudio(!_isMuted);
    setState(() => _isMuted = !_isMuted);
  }

  void _toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await AgoraService.setSpeakerphoneOn(_isSpeakerOn);
    setState(() {});
  }

  Future<void> _exitRoom() async {
    _isExiting = true;
    await _updateRoomOnExit();
    await AgoraService.dispose();
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final bool isSpeaking = _isConnected && !_isMuted;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // Show dialog asking what to do
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
          // End the call completely
          await AgoraService.dispose();
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
            // 1. Background Image layer
            Positioned.fill(child: _buildBackground()),

            // 2. Dim Dark Overlay layer
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),

            // 3. Top and Central Layout Blocks
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _buildHeader(user),
                    const SizedBox(height: 8),
                    _buildStatusIndicator(),
                    const SizedBox(height: 8),
                    _buildHostSection(user),
                    const SizedBox(height: 8),

                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildMicGrid(isSpeaking),
                      ),
                    ),

                    const SizedBox(height: 220),
                  ],
                ),
              ),
            ),

            // 4. Bottom Workspace Panel
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
                      _buildChatAndAnnouncement(),
                      const SizedBox(height: 10),
                      _buildBottomToolbar(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/bg.jpg'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    Color statusColor = _isConnected
        ? Colors.green
        : (_connectionStatus == 'Connection failed'
              ? Colors.red
              : Colors.orange);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _connectionStatus,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _buildHeader(UserModel user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          AnimatedAvatar(
            imageUrl: user.photoUrl,
            radius: 11,
            animationSize: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.name.length > 15
                      ? "${user.name.substring(0, 15)}..."
                      : user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    const Text(
                      "ID: ",
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    Text(
                      user.id.length > 10
                          ? "${user.id.substring(0, 8)}..."
                          : user.id,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DE9B6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "$_participantCount",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 15),
          const Icon(Icons.share_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 15),
          GestureDetector(
            onTap: _showExitOptions,
            child: const Icon(
              Icons.power_settings_new,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostSection(UserModel user) {
    return Column(
      children: [
        AnimatedAvatar(imageUrl: user.photoUrl, radius: 26, animationSize: 76),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home, color: Colors.greenAccent, size: 14),
            const SizedBox(width: 4),
            Text(
              user.name.length > 15
                  ? "${user.name.substring(0, 15)}..."
                  : user.name,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMicGrid(bool isSpeaking) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 15,
          crossAxisSpacing: 10,
          childAspectRatio: 0.9,
        ),
        itemCount: 8,
        itemBuilder: (context, index) {
          final isUserSeat = index == 0;
          final hasParticipant = index < _participants.length;

          return Column(
            children: [
              AnimatedBuilder(
                animation: (isUserSeat && isSpeaking)
                    ? _pulseAnimation
                    : const AlwaysStoppedAnimation(1.0),
                builder: (context, child) {
                  return Transform.scale(
                    scale: (isUserSeat && isSpeaking)
                        ? _pulseAnimation.value
                        : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasParticipant ? Colors.black45 : Colors.black26,
                        border: (isUserSeat && isSpeaking)
                            ? Border.all(
                                color: const Color(0xFF1DE9B6),
                                width: 3,
                              )
                            : Border.all(color: Colors.transparent),
                        boxShadow: (isUserSeat && isSpeaking)
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF1DE9B6,
                                  ).withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: hasParticipant
                          ? (isUserSeat && isSpeaking)
                                ? AnimatedBuilder(
                                    animation: _micWaveAnimation,
                                    builder: (context, child) => Opacity(
                                      opacity: _micWaveAnimation.value,
                                      child: const Icon(
                                        Icons.mic,
                                        color: Color(0xFF1DE9B6),
                                        size: 26,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    (isUserSeat && _isMuted)
                                        ? Icons.mic_off
                                        : Icons.mic_none,
                                    color: (isUserSeat && _isMuted)
                                        ? Colors.red
                                        : Colors.white54,
                                    size: 24,
                                  )
                          : const Icon(
                              Icons.person_outline,
                              color: Colors.white38,
                              size: 24,
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                hasParticipant
                    ? (isUserSeat ? "You" : "User ${index + 1}")
                    : "No.${index + 1}",
                style: TextStyle(
                  color: (isUserSeat && isSpeaking)
                      ? const Color(0xFF1DE9B6)
                      : Colors.white70,
                  fontSize: 11,
                  fontWeight: (isUserSeat && isSpeaking)
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChatAndAnnouncement() {
    final user = ref.read(userProvider);
    final roomId = _currentRoomId ?? widget.roomId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Welcome message
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "Welcome to Hapi! Please respect each other and talk politely...",
              style: TextStyle(color: Colors.greenAccent, fontSize: 10),
            ),
          ),
          const SizedBox(height: 6),

          // User entered message
          Text(
            "Welcome ${user.name} entered room",
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(height: 6),

          // Announcement
          Row(
            children: const [
              Text(
                "Announcement: ",
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
              Expanded(
                child: Text(
                  "অল্প জীবনের গল্প বেশি",
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
              Icon(Icons.edit, color: Colors.white70, size: 12),
            ],
          ),
          const SizedBox(height: 8),

          // Chat messages - inline style
          if (roomId != null) _buildChatMessages(roomId, user),

          // Chat input
          if (roomId != null) _buildChatInput(roomId, user),
        ],
      ),
    );
  }

  Widget _buildChatMessages(String roomId, UserModel user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final messages = snapshot.data!.docs;
        if (messages.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: messages.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final isMe = data['senderId'] == user.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      '${data['senderName']}: ',
                      style: const TextStyle(
                        color: Color(0xFF1DE9B6),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      data['message'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (isMe)
                    const Text(
                      'You',
                      style: TextStyle(color: Colors.grey, fontSize: 9),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildChatInput(String roomId, UserModel user) {
    final TextEditingController controller = TextEditingController();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: const InputDecoration(
                hintText: 'Say hi...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (text) {
                if (text.trim().isEmpty) return;
                _sendMessage(roomId, user, text);
                controller.clear();
              },
            ),
          ),
          GestureDetector(
            onTap: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              _sendMessage(roomId, user, text);
              controller.clear();
            },
            child: const Icon(Icons.send, size: 14, color: Color(0xFF1DE9B6)),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String roomId, UserModel user, String message) {
    FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .add({
          'senderId': user.id,
          'senderName': user.name,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  Widget _buildBottomToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _toolbarButton(Icons.volume_up, 'Sound', _toggleSpeaker),
          _toolbarButton(
            _isMuted ? Icons.mic_off : Icons.mic,
            _isMuted ? 'Unmute' : 'Mute',
            _toggleMute,
            color: _isMuted ? Colors.red : Colors.white,
          ),
          _toolbarButton(Icons.emoji_emotions_outlined, 'Emoji', () {}),
          _toolbarButton(
            Icons.logout,
            'Exit',
            _showExitOptions,
            color: Colors.red,
          ),
          _toolbarButton(Icons.grid_view_rounded, 'Game', _openGameSelector),
        ],
      ),
    );
  }

  Widget _toolbarButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10), // Increased from 8
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: Icon(icon, color: color, size: 26), // Increased from 22
          ),
          const SizedBox(height: 6), // Increased from 4
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12, // Increased from 9
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
