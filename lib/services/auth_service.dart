import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Google Login - Returns UserCredential with photo URL
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      return userCredential;
    } catch (e) {
      print('Google sign in error: $e');
      return null;
    }
  }

  // ✅ SIGN IN AS GUEST
  Future<UserCredential?> signInAsGuest() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      print('Guest sign in error: $e');
      return null;
    }
  }

  // Logout
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Current user
  User? get currentUser => _auth.currentUser;

  // ✅ CHECK IF USER IS GUEST
  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;
}
