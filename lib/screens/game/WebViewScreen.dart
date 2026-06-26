import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hapi/widgets/custom/hapi_dialog.dart';

class GameWebViewScreen extends StatefulWidget {
  final String gameName;
  final String gameUrl;

  const GameWebViewScreen({
    super.key,
    required this.gameName,
    required this.gameUrl,
  });

  @override
  State<GameWebViewScreen> createState() => _GameWebViewScreenState();
}

class _GameWebViewScreenState extends State<GameWebViewScreen> {
  late final WebViewController _controller;
  bool isLoading = true;
  bool isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _checkFirstLoad();
    _initWebView();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _checkFirstLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'game_loaded_${widget.gameUrl.hashCode}';
    isFirstLoad = !(prefs.getBool(key) ?? false);
  }

  Future<void> _markAsLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'game_loaded_${widget.gameUrl.hashCode}';
    await prefs.setBool(key, true);
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => isLoading = true),
          onPageFinished: (url) async {
            setState(() => isLoading = false);
            if (isFirstLoad) await _markAsLoaded();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.gameUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (isLoading) _buildLoadingOverlay(),
          _buildCloseButton(),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            isFirstLoad
                ? 'Loading game...\nFirst time may take a moment'
                : 'Loading...',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: 40,
      left: 10,
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white, size: 30),
        onPressed: _showExitDialog,
      ),
    );
  }

  void _showExitDialog() {
    HapiDialog.showConfirm(
      context: context,
      title: 'Exit Game',
      message: 'Are you sure you want to exit?',
      confirmText: 'Exit',
      cancelText: 'Cancel',
    ).then((shouldExit) {
      if (shouldExit == true) {
        Navigator.pop(context);
      }
    });
  }
}
