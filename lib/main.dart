import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/chat_screen.dart';
import 'utils/secure_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NeonChatApp());
}

class NeonChatApp extends StatelessWidget {
  const NeonChatApp({super.key});

  Future<Widget> _startScreen() async {
    final storage = SecureStorageService();
    final token = await storage.getToken();
    final userId = await storage.getUserId();

    if (token != null && userId != null) {
      return const ChatScreen(); // User already logged in → go to chat
    } else {
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon Chat',
      debugShowCheckedModeBanner: false,
      theme: _neonTheme(),

      home: FutureBuilder(
        future: _startScreen(),
        builder: (ctx, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: Color(0xFF02050A),
              body: Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              ),
            );
          }
          return snapshot.data!;
        },
      ),
    );
  }

  ThemeData _neonTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF02050A),
      primaryColor: const Color(0xFF00FEE0),
      hintColor: const Color(0xFF7A7F9A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00FEE0),
        secondary: Color(0xFFFF00FF),
        surface: Color(0xFF0A0F1F),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
        bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
        bodySmall: TextStyle(color: Colors.white60, fontSize: 12),
        titleLarge: TextStyle(
          color: Color(0xFF00FEE0),
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: const TextStyle(color: Colors.white60),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00FEE0), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF00FF), width: 1.6),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Color(0xFF00FEE0),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }
}
