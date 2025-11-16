import 'package:flutter/material.dart';
import '../utils/constants.dart';

InputDecoration neonInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      color: Constants.primary,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          color: Constants.accent.withOpacity(0.7),
          blurRadius: 12,
          offset: const Offset(0, 0),
        ),
        Shadow(
          color: Constants.primary.withOpacity(0.5),
          blurRadius: 20,
          offset: const Offset(0, 0),
        ),
      ],
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Constants.primary, width: 2),
      borderRadius: BorderRadius.circular(16),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Constants.accent, width: 3),
      borderRadius: BorderRadius.circular(16),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.redAccent, width: 2),
      borderRadius: BorderRadius.circular(16),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.redAccent, width: 3),
      borderRadius: BorderRadius.circular(16),
    ),
    filled: true,
    fillColor: Colors.black.withOpacity(0.25),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    hintStyle: TextStyle(
      color: Colors.white70,
      shadows: [
        Shadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 4,
          offset: const Offset(1, 1),
        ),
      ],
    ),
  );
}
