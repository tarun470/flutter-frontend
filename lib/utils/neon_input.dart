import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

InputDecoration neonInputDecoration(
  String label, {
  IconData? prefixIcon,
  IconData? suffixIcon,
  VoidCallback? onSuffixTap,
  String? hintText,
}) {
  final glowPrimary = Constants.primary.withOpacity(0.70);
  final glowAccent = Constants.accent.withOpacity(0.70);

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    hintText: hintText,
    hintStyle: TextStyle(
      color: Colors.white70,
      fontSize: 14,
      shadows: kIsWeb
          ? [] // No shadow blur on web (keeps clean UI)
          : [
              Shadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 6,
              )
            ],
    ),
    labelStyle: TextStyle(
      color: Constants.primary,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(color: glowAccent, blurRadius: 8),
        Shadow(color: glowPrimary, blurRadius: 14),
      ],
    ),

    // Neon borders
    enabledBorder: _border(Constants.primary, 2),
    focusedBorder: _border(Constants.accent, 3),
    errorBorder: _border(Colors.redAccent, 2),
    focusedErrorBorder: _border(Colors.redAccent, 3),

    filled: true,
    fillColor: Colors.black.withOpacity(0.30),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),

    prefixIcon: prefixIcon != null
        ? Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 4),
            child: Icon(prefixIcon, color: Constants.primary),
          )
        : null,

    suffixIcon: suffixIcon != null
        ? GestureDetector(
            onTap: onSuffixTap,
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Icon(suffixIcon, color: Constants.primary),
            ),
          )
        : null,
  );
}
