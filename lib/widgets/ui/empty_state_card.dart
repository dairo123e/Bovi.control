import 'package:flutter/material.dart';

class EmptyStateCard extends StatelessWidget {
  final String message;

  const EmptyStateCard({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(message),
      ),
    );
  }
}
