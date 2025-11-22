import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/secure_storage.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final secureStorage = SecureStorageService();
  bool loading = false;
  bool passwordVisible = false;

  void register() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final nickname = nicknameController.text.trim();

    if (username.isEmpty || password.isEmpty || nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter username, password & nickname'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => loading = true);

    final response = await ApiService.register(
      username,
      password,
      nickname: nickname,
    );

    setState(() => loading = false);

    if (response != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Registered successfully! Please login, ${response['username']}.'), 
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ Registration failed. Try another username.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required TextEditingController controller,
    bool obscureText = false,
    IconData? icon,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.amberAccent, fontSize: 16),
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(icon, color: Colors.amberAccent)
                : null,
            suffixIcon: suffix,
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.amber[200]),
            filled: true,
            fillColor: Colors.black87,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.black87, Colors.black54],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.amberAccent.withOpacity(0.7),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🤝 REAL TIME CHAT 🤝',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    _buildTextField(
                      hint: 'Username',
                      controller: usernameController,
                      icon: Icons.person,
                    ),

                    _buildTextField(
                      hint: 'Nickname',
                      controller: nicknameController,
                      icon: Icons.edit,
                    ),

                    _buildTextField(
                      hint: 'Password',
                      controller: passwordController,
                      obscureText: !passwordVisible,
                      icon: Icons.lock,
                      suffix: IconButton(
                        icon: Icon(
                          passwordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.amberAccent,
                        ),
                        onPressed: () {
                          setState(() {
                            passwordVisible = !passwordVisible;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: loading ? null : register,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 100, vertical: 18),
                        backgroundColor: Colors.amber[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 8,
                        shadowColor: Colors.amberAccent,
                      ),
                      child: loading
                          ? const CircularProgressIndicator(
                              color: Colors.black,
                            )
                          : const Text(
                              'REGISTER',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        );
                      },
                      child: const Text(
                        'Already have an account? Login',
                        style: TextStyle(color: Colors.amberAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
