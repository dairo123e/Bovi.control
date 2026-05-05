import 'package:flutter/material.dart';

class MenuOption {
  final String title;
  final Color color;
  final Widget page;
  final IconData? icon;
  final String? assetPath;

  const MenuOption._({
    required this.title,
    required this.color,
    required this.page,
    this.icon,
    this.assetPath,
  });

  factory MenuOption.icon({
    required String title,
    required IconData icon,
    required Color color,
    required Widget page,
  }) {
    return MenuOption._(
      title: title,
      icon: icon,
      color: color,
      page: page,
    );
  }

  factory MenuOption.asset({
    required String title,
    required String assetPath,
    required Color color,
    required Widget page,
  }) {
    return MenuOption._(
      title: title,
      assetPath: assetPath,
      color: color,
      page: page,
    );
  }
}
