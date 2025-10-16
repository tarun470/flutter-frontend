import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const NeonChatApp());
}

class NeonChatApp extends StatelessWidget {
  const NeonChatApp({Key? key}) : super(key: key); // Add const constructor

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFF00FFF0),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00FFF0),
          secondary: const Color(0xFFFF00FF), // accent color replacement
        ),
      ),
      home: const LoginScreen(), // Use const
    );
  }
}
