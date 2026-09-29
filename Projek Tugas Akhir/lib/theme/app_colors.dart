import 'package:flutter/material.dart';

class AppColors {
  // ================= WARNA BRAND =================
  static const Color primary = Color(0xFF0D47A1); // Blue 900
  static const Color secondary = Color(0xFF1565C0); // Blue 800
  static const Color tertiary = Color(0xFF1976D2); // Blue 700
  static const Color accent = Color(0xFF42A5F5); // Blue 400

  // ================= BAYANGAN =================
  static final Color blue50 = Colors.blue.shade50;
  static final Color blue100 = Colors.blue.shade100;
  static final Color blue200 = Colors.blue.shade200;
  static final Color blue400 = Colors.blue.shade400;

  // ================= WARNA TANDA =================
  static const Color success = Colors.green;
  static const Color error = Colors.red;
  static const Color warning = Colors.amber;
  // Dipergelap dari Colors.grey (shade 400-ish) ke Grey 700 untuk kontras lebih baik
  static const Color disabled = Color(0xFF616161);

  // ================= TEKS & ICON =================
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color black87 = Colors.black87;
  static final Color iconDefault = primary;

  // ================= LATAR BELAKANG =================
  static final Color backgroundLight = Colors.blue.shade50;
  static final Color cardBackground = Colors.white;
  static final Color greyBackground = Colors.grey.shade100;
  static final Color disabledBackground = Colors.grey.shade300;
}
