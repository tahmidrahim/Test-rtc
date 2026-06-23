import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hapi/providers/navigation_provider.dart';
import 'package:hapi/providers/user_provider.dart';
import 'package:hapi/services/auth_service.dart';

// Define AuthState
class AuthState {
  final bool isLoading;
  final String? error;

  AuthState({this.isLoading = false, this.error});

  AuthState copyWith({bool? isLoading, String? error}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

// Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final AuthService _authService = AuthService();

  AuthNotifier(this._ref) : super(AuthState());

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true);

    try {
      final userCredential = await _authService.signInWithGoogle();

      if (userCredential?.user != null) {
        final user = userCredential!.user!;

        _ref
            .read(userProvider.notifier)
            .updateUser(
              name: user.displayName ?? '',
              gender: '',
              email: user.email ?? '',
              photoUrl: user.photoURL,
              id: user.uid,
            );

        _ref.read(navigationProvider.notifier).goToHome();
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ✅ SIGN IN AS GUEST
  Future<void> signInAsGuest() async {
    state = state.copyWith(isLoading: true);

    try {
      final userCredential = await _authService.signInAsGuest();

      if (userCredential?.user != null) {
        final user = userCredential!.user!;

        _ref
            .read(userProvider.notifier)
            .updateUser(
              name: 'Guest ${DateTime.now().millisecondsSinceEpoch}',
              gender: '',
              email: 'guest@hapi.app',
              photoUrl: null,
              id: user.uid,
            );

        _ref.read(navigationProvider.notifier).goToHome();
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _ref.read(navigationProvider.notifier).goToLogin();
  }
}
