import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF4F7F2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFEAF1E7);
  static const ink = Color(0xFF18231F);
  static const muted = Color(0xFF66736D);
  static const border = Color(0x1A18231F);
  static const primary = Color(0xFF2563EB);
  static const teal = Color(0xFF0F766E);
  static const amber = Color(0xFFF59E0B);
  static const coral = Color(0xFFF97316);
  static const danger = Color(0xFFE11D48);
}

class AppRadii {
  static const card = 8.0;
  static const control = 8.0;
}

TextStyle headerstyle = const TextStyle(
  fontWeight: FontWeight.bold,
  color: Colors.white,
  fontSize: 24,
);
TextStyle headerstyleblack = const TextStyle(
  fontWeight: FontWeight.bold,
  color: AppColors.ink,
  fontSize: 24,
);

TextStyle subheader = const TextStyle(color: Colors.white, fontSize: 17);

Color backgroundcolor = AppColors.background;

Color appbarcolor = AppColors.primary;

Color primary_color = AppColors.primary;
