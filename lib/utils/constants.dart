import 'package:flutter/material.dart';

class Constants {
  static const bool isLocal = false;

  // API BASE URL
  static String get apiUrl =>
      isLocal ? "http://localhost:5000/api" : "https://chat-backend-mnz7.onrender.com/api";

  // SOCKET URL
  static String get socketUrl =>
      isLocal ? "http://localhost:5000" : "https://chat-backend-mnz7.onrender.com";

  static const Color primary = Color(0xFF00FFF0);
  static const Color accent = Color(0xFFFF00FF);
  static final Color background = Colors.black;
}
