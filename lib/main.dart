import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hapi/firebase_options.dart';
import 'package:hapi/providers/navigation_provider.dart';
import 'package:hapi/providers/user_provider.dart';
import 'package:hapi/screens/auth/auth_screen.dart';
import 'package:hapi/screens/auth/complete_profile_screen.dart';
import 'package:hapi/screens/call/edit_room_name_dialog.dart';
import 'package:hapi/screens/home/home_screen.dart';
import 'package:hapi/screens/call/voice_room_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void _checkAuthState() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        // Check Firestore for saved profile data
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final savedName = doc.data()?['name'] ?? user.displayName ?? '';
        final savedGender = doc.data()?['gender'] ?? '';
        final profileCompleted = doc.data()?['profileCompleted'] == true;

        final userModel = UserModel(
          id: user.uid,
          name: savedName,
          email: user.email ?? '',
          photoUrl: user.photoURL,
          gender: savedGender,
        );

        ref
            .read(userProvider.notifier)
            .updateUser(
              name: userModel.name,
              gender: userModel.gender,
              id: userModel.id,
              email: userModel.email,
              photoUrl: userModel.photoUrl,
            );

        if (profileCompleted && savedGender.isNotEmpty) {
          ref.read(navigationProvider.notifier).goToHome();
        } else {
          ref.read(navigationProvider.notifier).goToCompleteProfile();
        }
      } else {
        ref.read(navigationProvider.notifier).goToLogin();
      }
      setState(() => _isChecking = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(navigationProvider);
    final user = ref.watch(userProvider);

    if (_isChecking) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Hapi',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.white,
      ),
      debugShowCheckedModeBanner: false,
      home: _getScreen(route, user),
    );
  }

  Widget _getScreen(String route, UserModel user) {
    // Handle edit room name route
    if (route == '/edit-room-name') {
      return const EditRoomNameScreen();
    }

    // Handle voice-room routes
    if (route.startsWith('/voice-room')) {
      final uri = Uri.parse(route);
      final roomId = uri.queryParameters['roomId'] ?? '';
      final isCreating = uri.queryParameters['isCreating'] == 'true';
      return VoiceRoomScreen(roomId: roomId, isCreating: isCreating);
    }

    switch (route) {
      case '/login':
        return const AuthScreen();
      case '/complete-profile':
        return const CompleteProfileScreen();
      case '/home':
        return const HomeScreen();
      default:
        return const AuthScreen();
    }
  }
}
