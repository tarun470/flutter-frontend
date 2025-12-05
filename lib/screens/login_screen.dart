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
  bool showPassword = false;

  // ---------------------- LOGIN LOGIC ----------------------
  Future<void> login() async {
    final username = usernameCtrl.text.trim().toLowerCase();
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
    final user = res["user"];

    if (token == null || user == null) {
      _showError("Unexpected server error");
      return;
    }

    await storage.saveToken(token);
    await storage.saveUserId(user.id);
    await storage.saveUsername(user.nickname);

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

  // ---------------------- GLASS CARD ----------------------
  Widget _buildGlassLoginCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.3),
            blurRadius: 28,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTitle(),
          const SizedBox(height: 28),
          _buildInput(usernameCtrl, "Username", Icons.person),
          const SizedBox(height: 16),
          _buildPasswordInput(),
          const SizedBox(height: 26),
          _buildLoginButton(),
          const SizedBox(height: 14),
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
                color: Colors.blueAccent.withOpacity(0.8),
                blurRadius: 28,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Welcome back 👋",
          style: TextStyle(color: Colors.white70, fontSize: 15),
        ),
      ],
    );
  }

  // ---------------------- TEXT INPUT ----------------------
  Widget _buildInput(
      TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black.withOpacity(0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ---------------------- PASSWORD INPUT WITH TOGGLE ----------------------
  Widget _buildPasswordInput() {
    return TextField(
      controller: passwordCtrl,
      obscureText: !showPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock, color: Colors.blueAccent),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.white70,
          ),
          onPressed: () => setState(() => showPassword = !showPassword),
        ),
        hintText: "Password",
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black.withOpacity(0.45),
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
          elevation: 10,
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
        "Don't have an account? Create one",
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
