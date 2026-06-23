import 'package:flutter/material.dart';
import 'package:hapi/providers/user_provider.dart';
import 'package:hapi/widgets/animated_avatar.dart';

/// Header widget for voice room showing host info and participant count
class VoiceRoomHeader extends StatelessWidget {
  final UserModel user;
  final int participantCount;
  final String connectionStatus;
  final bool isConnected;
  final VoidCallback onSettingsTap;
  final VoidCallback onShareTap;
  final VoidCallback onExitTap;

  const VoiceRoomHeader({
    super.key,
    required this.user,
    required this.participantCount,
    required this.connectionStatus,
    required this.isConnected,
    required this.onSettingsTap,
    required this.onShareTap,
    required this.onExitTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = isConnected
        ? Colors.green
        : (connectionStatus == 'Connection failed' ? Colors.red : Colors.orange);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
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
                            "$participantCount",
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
              GestureDetector(
                onTap: onSettingsTap,
                child: const Icon(Icons.settings_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: onShareTap,
                child: const Icon(Icons.share_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: onExitTap,
                child: const Icon(
                  Icons.power_settings_new,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              connectionStatus,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
