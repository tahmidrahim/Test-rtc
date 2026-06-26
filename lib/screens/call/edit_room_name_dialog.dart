import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hapi/providers/navigation_provider.dart';
import 'package:hapi/providers/user_provider.dart';
import 'package:hapi/widgets/custom/hapi_button.dart';
import 'package:hapi/widgets/custom/hapi_avatar.dart';

class EditRoomNameScreen extends ConsumerStatefulWidget {
  const EditRoomNameScreen({super.key});

  @override
  ConsumerState<EditRoomNameScreen> createState() => _EditRoomNameScreenState();
}

class _EditRoomNameScreenState extends ConsumerState<EditRoomNameScreen> {
  final TextEditingController _controller = TextEditingController();
  int maxLength = 30;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    _controller.text = user.name;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Room Name',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          _buildProfileImage(),
          const SizedBox(height: 40),
          _buildNameInput(),
          const SizedBox(height: 30),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    final user = ref.read(userProvider);

    return Center(
      child: HapiAvatar(
        imageUrl: user.photoUrl,
        radius: 60,
        showAnimation: false,
      ),
    );
  }

  Widget _buildNameInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _controller,
              onChanged: (value) => setState(() {}),
              maxLength: maxLength,
              decoration: const InputDecoration(
                counterText: "",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_controller.text.length}/$maxLength',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: HapiButton(
        text: 'Submit',
        onPressed: () {
          final roomName = _controller.text.trim();
          if (roomName.isNotEmpty) {
            ref
                .read(navigationProvider.notifier)
                .goToVoiceRoom(roomId: roomName, isCreating: true);
          }
        },
      ),
    );
  }
}
