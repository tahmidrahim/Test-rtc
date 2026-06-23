import 'package:flutter/material.dart';

/// Bottom toolbar for voice room controls
class VoiceRoomToolbar extends StatelessWidget {
  final bool isMuted;
  final bool isSpeakerOn;
  final VoidCallback onSpeakerToggle;
  final VoidCallback onMicToggle;
  final VoidCallback onEmojiTap;
  final VoidCallback onExitTap;
  final VoidCallback onGameTap;

  const VoiceRoomToolbar({
    super.key,
    required this.isMuted,
    required this.isSpeakerOn,
    required this.onSpeakerToggle,
    required this.onMicToggle,
    required this.onEmojiTap,
    required this.onExitTap,
    required this.onGameTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _toolbarButton(
            isSpeakerOn ? Icons.volume_up : Icons.phone_in_talk,
            isSpeakerOn ? 'Speaker' : 'Earpiece',
            onSpeakerToggle,
            color: isSpeakerOn ? Colors.white : const Color(0xFFFFB74D),
          ),
          _toolbarButton(
            isMuted ? Icons.mic_off : Icons.mic,
            isMuted ? 'Unmute' : 'Mute',
            onMicToggle,
            color: isMuted ? Colors.red : Colors.white,
          ),
          _toolbarButton(
            Icons.emoji_emotions_outlined,
            'Emoji',
            onEmojiTap,
          ),
          _toolbarButton(
            Icons.logout,
            'Exit',
            onExitTap,
            color: Colors.red,
          ),
          _toolbarButton(Icons.grid_view_rounded, 'Game', onGameTap),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
