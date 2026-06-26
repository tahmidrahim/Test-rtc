import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hapi/providers/user_provider.dart';
import 'package:hapi/services/rtc/funint_rtc_extended_service.dart';
import 'package:permission_handler/permission_handler.dart';

enum _RoomMode { voice, video }

const _emojiOptions = [
  '😀',
  '😂',
  '😍',
  '😎',
  '🥳',
  '👏',
  '🔥',
  '💯',
  '❤️',
  '👍',
  '🙏',
  '🎉',
];

class _ChatMessage {
  final String sender;
  final String text;
  final bool isLocal;
  final bool isSystem;
  final DateTime time;

  _ChatMessage({
    required this.sender,
    required this.text,
    this.isLocal = false,
    this.isSystem = false,
  }) : time = DateTime.now();
}

class RtcTestScreen extends ConsumerStatefulWidget {
  const RtcTestScreen({super.key});
  @override
  ConsumerState<RtcTestScreen> createState() => _RtcTestScreenState();
}

class _RtcTestScreenState extends ConsumerState<RtcTestScreen> {
  final FunintRtcExtended _rtc = FunintRtcExtended();
  final _roomController = TextEditingController(text: 'test_room_123');
  final _msgController = TextEditingController();
  final _chatScrollController = ScrollController();

  bool _isJoined = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isVideoEnabled = true;
  bool _isScreenSharing = false;
  bool _isJoining = false;

  _RoomMode _mode = _RoomMode.voice;
  String _status = 'Disconnected';
  String? _connectedRoom;
  String _connectionIndicator = '';

  final List<String> _remoteUsers = [];
  final List<_ChatMessage> _chat = [];
  StreamSubscription<FunintRtcEventData>? _eventSub;

  @override
  void initState() {
    super.initState();
    _initRtc();
  }

