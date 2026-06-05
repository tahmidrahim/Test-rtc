// lib/screens/auth/complete_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hapi/providers/navigation_provider.dart';
import 'package:hapi/providers/user_provider.dart';
import 'package:hapi/widgets/custom/hapi_button.dart';
import 'package:hapi/widgets/custom/hapi_text_field.dart';
import 'package:hapi/widgets/custom/hapi_snackbar.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  String selectedGender = '';
  bool _isLoading = false;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    _nameController.text = user.name.isNotEmpty ? user.name : '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Complete your profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            // Profile Image with Edit Icon
            _buildProfileImage(user),

            const SizedBox(height: 30),
            const Text(
              "Please choose your gender",
              style: TextStyle(fontSize: 16),
            ),
            const Text(
              "Cannot modify after select gender",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Gender Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _genderOption("Boy", Icons.face_retouching_natural),
                _genderOption("Girl", Icons.face_3),
              ],
            ),

            const SizedBox(height: 30),

            // Name Input Field
            HapiTextField(
              controller: _nameController,
              hintText: "Enter your name",
              icon: Icons.person,
            ),

            const SizedBox(height: 16),

            // Location Input
            _buildLocationTile(),

            const SizedBox(height: 50),

            // Next Button
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : HapiButton(text: 'Next', onPressed: () => _saveProfile(user)),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile(UserModel user) async {
    if (_nameController.text.isEmpty) {
      HapiSnackbar.showError(context, 'Please enter your name');
      return;
    }
    if (selectedGender.isEmpty) {
      HapiSnackbar.showError(context, 'Please select your gender');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.id).set({
        'name': _nameController.text,
        'gender': selectedGender,
        'email': user.email,
        'photoUrl': user.photoUrl,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update userProvider
      ref
          .read(userProvider.notifier)
          .updateUser(
            name: _nameController.text,
            gender: selectedGender,
            id: user.id,
            email: user.email,
            photoUrl: user.photoUrl,
          );

      // Navigate to home
      ref.read(navigationProvider.notifier).goToHome();
    } catch (e) {
      HapiSnackbar.showError(context, 'Error saving profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildProfileImage(UserModel user) {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                ? NetworkImage(user.photoUrl!)
                : null,
            child: user.photoUrl == null || user.photoUrl!.isEmpty
                ? const Icon(Icons.person, size: 50, color: Colors.grey)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF1DE9B6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _genderOption(String label, IconData icon) {
    bool isSelected = selectedGender == label;
    return GestureDetector(
      onTap: () => setState(() => selectedGender = label),
      child: Column(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: isSelected
                ? const Color(0xFF1DE9B6).withOpacity(0.2)
                : Colors.grey[100],
            child: Icon(
              icon,
              size: 40,
              color: isSelected ? const Color(0xFF1DE9B6) : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: isSelected ? Colors.black : Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.location_on, color: Colors.black54),
          SizedBox(width: 12),
          Text("🇧🇩 ", style: TextStyle(fontSize: 18)),
          Expanded(
            child: Text(
              "Bangladesh",
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.black54),
        ],
      ),
    );
  }
}
