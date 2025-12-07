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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final storage = SecureStorageService();

  bool loading = false;
  bool showPassword = false;

  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------
  // LOGIN LOGIC
  // --------------------------------------------------------
  Future<void> login() async {
    final username = usernameCtrl.text.trim().toLowerCase();
    final password = passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError("Please enter both username and password");
      return;
    }

    setState(() => loading = true);

    try {
      final res = await ApiService.loginUser(username, password);

      if (!mounted) return;

      setState(() => loading = false);

      if (res == null) {
        _showError("Invalid username or password");
        return;
      }

      final token = res["token"];
      final user = res["user"]; // User model from backend

      if (token == null || user == null) {
        _showError("Unexpected server error");
        return;
      }

      await storage.saveToken(token);
      await storage.saveUserId(user.id);
      await storage.saveUsername(user.nickname ?? user.username);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _showError("Something went wrong. Please try again.");
    }
  }

  // --------------------------------------------------------
  // ERROR SNACKBAR
  // --------------------------------------------------------
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent.shade200,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      body: Stack(
        children: [
          _buildBackground(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: _buildGlassLoginCard(),
                ),
              ),
            ),
          ),
          if (loading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // CUSTOM THEME BACKGROUND (CUSTOM OPTION #5)
  // --------------------------------------------------------
  Widget _buildBackground() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF040C1C),
                Color(0xFF050816),
                Color(0xFF030712),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Soft radial highlights
        Positioned(
          top: -80,
          right: -40,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF38BDF8).withOpacity(0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -50,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFA855F7).withOpacity(0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------
  // GLASS EFFECT CARD
  // --------------------------------------------------------
  Widget _buildGlassLoginCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: const Color(0xFF38BDF8).withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLogoHeader(),
          const SizedBox(height: 24),
          _buildInput(usernameCtrl, "Username", Icons.person_outline),
          const SizedBox(height: 16),
          _buildPasswordInput(),
          const SizedBox(height: 20),
          _buildLoginButton(),
          const SizedBox(height: 12),
          _buildRegisterLink(),
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // LOGO + TITLE
  // --------------------------------------------------------
  Widget _buildLogoHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFF38BDF8),
                Color(0xFFA855F7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38BDF8).withOpacity(0.55),
                blurRadius: 26,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          "Realtime Chat",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Log in to continue the conversation",
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------
  // TEXT INPUT
  // --------------------------------------------------------
  Widget _buildInput(
      TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      cursorColor: const Color(0xFF38BDF8),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF38BDF8)),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.14),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFF38BDF8),
            width: 1.4,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------
  // PASSWORD INPUT WITH TOGGLE
  // --------------------------------------------------------
  Widget _buildPasswordInput() {
    return TextField(
      controller: passwordCtrl,
      obscureText: !showPassword,
      style: const TextStyle(color: Colors.white),
      cursorColor: const Color(0xFF38BDF8),
      decoration: InputDecoration(
        prefixIcon:
            const Icon(Icons.lock_outline_rounded, color: Color(0xFF38BDF8)),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.white.withOpacity(0.7),
          ),
          onPressed: () => setState(() => showPassword = !showPassword),
        ),
        hintText: "Password",
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.14),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFA855F7),
            width: 1.4,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------
  // LOGIN BUTTON
  // --------------------------------------------------------
  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF38BDF8),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 10,
          shadowColor: const Color(0xFF38BDF8).withOpacity(0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Continue",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: Colors.white.withOpacity(0.95),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------
  // REGISTER LINK
  // --------------------------------------------------------
  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "New here?",
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 13,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            );
          },
          child: const Text(
            "Create an account",
            style: TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------
  // LOADING OVERLAY
  // --------------------------------------------------------
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.45),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF38BDF8),
          strokeWidth: 3,
        ),
      ),
    );
  }
}


