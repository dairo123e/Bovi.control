import 'package:flutter/material.dart';

class AppColors {
  static const Color brandForest = Color(0xFF1E4E3E);
  static const Color brandLeaf = Color(0xFF5E9E64);
  static const Color brandMint = Color(0xFFDDF0E2);
  static const Color surfaceSoft = Color(0xFFF4F8F2);
  static const Color surfaceCard = Colors.white;
  static const Color textPrimary = Color(0xFF1C2B24);
  static const Color textMuted = Color(0xFF5A6A62);
  static const Color warning = Color(0xFFEAA33D);
  static const Color danger = Color(0xFFD85E5E);
}

class AppSpacing {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
}

class AppRadii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
}

class AppShadows {
  static List<BoxShadow> soft = const [
    BoxShadow(
      color: Color(0x1A1A2D24),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  static List<BoxShadow> subtle = const [
    BoxShadow(
      color: Color(0x121A2D24),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];
}
