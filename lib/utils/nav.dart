import 'package:flutter/material.dart';
import '../menu.dart';

void goHomeAndClear(BuildContext ctx) {
  Navigator.of(ctx).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => MenuPage()),
    (route) => false,
  );
}
