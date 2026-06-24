import 'package:flutter/material.dart';
import 'package:hapi/widgets/animation.dart';

class AnimatedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final double animationSize;

  const AnimatedAvatar({
    super.key,
    this.imageUrl,
    this.radius = 35,
    this.animationSize = 80,
  });

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFE0E0E0),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: radius * 1.2, color: Colors.grey[600]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: animationSize,
      height: animationSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated border
          SvgaAnimation(
            assetPath: 'assets/animation_1778864976525.svga',
            width: animationSize,
            height: animationSize,
            loop: true,
          ),
          // Profile picture with fallback
          CircleAvatar(
            radius: radius,
            backgroundColor: Colors.transparent,
            child: ClipOval(
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      width: radius * 2,
                      height: radius * 2,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
          ),
        ],
      ),
    );
  }
}
