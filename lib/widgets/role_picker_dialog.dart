import 'package:flutter/material.dart';

Future<String?> pickRoleDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => SimpleDialog(
      title: const Text('Selecciona tu rol'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'ganadero'),
          child: const Text('Ganadero'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'veterinario'),
          child: const Text('Veterinario'),
        ),
      ],
    ),
  );
}
