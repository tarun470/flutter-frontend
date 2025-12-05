import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NeonChatApp());
}

class NeonChatApp extends StatelessWidget {
  const NeonChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon Chat',
      debugShowCheckedModeBanner: false,

      // =======================================
      // 🌐 GLOBAL THEME
      // =======================================
      theme: _neonTheme(),

      // =======================================
      // 🚀 SMOOTH PAGE TRANSITION (Fade)
      // =======================================
      onGenerateRoute: (settings) {
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, anim, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: anim,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
        );
      },
    );
  }

  // =======================================
  // 🎨 NEON THEME DATA
  // =======================================
  ThemeData _neonTheme() {
    return ThemeData.dark().copyWith(

      // Colors
      scaffoldBackgroundColor: const Color(0xFF02050A),
      primaryColor: const Color(0xFF00FEE0),
      hintColor: const Color(0xFF7A7F9A),

      // Neon Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00FEE0),   // Neon Cyan
        secondary: Color(0xFFFF00FF), // Neon Magenta
        surface: Color(0xFF0A0F1F),   // Dark Panel
      ),

      // Typography
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

      // Input decoration style (global)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: TextStyle(
          color: Colors.white60,
          shadows: [
            Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 2),
          ],
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00FEE0), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF00FF), width: 1.6),
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FEE0),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          shadowColor: const Color(0xFF00FEE0),
        ),
      ),

      // Bottom Sheets
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color(0xFF0A0F1F).withOpacity(0.95),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF00FEE0),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }
}

