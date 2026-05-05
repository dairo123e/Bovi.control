import 'package:flutter/material.dart';

class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({
    super.key,
    required this.hasPendingWrites,
    required this.isFromCache,
  });

  final bool hasPendingWrites;
  final bool isFromCache;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    Color bg;
    Color fg;
    IconData icon;
    String label;

    if (hasPendingWrites) {
      bg = Colors.orange.shade100;
      fg = Colors.orange.shade900;
      icon = Icons.sync_problem_outlined;
      label = 'Pendiente';
    } else if (isFromCache) {
      bg = Colors.blue.shade100;
      fg = Colors.blue.shade900;
      icon = Icons.cloud_off_outlined;
      label = 'Cache';
    } else {
      bg = scheme.primary.withOpacity(0.12);
      fg = scheme.primary;
      icon = Icons.cloud_done_outlined;
      label = 'Sync';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class SyncSummaryCard extends StatelessWidget {
  const SyncSummaryCard({
    super.key,
    required this.pendingCount,
    required this.isFromCache,
  });

  final int pendingCount;
  final bool isFromCache;

  @override
  Widget build(BuildContext context) {
    final bool hasPending = pendingCount > 0;
    final Color tone = hasPending
        ? Colors.orange.shade800
        : (isFromCache ? Colors.blue.shade800 : Colors.green.shade800);

    final String message = hasPending
        ? '$pendingCount cambio(s) pendiente(s) de sincronizar.'
        : (isFromCache
            ? 'Mostrando datos desde cache local.'
            : 'Datos sincronizados con el servidor.');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            hasPending
                ? Icons.sync_problem_outlined
                : (isFromCache ? Icons.cloud_off_outlined : Icons.cloud_done),
            color: tone,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: tone, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
