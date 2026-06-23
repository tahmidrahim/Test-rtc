import 'package:flutter/material.dart';

/// Widget for displaying participants in a grid with animation
class ParticipantsGrid extends StatelessWidget {
  final List<String> participants;
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
          final hasParticipant = index < participants.length;

          return Column(
            children: [
              AnimatedBuilder(
                animation: (isUserSeat && isSpeaking)
                    ? pulseAnimation
                    : const AlwaysStoppedAnimation(1.0),
                builder: (context, child) {
                  return Transform.scale(
                    scale: (isUserSeat && isSpeaking)
                        ? pulseAnimation.value
                        : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            hasParticipant ? Colors.black45 : Colors.black26,
                        border: (isUserSeat && isSpeaking)
                            ? Border.all(
                                color: const Color(0xFF1DE9B6),
                                width: 3,
                              )
                            : Border.all(color: Colors.transparent),
                        boxShadow: (isUserSeat && isSpeaking)
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF1DE9B6)
                                      .withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: hasParticipant
                          ? (isUserSeat && isSpeaking)
                                ? AnimatedBuilder(
                                    animation: micWaveAnimation,
                                    builder: (context, child) => Opacity(
                                      opacity: micWaveAnimation.value,
                                      child: const Icon(
                                        Icons.mic,
                                        color: Color(0xFF1DE9B6),
                                        size: 26,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    (isUserSeat && isMuted)
                                        ? Icons.mic_off
                                        : Icons.mic_none,
                                    color: (isUserSeat && isMuted)
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
}
