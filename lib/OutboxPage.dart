import 'package:flutter/material.dart';

import 'services/connectivity_service.dart';
import 'services/offline_outbox_service.dart';

class OutboxPage extends StatelessWidget {
  const OutboxPage({super.key});

  static const String routeName = '/outbox';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de sincronizacion'),
        actions: [
          IconButton(
            tooltip: 'Reintentar todo',
            onPressed: () async {
              await OfflineOutboxService.instance.processPending();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reintento global ejecutado.')),
              );
            },
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: ConnectivityService.instance.isOffline,
        builder: (context, offline, _) {
          return ValueListenableBuilder<List<OutboxItem>>(
            valueListenable: OfflineOutboxService.instance.items,
            builder: (context, items, __) {
              if (items.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay operaciones pendientes en la cola local.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: offline
                          ? Colors.orange.withOpacity(0.10)
                          : Colors.blue.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      offline
                          ? 'Sin internet. Puedes revisar o descartar operaciones; el reintento sera al reconectar.'
                          : 'Con internet activo. Puedes reintentar operaciones pendientes manualmente.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...items.map((item) {
                    final created = item.createdAtDate;
                    final createdLabel =
                        '${created.day}/${created.month}/${created.year} ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
                    final retry = item.nextRetryAtDate;
                    final retryLabel =
                        '${retry.day}/${retry.month}/${retry.year} ${retry.hour.toString().padLeft(2, '0')}:${retry.minute.toString().padLeft(2, '0')}';
                    final reachedMaxAttempts = item.attempts >= 8;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.attempts > 0
                                        ? Colors.red.withOpacity(0.12)
                                        : Colors.orange.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    reachedMaxAttempts
                                        ? 'Pausado x${item.attempts}'
                                        : (item.attempts > 0
                                            ? 'Error x${item.attempts}'
                                            : 'Pendiente'),
                                    style: TextStyle(
                                      color: reachedMaxAttempts
                                          ? Colors.grey.shade800
                                          : (item.attempts > 0
                                              ? Colors.red.shade800
                                              : Colors.orange.shade800),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (item.subtitle.isNotEmpty) Text(item.subtitle),
                            const SizedBox(height: 4),
                            Text(
                              'Creado: $createdLabel',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            if ((item.lastError ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Ultimo error: ${item.lastError}',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (!reachedMaxAttempts &&
                                item.waitingForRetry) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Proximo reintento automatico: $retryLabel',
                                style: TextStyle(
                                  color: Colors.blueGrey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (reachedMaxAttempts) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Se alcanzo el maximo de intentos automaticos. Reintenta manualmente o descarta.',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: offline
                                      ? null
                                      : () async {
                                          await OfflineOutboxService.instance
                                              .processItemById(item.id);
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Reintento ejecutado.'),
                                            ),
                                          );
                                        },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reintentar'),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    await OfflineOutboxService.instance
                                        .removeItemById(item.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Operacion descartada.'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Descartar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: ValueListenableBuilder<List<OutboxItem>>(
        valueListenable: OfflineOutboxService.instance.items,
        builder: (context, items, _) {
          if (items.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Limpiar cola'),
                  content: const Text(
                    'Esto descartara todas las operaciones pendientes.\n\nDeseas continuar?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Limpiar'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              await OfflineOutboxService.instance.clearAll();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cola local limpiada.')),
              );
            },
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('Limpiar cola'),
          );
        },
      ),
    );
  }
}
