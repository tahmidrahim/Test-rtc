import 'package:flutter/material.dart';

class MessageScreen extends StatelessWidget {
  const MessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Gradient Background Header
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1DE9B6), Colors.white],
                stops: [0.0, 0.8],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 10),
                    children: [
                      _buildHeaderTile(
                        Icons.notifications,
                        const Color(0xFF5C6BC0),
                        'Notifications',
                      ),
                      _buildActivityTile(),
                      _buildHeaderTile(
                        Icons.groups,
                        const Color(0xFFFFB74D),
                        'Family',
                      ),
                      _buildFeedbackTile(),
                      _buildSayHiTile(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          const Text(
            'Message',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const Spacer(),
          const Icon(Icons.check_circle_outline, color: Colors.black54),
        ],
      ),
    );
  }

  Widget _buildHeaderTile(IconData icon, Color color, String title) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildActivityTile() {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFFF8A65),
        child: Icon(Icons.flag, color: Colors.white, size: 22),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text('Activity', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('8:36', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
      subtitle: Row(
        children: [
          const Expanded(
            child: Text(
              '👸Ladies, become shining stars now!🌟💖 👠Ex...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13),
            ),
          ),
          _buildBadge('23', const Color(0xFFF06292)),
        ],
      ),
    );
  }

  Widget _buildFeedbackTile() {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF1DE9B6),
        child: const Icon(Icons.headset_mic, color: Colors.black, size: 22),
      ),
      title: const Text(
        'Feedback',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSayHiTile() {
    return Column(
      children: [
        const Divider(indent: 70, endIndent: 20, height: 1),
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF4FC3F7),
            child: Icon(Icons.chat_bubble, color: Colors.white, size: 20),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Say Hi', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('10:45', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          subtitle: Row(
            children: [
              const Expanded(
                child: Text(
                  'MR.X: 👉follow me new ID 👉and get 7000000 coin...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13),
                ),
              ),
              _buildBadge('4', Colors.red),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}