  Future<void> _initRtc() async {
    await _rtc.initialize();
    _eventSub = _rtc.events.listen(_onEvent);
    _addSystem('RTC ready');
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _rtc.dispose();
    _roomController.dispose();
    _msgController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _onEvent(FunintRtcEventData e) {
    if (!mounted) return;
    setState(() {
      switch (e.event) {
        case FunintRtcEvent.connected:
          _status = 'Connecting…';
          break;
        case FunintRtcEvent.joinedChannel:
          _connectedRoom = e.channel;
          _status = 'In Room';
          _isJoined = true;
          _isJoining = false;
          _addSystem('Joined ${e.channel}');
          break;
        case FunintRtcEvent.localStream:
          _addSystem('Local stream ready');
          // Removed manual attachment - Kotlin handles this automatically now
          break;
        case FunintRtcEvent.remoteUserJoined:
          final uid = e.uid ?? 'unknown';
          if (!_remoteUsers.contains(uid)) {
            _remoteUsers.add(uid);
            _addSystem('$uid joined');
          }
          break;
        case FunintRtcEvent.remoteUserLeft:
          final uid = e.uid ?? 'unknown';
          _remoteUsers.remove(uid);
          _addSystem('$uid left');
          break;
        case FunintRtcEvent.connectionState:
          _connectionIndicator = e.state ?? '';
          break;
        case FunintRtcEvent.messageReceived:
          _chat.add(
            _ChatMessage(
              sender: e.sender ?? 'participant',
              text: e.message ?? '',
            ),
          );
          _scrollToBottom();
          break;
        case FunintRtcEvent.messageSent:
          _chat.add(
            _ChatMessage(sender: 'You', text: e.message ?? '', isLocal: true),
          );
          _scrollToBottom();
          break;
        case FunintRtcEvent.screenShareStarted:
          _isScreenSharing = true;
          _addSystem('Screen share started');
          break;
        case FunintRtcEvent.screenShareStopped:
          _isScreenSharing = false;
          _addSystem('Screen share stopped');
          break;
        case FunintRtcEvent.userMuteAudio:
          if (e.uid == 'local') _isMuted = e.muted ?? _isMuted;
          break;
        case FunintRtcEvent.leftChannel:
          _resetState();
          break;
        case FunintRtcEvent.error:
          _status = 'Error';
          _isJoining = false;
          _addSystem('⚠ ${e.message}');
          break;
        default:
          break;
      }
    });
  }

  void _resetState() {
    _isJoined = false;
    _isJoining = false;
    _status = 'Disconnected';
    _connectedRoom = null;
    _remoteUsers.clear();
    _isMuted = false;
    _isVideoEnabled = true;
    _isScreenSharing = false;
    _connectionIndicator = '';
  }

  void _addSystem(String text) {
    _chat.add(_ChatMessage(sender: 'System', text: text, isSystem: true));
    if (_chat.length > 100) _chat.removeAt(0);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Actions ──────────────────────────────────
  Future<void> _joinRoom() async {
    final roomId = _roomController.text.trim();
    final user = ref.read(userProvider);
    if (roomId.isEmpty || user.id.isEmpty || _isJoining) return;

    final neededPermissions = _mode == _RoomMode.video
        ? [Permission.camera, Permission.microphone]
        : [Permission.microphone];

    final statuses = await neededPermissions.request();
    if (!statuses.values.every((s) => s == PermissionStatus.granted)) {
      _addSystem('Required permissions denied');
      return;
    }

    setState(() {
      _isJoining = true;
      _status = 'Joining…';
      _remoteUsers.clear();
    });

    try {
      if (_mode == _RoomMode.video) {
        await _rtc.joinVideoRoom(roomId, user.id);
        setState(() => _isVideoEnabled = true);
      } else {
        await _rtc.joinVoiceRoom(roomId, user.id);
      }
    } catch (e) {
      setState(() {
        _isJoining = false;
        _status = 'Join failed';
      });
    }
  }

  Future<void> _leaveRoom() async {
    await _rtc.leaveRoom();
    setState(_resetState);
  }

  Future<void> _toggleMute() async {
    await _rtc.toggleMute();
    setState(() => _isMuted = _rtc.isMuted);
  }

  Future<void> _toggleVideo() async {
    await _rtc.toggleVideo();
    setState(() => _isVideoEnabled = _rtc.isVideoEnabled);
    _addSystem(_isVideoEnabled ? 'Camera on' : 'Camera off');
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    await _rtc.setSpeakerphone(_isSpeakerOn);
  }

  Future<void> _toggleScreenShare() async {
    if (_isScreenSharing) {
      await _rtc.stopScreenShare();
    } else {
      await _rtc.startScreenShare();
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || !_isJoined) return;
    await _rtc.sendMessage(text);
    _msgController.clear();
  }

  Future<void> _sendEmoji(String emoji) async {
    if (!_isJoined) return;
    await _rtc.sendEmoji(emoji);
    Navigator.pop(context);
  }

  // ─── Build ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Stack(
                    children: [
                      if (_mode == _RoomMode.video) _buildVideoStage(),
                      if (_mode == _RoomMode.voice && _isJoined)
                        _buildVoiceStage(),
                      if (!_isJoined) _buildJoinOverlay(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isJoined)
            Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomBar()),
        ],
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {
              if (_isJoined) _leaveRoom();
              Navigator.pop(context);
            },
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isJoined
                          ? const Color(0xFF1DE9B6)
                          : _isJoining
                          ? Colors.amber
                          : Colors.white30,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isJoined
                              ? (_connectedRoom ?? 'Unknown Room')
                              : _status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (_connectionIndicator.isNotEmpty)
                          Text(
                            _connectionIndicator,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_isJoined) ...[
                    const Icon(
                      Icons.people,
                      color: Color(0xFF1DE9B6),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_remoteUsers.length + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isJoined)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: GestureDetector(
                onTap: _leaveRoom,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Leave',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── JOIN OVERLAY ────────────────────────────
  Widget _buildJoinOverlay() {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _modeTab('Voice', _RoomMode.voice, Icons.mic),
                    _modeTab('Video', _RoomMode.video, Icons.videocam),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _roomController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Room ID',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isJoining ? null : _joinRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DE9B6),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isJoining
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black54,
                          ),
                        )
                      : Text(
                          'Join ${_mode == _RoomMode.voice ? 'Voice' : 'Video'} Room',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeTab(String label, _RoomMode mode, IconData icon) {
    final isActive = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF1DE9B6).withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF1DE9B6) : Colors.white38,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? const Color(0xFF1DE9B6) : Colors.white38,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── VIDEO STAGE ─────────────────────────────
  Widget _buildVideoStage() {
    final count = (_remoteUsers.length + 1).clamp(1, 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 250),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: count.clamp(1, 2),
        itemBuilder: (_, index) {
          final isLocal = index == 0;
          return _buildVideoTile(isLocal);
        },
      ),
    );
  }

