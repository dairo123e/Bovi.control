import 'package:flutter/material.dart';

void goHomeAndClear(BuildContext ctx) {
  Navigator.of(ctx).pushNamedAndRemoveUntil('/menu', (route) => false);
}
