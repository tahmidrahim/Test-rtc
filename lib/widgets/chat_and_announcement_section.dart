import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hapi/providers/user_provider.dart';

/// Chat and announcement section for voice room
class ChatAndAnnouncementSection extends StatefulWidget {
  final String? roomId;
  final UserModel user;

  const ChatAndAnnouncementSection({
    super.key,
    required this.roomId,
    required this.user,
  });

  @override
  State<ChatAndAnnouncementSection> createState() =>
      _ChatAndAnnouncementSectionState();
}

class _ChatAndAnnouncementSectionState extends State<ChatAndAnnouncementSection> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (widget.roomId == null) return;
    if (text.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
            'senderId': widget.user.id,
            'senderName': widget.user.name,
            'message': text,
            'type': 'text',
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('❌ Error sending message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Text(
            "Welcome ${widget.user.name} entered room",
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(height: 6),
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
          if (widget.roomId != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                reverse: true,
                child: _buildChatMessages(),
              ),
            ),
          if (widget.roomId != null) _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildChatMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
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
            final isMe = data['senderId'] == widget.user.id;
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

  Widget _buildChatInput() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: const InputDecoration(
                hintText: 'Say hi...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (text) {
                _sendMessage(text);
                _controller.clear();
              },
            ),
          ),
          GestureDetector(
            onTap: () {
              final text = _controller.text.trim();
              _sendMessage(text);
              _controller.clear();
            },
            child: const Icon(Icons.send, size: 14, color: Color(0xFF1DE9B6)),
          ),
        ],
      ),
    );
  }
}