  Widget _buildVideoTile(bool isLocal) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLocal && !_isMuted
              ? const Color(0xFF1DE9B6)
              : Colors.white10,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AndroidView(
              viewType: 'funint_rtc_video_view',
              creationParams: {'isLocal': isLocal},
              creationParamsCodec: const StandardMessageCodec(),
            ),
            if (isLocal && !_isVideoEnabled)
              Container(
                color: const Color(0xFF0F172A),
                child: const Center(
                  child: Icon(
                    Icons.videocam_off,
                    color: Colors.white24,
                    size: 40,
                  ),
                ),
              ),
            if (isLocal && _isScreenSharing)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Sharing',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLocal && _isMuted ? Icons.mic_off : Icons.mic,
                      color: isLocal && _isMuted
                          ? Colors.redAccent
                          : Colors.white,
                      size: 11,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isLocal ? 'You' : 'Remote',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── VOICE STAGE ─────────────────────────────
  Widget _buildVoiceStage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 250),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            _connectedRoom ?? 'Voice Room',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_remoteUsers.length + 1} participant${_remoteUsers.isEmpty ? '' : 's'}',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _buildVoiceParticipantTile('You (local)', isLocal: true),
          ...(_remoteUsers.map(
            (uid) => _buildVoiceParticipantTile(uid, isLocal: false),
          )),
        ],
      ),
    );
  }

  Widget _buildVoiceParticipantTile(String label, {required bool isLocal}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isLocal && !_isMuted)
              ? const Color(0xFF1DE9B6).withValues(alpha: 0.4)
              : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1DE9B6).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Color(0xFF1DE9B6), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Icon(
            (isLocal && _isMuted) ? Icons.mic_off : Icons.mic,
            color: (isLocal && _isMuted) ? Colors.redAccent : Colors.white54,
            size: 18,
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM BAR ──────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF0F172A).withValues(alpha: 0.85),
            const Color(0xFF0F172A),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_buildChatList(), _buildMessageInput(), _buildControls()],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        controller: _chatScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _chat.length,
        itemBuilder: (_, i) {
          final msg = _chat[i];
          if (msg.isSystem) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                msg.text,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${msg.sender}: ',
                  style: TextStyle(
                    color: msg.isLocal ? const Color(0xFF1DE9B6) : Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Expanded(
                  child: Text(
                    msg.text,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Say something…',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.emoji_emotions_outlined,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onPressed: _showEmojiPicker,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Color(0xFF1DE9B6),
                      size: 20,
                    ),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlBtn(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            label: _isMuted ? 'Muted' : 'Mic',
            active: !_isMuted,
            activeColor: Colors.white,
            inactiveColor: Colors.redAccent,
            onTap: _toggleMute,
          ),
          _controlBtn(
            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
            label: 'Speaker',
            active: _isSpeakerOn,
            activeColor: Colors.white,
            inactiveColor: Colors.white38,
            onTap: _toggleSpeaker,
          ),
          if (_mode == _RoomMode.video)
            _controlBtn(
              icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              label: 'Camera',
              active: _isVideoEnabled,
              activeColor: Colors.white,
              inactiveColor: Colors.white38,
              onTap: _toggleVideo,
            ),
          if (_mode == _RoomMode.video)
            _controlBtn(
              icon: Icons.screen_share,
              label: _isScreenSharing ? 'Sharing' : 'Share',
              active: _isScreenSharing,
              activeColor: const Color(0xFF1DE9B6),
              inactiveColor: Colors.white38,
              onTap: _toggleScreenShare,
            ),
        ],
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required bool active,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black38,
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? Colors.white24 : Colors.transparent,
              ),
            ),
            child: Icon(
              icon,
              color: active ? activeColor : inactiveColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white70 : Colors.white30,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF161616),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _emojiOptions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _sendEmoji(_emojiOptions[i]),
                child: Center(
                  child: Text(
                    _emojiOptions[i],
                    style: const TextStyle(fontSize: 30),
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
