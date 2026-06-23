import 'package:flutter/material.dart';
import 'package:hapi/providers/user_provider.dart';
import 'package:hapi/widgets/animated_avatar.dart';

/// Host section showing the room host
class HostSection extends StatelessWidget {
  final UserModel user;

  const HostSection({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedAvatar(
          imageUrl: user.photoUrl,
          radius: 26,
          animationSize: 76,
        ),
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
}
