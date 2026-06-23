import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hapi/providers/auth_provider.dart';
import 'package:hapi/widgets/custom/hapi_button.dart';
import 'package:hapi/widgets/custom/hapi_snackbar.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo Section
              _buildLogo(),

              const Spacer(flex: 3),

              // ✅ Guest Login Button
              const SizedBox(height: 16),

              // Social Login Buttons
              HapiButton(
                text: 'Facebook',
                onPressed: () {
                  HapiSnackbar.showInfo(context, 'Facebook login disabled');
                },
                icon: Icons.facebook,
                backgroundColor: const Color(0xFF1877F2),
                isOutlined: true,
              ),

              const SizedBox(height: 16),

              HapiButton(
                text: 'Google',
                onPressed: () =>
                    ref.read(authProvider.notifier).signInWithGoogle(),
                icon: Icons.g_mobiledata_rounded,
                backgroundColor: Colors.red,
                isOutlined: true,
              ),

              const SizedBox(height: 24),
              HapiButton(
                text: 'Continue as Guest',
                onPressed: () =>
                    ref.read(authProvider.notifier).signInAsGuest(),
                icon: Icons.person_outline,
                backgroundColor: const Color.fromARGB(255, 217, 79, 79),
                isOutlined: false,
              ),
              SizedBox(height: 20),

              const Text(
                'Or log in with',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 16),

              // Phone Authentication Option
              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(Icons.smartphone, color: Colors.black87),
                ),
              ),

              const Spacer(flex: 2),

              // Footer Legal Text
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          height: 100,
          width: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF42E695), Color(0xFF3BB2B8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/logo.png',
                height: 60,
                width: 60,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.sentiment_very_satisfied,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hapi',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          const Text(
            'Log In means you agree to ',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          GestureDetector(
            onTap: () {},
            child: Text(
              'Term of Service',
              style: TextStyle(
                color: Colors.teal[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Text(', ', style: TextStyle(color: Colors.grey, fontSize: 12)),
          GestureDetector(
            onTap: () {},
            child: Text(
              'Privacy Policy',
              style: TextStyle(
                color: Colors.teal[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
