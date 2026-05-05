import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';

class SectionTitle extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry? margin;

  const SectionTitle({
    super.key,
    required this.text,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
