import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/secure_storage.dart';
import 'chat_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final storage = SecureStorageService();

  bool loading = false;

  // ---------------------- FIXED LOGIN LOGIC ----------------------
  Future<void> login() async {
    final username = usernameCtrl.text.trim();
    final password = passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError("Please enter both username and password");
      return;
    }

    setState(() => loading = true);

    final res = await ApiService.loginUser(username, password);

    setState(() => loading = false);

    if (res == null) {
      _showError("Server error or invalid credentials");
      return;
    }

    // Backend returns: { token, user: { id, username, nickname } }
    final token = res["token"];
    final user = res["user"];

    if (token == null || user == null) {
      _showError("Invalid server response");
      return;
    }

    final userId = user["id"];
    final uname = user["username"];
    final nickname = user["nickname"] ?? uname;

    await storage.saveToken(token);
    await storage.saveUserId(userId);
    await storage.saveUsername(nickname);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  // ---------------------- ERROR POPUP ----------------------
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      body: Stack(
        children: [
          _buildBackground(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _buildGlassLoginCard(),
            ),
          ),
          if (loading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // ---------------------- BACKGROUND ----------------------
  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF011627),
            Color(0xFF00101A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  // ---------------------- GLASSMORPHIC CARD ----------------------
  Widget _buildGlassLoginCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTitle(),
          const SizedBox(height: 32),
          _buildInput(usernameCtrl, "Username", Icons.person),
          const SizedBox(height: 18),
          _buildInput(passwordCtrl, "Password", Icons.lock, obscure: true),
          const SizedBox(height: 28),
          _buildLoginButton(),
          const SizedBox(height: 18),
          _buildRegisterLink(),
        ],
      ),
    );
  }

  // ---------------------- TITLE ----------------------
  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          "REAL TIME CHAT",
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent.shade100,
            shadows: [
              Shadow(
                color: Colors.blueAccent.withOpacity(0.9),
                blurRadius: 30,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Welcome back 👋",
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  // ---------------------- INPUT FIELD ----------------------
  Widget _buildInput(TextEditingController ctrl, String hint, IconData icon,
      {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ---------------------- LOGIN BUTTON ----------------------
  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 12,
        ),
        child: const Text(
          "LOGIN",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ---------------------- REGISTER LINK ----------------------
  Widget _buildRegisterLink() {
    return TextButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      ),
      child: const Text(
        "Don't have an account? Sign up",
        style: TextStyle(color: Colors.white70, fontSize: 15),
      ),
    );
  }

  // ---------------------- LOADING OVERLAY ----------------------
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      ),
    );
  }
}
