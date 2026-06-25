import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ParticipantData {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final bool isMuted;

  const ParticipantData({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.isMuted = false,
  });
}

class ParticipantsGrid extends StatelessWidget {
  final List<ParticipantData> participants;
  final bool isSpeaking;
  final bool isMuted;
  final Animation<double> pulseAnimation;
  final Animation<double> micWaveAnimation;

  const ParticipantsGrid({
    super.key,
    required this.participants,
    required this.isSpeaking,
    required this.isMuted,
    required this.pulseAnimation,
    required this.micWaveAnimation,
  });

  @override
  Widget build(BuildContext context) {
    const int totalSeats = 8;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 15,
          crossAxisSpacing: 10,
          childAspectRatio: 0.75,
        ),
        itemCount: totalSeats,
        itemBuilder: (context, index) {
          // index 0 = local user (always filled)
          // index 1+ = remote participants
          final isUserSeat = index == 0;
          final hasParticipant = index < participants.length;
          final participant = hasParticipant ? participants[index] : null;

          final bool speaking = isUserSeat && isSpeaking;
          final bool muted = isUserSeat
              ? isMuted
              : (participant?.isMuted ?? false);

          return Column(
            children: [
              AnimatedBuilder(
                animation: speaking
                    ? pulseAnimation
                    : const AlwaysStoppedAnimation(1.0),
                builder: (context, child) {
                  return Transform.scale(
                    scale: speaking ? pulseAnimation.value : 1.0,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasParticipant ? Colors.black45 : Colors.black26,
                        border: speaking
                            ? Border.all(
                                color: const Color(0xFF1DE9B6),
                                width: 3,
                              )
                            : Border.all(color: Colors.white12),
                        boxShadow: speaking
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF1DE9B6,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: ClipOval(
                        child: hasParticipant
                            ? _buildAvatar(
                                participant?.photoUrl,
                                speaking,
                                muted,
                                micWaveAnimation,
                              )
                            : // Empty seat
                              const Icon(
                                Icons.person_outline,
                                color: Colors.white38,
                                size: 24,
                              ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              // Name
              Text(
                hasParticipant
                    ? (isUserSeat ? 'You' : participant?.displayName ?? 'User')
                    : 'No.${index + 1}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: speaking ? const Color(0xFF1DE9B6) : Colors.white70,
                  fontSize: 11,
                  fontWeight: speaking ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              // Mic status icon
              if (hasParticipant)
                Icon(
                  muted ? Icons.mic_off : Icons.mic_none,
                  color: muted ? Colors.red : Colors.white38,
                  size: 12,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatar(
    String? photoUrl,
    bool speaking,
    bool muted,
    Animation<double> micWaveAnimation,
  ) {
    if (speaking) {
      return AnimatedBuilder(
        animation: micWaveAnimation,
        builder: (context, child) => Container(
          width: 64,
          height: 64,
          color: Colors.black45,
          child: Opacity(
            opacity: micWaveAnimation.value,
            child: const Icon(Icons.mic, color: Color(0xFF1DE9B6), size: 26),
          ),
        ),
      );
    }

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return SizedBox(
        width: 64,
        height: 64,
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          fit: BoxFit.cover, // ← fills the circle
          width: 64,
          height: 64,
          placeholder: (context, url) => Container(
            width: 64,
            height: 64,
            color: Colors.black45,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF1DE9B6),
              ),
            ),
          ),
          errorWidget: (context, url, error) => _placeholderIcon(muted),
        ),
      );
    }

    return _placeholderIcon(muted);
  }

  Widget _placeholderIcon(bool muted) {
    return Container(
      width: 64,
      height: 64,
      color: Colors.black45,
      child: Icon(
        muted ? Icons.mic_off : Icons.person,
        color: muted ? Colors.red : Colors.white54,
        size: 28, // ← bigger icon
      ),
    );
  }
}
