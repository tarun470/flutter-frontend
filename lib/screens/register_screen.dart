import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/secure_storage.dart';
import '../utils/constants.dart';
import '../utils/neon_input.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final usernameCtrl = TextEditingController();
  final nicknameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final storage = SecureStorageService();

  bool loading = false;
  bool showPassword = false;

  late AnimationController glowController;
  late Animation<double> glow;

  @override
  void initState() {
    super.initState();

    glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    glow = Tween<double>(begin: 0.4, end: 1.0).animate(glowController);
  }

  @override
  void dispose() {
    usernameCtrl.dispose();
    nicknameCtrl.dispose();
    passwordCtrl.dispose();
    glowController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------
  // REGISTER LOGIC (FIXED)
  // -------------------------------------------------------
  Future<void> register() async {
    final username = usernameCtrl.text.trim().toLowerCase();
    final nick = nicknameCtrl.text.trim();
    final pass = passwordCtrl.text.trim();

    if (username.isEmpty || nick.isEmpty || pass.isEmpty) {
      _error("Please fill all fields.");
      return;
    }

    if (pass.length < 6) {
      _error("Password must be at least 6 characters.");
      return;
    }

    setState(() => loading = true);

    final res = await ApiService.register(username, pass, nickname: nick);

    setState(() => loading = false);

    if (res != null) {
      final registeredUser = res['user'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "🎉 Account created for ${registeredUser.username}! Please log in.",
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      _error("Registration failed. Username might already exist.");
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // -------------------------------------------------------
  // UI
  // -------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _background(),
          Center(child: _formCard()),
          if (loading) _loadingOverlay(),
        ],
      ),
    );
  }

  // ---------------------- BACKGROUND ----------------------
  Widget _background() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF000F1C),
            Color(0xFF051A2C),
            Color(0xFF000A12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  // ---------------------- FORM CARD ----------------------
  Widget _formCard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: AnimatedBuilder(
        animation: glow,
        builder: (_, __) {
          return Container(
            width: 420,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.70),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Constants.primary.withOpacity(glow.value),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Constants.accent.withOpacity(glow.value * 0.6),
                  blurRadius: 25,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Column(
              children: [
                _title(),
                const SizedBox(height: 35),
                _input(usernameCtrl, "Username", AutofillHints.username),
                const SizedBox(height: 18),
                _input(nicknameCtrl, "Nickname", AutofillHints.name),
                const SizedBox(height: 18),
                _passwordField(),
                const SizedBox(height: 30),
                _registerButton(),
                const SizedBox(height: 14),
                _loginLink(),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------- TITLE ----------------------
  Widget _title() {
    return Column(
      children: [
        Text(
          "CREATE ACCOUNT",
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Constants.primary,
            shadows: [
              Shadow(
                color: Constants.accent.withOpacity(0.6),
                blurRadius: 25,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Join real-time chat ✨",
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
      ],
    );
  }

  // ---------------------- INPUT FIELD ----------------------
  Widget _input(TextEditingController ctrl, String label, String autofill) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      autofillHints: [autofill],
      decoration: neonInputDecoration(label),
    );
  }

  // ---------------------- PASSWORD FIELD ----------------------
  Widget _passwordField() {
    return TextField(
      controller: passwordCtrl,
      obscureText: !showPassword,
      style: const TextStyle(color: Colors.white),
      autofillHints: const [AutofillHints.password],
      decoration: neonInputDecoration("Password").copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            showPassword ? Icons.visibility : Icons.visibility_off,
            color: Constants.primary,
          ),
          onPressed: () => setState(() => showPassword = !showPassword),
        ),
      ),
    );
  }

  // ---------------------- REGISTER BUTTON ----------------------
  Widget _registerButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : register,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Constants.accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 12,
        ),
        child: const Text(
          "REGISTER",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ---------------------- LOGIN LINK ----------------------
  Widget _loginLink() {
    return TextButton(
      onPressed: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      ),
      child: Text(
        "Already have an account? Login",
        style: TextStyle(
          color: Constants.primary,
          fontSize: 14,
          shadows: [
            Shadow(
              color: Constants.primary.withOpacity(0.5),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------- LOADING OVERLAY ----------------------
  Widget _loadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      ),
    );
  }
}
