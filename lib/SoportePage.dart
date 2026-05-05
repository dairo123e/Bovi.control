import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/app_config.dart';
import 'config/design_tokens.dart';
import 'services/offline_outbox_service.dart';
import 'widgets/ui/app_background.dart';
import 'widgets/ui/empty_state_card.dart';
import 'widgets/ui/section_title.dart';

class SoportePage extends StatefulWidget {
  const SoportePage({super.key});

  @override
  State<SoportePage> createState() => _SoportePageState();
}

class _SoportePageState extends State<SoportePage> {
  final _formKey = GlobalKey<FormState>();
  final _asuntoCtrl = TextEditingController();
  final _detalleCtrl = TextEditingController();
  final _buscarCtrl = TextEditingController();
  String _prioridad = 'media';
  bool _enviando = false;
  int _pagina = 0;
  static const int _itemsPorPagina = 6;

  CollectionReference<Map<String, dynamic>> get _ticketsRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('support_tickets');

  @override
  void dispose() {
    _asuntoCtrl.dispose();
    _detalleCtrl.dispose();
    _buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> _crearTicket(User user) async {
    if (_enviando) return;
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _enviando = true);
    try {
      final opId =
          'ticket_${user.uid}_${DateTime.now().microsecondsSinceEpoch}';
      await _ticketsRef.doc(opId).set({
        'asunto': _asuntoCtrl.text.trim(),
        'detalle': _detalleCtrl.text.trim(),
        'prioridad': _prioridad,
        'estado': 'abierto',
        'creadoPor': user.uid,
        'creadoPorEmail': user.email ?? '',
        'sourceOperationId': opId,
        'updatedAt': FieldValue.serverTimestamp(),
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _asuntoCtrl.clear();
      _detalleCtrl.clear();
      setState(() => _prioridad = 'media');
      _snack('Ticket enviado correctamente.');
    } catch (e) {
      await OfflineOutboxService.instance.enqueueSupportTicketCreate(
        uid: user.uid,
        email: user.email ?? '',
        asunto: _asuntoCtrl.text.trim(),
        detalle: _detalleCtrl.text.trim(),
        prioridad: _prioridad,
      );
      _asuntoCtrl.clear();
      _detalleCtrl.clear();
      setState(() => _prioridad = 'media');
      _snack('Ticket guardado localmente. Se sincronizara al reconectar.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _copiarContacto(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    _snack('$label copiado al portapapeles.');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _editarTicket(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? <String, dynamic>{};
    final asuntoCtrl =
        TextEditingController(text: (data['asunto'] ?? '').toString());
    final detalleCtrl =
        TextEditingController(text: (data['detalle'] ?? '').toString());
    String prioridad = (data['prioridad'] ?? 'media').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Editar ticket'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: asuntoCtrl,
                  decoration: const InputDecoration(labelText: 'Asunto'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detalleCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Detalle'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: prioridad,
                  items: const [
                    DropdownMenuItem(value: 'alta', child: Text('alta')),
                    DropdownMenuItem(value: 'media', child: Text('media')),
                    DropdownMenuItem(value: 'baja', child: Text('baja')),
                  ],
                  onChanged: (v) => setLocal(() => prioridad = v ?? 'media'),
                  decoration: const InputDecoration(labelText: 'Prioridad'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    try {
      await doc.reference.set({
        'asunto': asuntoCtrl.text.trim(),
        'detalle': detalleCtrl.text.trim(),
        'prioridad': prioridad,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack('Ticket actualizado.');
    } catch (_) {
      await OfflineOutboxService.instance.enqueueSupportTicketUpdate(
        ticketId: doc.id,
        asunto: asuntoCtrl.text.trim(),
        detalle: detalleCtrl.text.trim(),
        prioridad: prioridad,
      );
      _snack('Actualizacion guardada localmente. Se sincronizara.');
    } finally {
      asuntoCtrl.dispose();
      detalleCtrl.dispose();
    }
  }

  Future<void> _eliminarTicket(
      DocumentReference<Map<String, dynamic>> ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar ticket'),
        content: const Text('¿Deseas eliminar este ticket?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await ref.delete();
      _snack('Ticket eliminado.');
    } catch (_) {
      await OfflineOutboxService.instance.enqueueSupportTicketDelete(
        ticketId: ref.id,
      );
      _snack('Eliminacion guardada localmente. Se sincronizara.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesion para usar soporte.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacto y Soporte'),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const Text(
              'Soporte operativo',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea un ticket y haz seguimiento de su estado. Tambien puedes copiar los contactos de soporte.',
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.email_outlined,
                        color: AppColors.brandLeaf,
                      ),
                      title: const Text('Correo soporte'),
                      subtitle: const Text('dairoquintana023@gmail.com'),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copiarContacto(
                          'dairoquintana023@gmail.com',
                          'Correo',
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.phone_outlined,
                        color: AppColors.brandLeaf,
                      ),
                      title: const Text('Telefono principal'),
                      subtitle: const Text('+57 321 3250 580'),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () =>
                            _copiarContacto('+57 321 3250 580', 'Telefono'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(text: 'Crear ticket'),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _asuntoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Asunto',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresa un asunto'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _detalleCtrl,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Detalle',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresa el detalle'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _prioridad,
                        items: const [
                          DropdownMenuItem(value: 'alta', child: Text('alta')),
                          DropdownMenuItem(
                              value: 'media', child: Text('media')),
                          DropdownMenuItem(value: 'baja', child: Text('baja')),
                        ],
                        onChanged: (v) =>
                            setState(() => _prioridad = v ?? 'media'),
                        decoration: const InputDecoration(
                          labelText: 'Prioridad',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _enviando ? null : () => _crearTicket(user),
                          icon: _enviando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label:
                              Text(_enviando ? 'Enviando...' : 'Enviar ticket'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle(text: 'Seguimiento de tickets'),
            const SizedBox(height: 8),
            TextField(
              controller: _buscarCtrl,
              decoration: const InputDecoration(
                labelText: 'Buscar por asunto, estado o prioridad',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() => _pagina = 0),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _ticketsRef
                  .where('creadoPor', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Text('Error cargando tickets: ${snap.error}');
                }

                final docs = (snap.data?.docs ?? []).toList();
                final query = _buscarCtrl.text.trim().toLowerCase();
                docs.sort((a, b) {
                  final aDate = (a.data()['creadoEn'] as Timestamp?)?.toDate();
                  final bDate = (b.data()['creadoEn'] as Timestamp?)?.toDate();
                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return bDate.compareTo(aDate);
                });

                final filtrados = query.isEmpty
                    ? docs
                    : docs.where((d) {
                        final t = d.data();
                        final asunto =
                            (t['asunto'] ?? '').toString().toLowerCase();
                        final estado =
                            (t['estado'] ?? '').toString().toLowerCase();
                        final prioridad =
                            (t['prioridad'] ?? '').toString().toLowerCase();
                        return asunto.contains(query) ||
                            estado.contains(query) ||
                            prioridad.contains(query);
                      }).toList();

                if (filtrados.isEmpty) {
                  return const EmptyStateCard(
                    message: 'Aun no has creado tickets de soporte.',
                  );
                }

                final totalPaginas =
                    (filtrados.length / _itemsPorPagina).ceil();
                final paginaActual =
                    _pagina.clamp(0, (totalPaginas - 1).clamp(0, 99999));
                final inicio = paginaActual * _itemsPorPagina;
                final fin = (inicio + _itemsPorPagina > filtrados.length)
                    ? filtrados.length
                    : (inicio + _itemsPorPagina);
                final pageDocs = filtrados.sublist(inicio, fin);

                return Column(
                  children: [
                    Row(
                      children: [
                        Text(
                            'Mostrando ${inicio + 1}-$fin de ${filtrados.length}'),
                        const Spacer(),
                        IconButton(
                          onPressed: paginaActual > 0
                              ? () => setState(() => _pagina = paginaActual - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('${paginaActual + 1}/$totalPaginas'),
                        IconButton(
                          onPressed: paginaActual < totalPaginas - 1
                              ? () => setState(() => _pagina = paginaActual + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    ...pageDocs.map((d) {
                      final data = d.data();
                      final estado = (data['estado'] ?? 'abierto').toString();
                      final prioridad =
                          (data['prioridad'] ?? 'media').toString();
                      final creadoEn =
                          (data['creadoEn'] as Timestamp?)?.toDate();

                      Color stateColor = Colors.blue;
                      if (estado == 'en_proceso') stateColor = Colors.orange;
                      if (estado == 'cerrado') stateColor = Colors.green;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Icon(Icons.support_agent, color: stateColor),
                          title: Text((data['asunto'] ?? 'Ticket').toString()),
                          subtitle: Text(
                            'Estado: $estado | Prioridad: $prioridad\nFecha: ${_fmtFecha(creadoEn)}\n${(data['detalle'] ?? '').toString()}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editarTicket(d),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.red.shade700,
                                onPressed: () => _eliminarTicket(d.reference),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtFecha(DateTime? d) {
    if (d == null) return 'Sin fecha';
    return '${d.day}/${d.month}/${d.year}';
  }
}
