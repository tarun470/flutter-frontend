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

  // ---------------------- LOGIN LOGIC ----------------------
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
      _showError("Invalid username or password");
      return;
    }

    final token = res["token"];
    final userId = res["userId"];
    final uname = res["username"] ?? username;

    if (token == null || userId == null) {
      _showError("Login failed. Invalid server response.");
      return;
    }

    await storage.saveToken(token);
    await storage.saveUserId(userId);
    await storage.saveUsername(uname);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
              child: _buildLoginCard(),
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
            Color(0xFF00172B),
            Color(0xFF000E1A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  // ---------------------- LOGIN CARD ----------------------
  Widget _buildLoginCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.4),
            blurRadius: 25,
            spreadRadius: 1,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTitle(),
          const SizedBox(height: 30),
          _buildInput(usernameCtrl, "Username", Icons.person),
          const SizedBox(height: 16),
          _buildInput(passwordCtrl, "Password", Icons.lock, obscure: true),
          const SizedBox(height: 28),
          _buildLoginButton(),
          const SizedBox(height: 16),
          _buildRegisterLink(),
        ],
      ),
    );
  }

  // ---------------------- TITLE ----------------------
  Widget _buildTitle() {
    return Column(
      children: const [
        Text(
          "REAL TIME CHAT",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
            shadows: [
              Shadow(
                color: Colors.blueAccent,
                blurRadius: 25,
              ),
            ],
          ),
        ),
        SizedBox(height: 6),
        Text(
          "Welcome back 🔥",
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
      ],
    );
  }

  // ---------------------- INPUT FIELD ----------------------
  Widget _buildInput(
      TextEditingController controller, String hint, IconData icon,
      {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black.withOpacity(0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
    );
  }

  // ---------------------- LOGIN BUTTON ----------------------
  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: loading ? null : login,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 10,
        shadowColor: Colors.blueAccent,
      ),
      child: const Text(
        "LOGIN",
        style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
        "Don't have an account? Create one",
        style: TextStyle(color: Colors.white70, fontSize: 14),
      ),
    );
  }

  // ---------------------- LOADING OVERLAY ----------------------
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      ),
    );
  }
}
