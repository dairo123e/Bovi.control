import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'services/offline_outbox_service.dart';
import 'widgets/ui/app_background.dart';
import 'widgets/ui/empty_state_card.dart';
import 'widgets/ui/section_title.dart';
import 'widgets/ui/sync_state_widgets.dart';

class MedicamentosPage extends StatefulWidget {
  const MedicamentosPage({super.key});

  @override
  State<MedicamentosPage> createState() => _MedicamentosPageState();
}

class _MedicamentosPageState extends State<MedicamentosPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _dosisCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _buscarCtrl = TextEditingController();

  String? _animalId;
  String? _animalNombre;
  DateTime _fechaAplicacion = DateTime.now();
  DateTime? _fechaProxima;
  bool _guardando = false;
  int _pagina = 0;
  static const int _itemsPorPagina = 6;

  void _ensureAnimalSeleccionada(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return;

    final existe = _animalId != null && docs.any((d) => d.id == _animalId);
    if (existe) return;

    final first = docs.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _animalId = first.id;
        _animalNombre = (first.data()['nombre'] ?? 'Sin nombre').toString();
      });
    });
  }

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('users');

  CollectionReference<Map<String, dynamic>> get _animalesRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('animales');

  CollectionReference<Map<String, dynamic>> get _medicamentosRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('medicamentos');

  CollectionReference<Map<String, dynamic>> get _tareasRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('tareas');

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dosisCtrl.dispose();
    _obsCtrl.dispose();
    _buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFechaAplicacion() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fechaAplicacion,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _fechaAplicacion = d);
    }
  }

  Future<void> _pickFechaProxima() async {
    final base =
        _fechaProxima ?? _fechaAplicacion.add(const Duration(days: 30));
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _fechaProxima = d);
    }
  }

  Future<void> _guardarMedicamento(User user, {required bool readOnly}) async {
    if (readOnly) {
      _snack('Tu rol es solo lectura para registrar medicamentos.');
      return;
    }
    if (_guardando) return;
    if (_formKey.currentState?.validate() != true) return;
    if (_animalId == null) {
      _snack('Selecciona una vaca.');
      return;
    }

    setState(() => _guardando = true);
    final opId = 'med_${user.uid}_${DateTime.now().microsecondsSinceEpoch}';
    try {
      String animalNombre = (_animalNombre ?? '').trim();
      if (animalNombre.isEmpty) {
        final animalDoc = await _animalesRef.doc(_animalId!).get();
        animalNombre = (animalDoc.data()?['nombre'] ?? 'Sin nombre').toString();
        _animalNombre = animalNombre;
      }

      final data = {
        'nombreMedicamento': _nombreCtrl.text.trim(),
        'dosis': _dosisCtrl.text.trim(),
        'observaciones': _obsCtrl.text.trim(),
        'animalId': _animalId,
        'animalNombre': animalNombre,
        'fechaAplicacion': Timestamp.fromDate(_fechaAplicacion),
        'fechaProxima':
            _fechaProxima == null ? null : Timestamp.fromDate(_fechaProxima!),
        'estado': 'activo',
        'creadoPor': user.uid,
        'sourceOperationId': opId,
        'updatedAt': FieldValue.serverTimestamp(),
        'creadoEn': FieldValue.serverTimestamp(),
      };

      await _medicamentosRef.doc(opId).set(data, SetOptions(merge: true));

      if (_fechaProxima != null) {
        await _tareasRef.doc('${opId}_task').set({
          'titulo': 'Aplicar ${_nombreCtrl.text.trim()} a $animalNombre',
          'descripcion':
              'Tarea automatica generada desde tratamientos. Dosis: ${_dosisCtrl.text.trim()}.',
          'fecha': Timestamp.fromDate(_fechaProxima!),
          'estado': 'pendiente',
          'prioridad': 'alta',
          'asignadoA': user.email ?? user.uid,
          'animalId': _animalId,
          'tipo': 'tratamiento',
          'creadoPor': user.uid,
          'sourceOperationId': opId,
          'updatedAt': FieldValue.serverTimestamp(),
          'creadoEn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _formKey.currentState?.reset();
      setState(() {
        _animalId = null;
        _animalNombre = null;
        _fechaAplicacion = DateTime.now();
        _fechaProxima = null;
      });
      _snack('Tratamiento guardado.');
    } catch (e) {
      await OfflineOutboxService.instance.enqueueMedicamentoCreate(
        uid: user.uid,
        userEmailOrUid: user.email ?? user.uid,
        nombreMedicamento: _nombreCtrl.text.trim(),
        dosis: _dosisCtrl.text.trim(),
        observaciones: _obsCtrl.text.trim(),
        animalId: _animalId!,
        animalNombre: (_animalNombre ?? 'Sin nombre').trim().isEmpty
            ? 'Sin nombre'
            : _animalNombre!.trim(),
        fechaAplicacionMillis: _fechaAplicacion.millisecondsSinceEpoch,
        fechaProximaMillis: _fechaProxima?.millisecondsSinceEpoch,
        operationId: opId,
      );

      _formKey.currentState?.reset();
      setState(() {
        _animalId = null;
        _animalNombre = null;
        _fechaAplicacion = DateTime.now();
        _fechaProxima = null;
      });
      _snack(
        'Sin red/servidor. Tratamiento en cola local para sincronizar.',
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _marcarCompletado(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      await ref.update({
        'estado': 'completado',
        'completadoEn': FieldValue.serverTimestamp(),
      });
      _snack('Tratamiento marcado como completado.');
    } catch (_) {
      await OfflineOutboxService.instance.enqueueMedicamentoComplete(
        medicamentoId: ref.id,
      );
      _snack('Actualizacion guardada localmente. Se sincronizara.');
    }
  }

  Future<void> _eliminarTratamiento(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      await ref.delete();
      _snack('Tratamiento eliminado.');
    } catch (_) {
      await OfflineOutboxService.instance.enqueueMedicamentoDelete(
        medicamentoId: ref.id,
      );
      _snack('Eliminacion guardada localmente. Se sincronizara.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Medicamentos')),
        body: const Center(child: Text('Debes iniciar sesion.')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _usersRef.doc(user.uid).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() ?? {};
        final roleRaw =
            (userData['role'] ?? userData['rol'] ?? 'ganadero').toString();
        final role = roleRaw.trim().toLowerCase();
        final readOnly = role == 'veterinario';

        return Scaffold(
          appBar: AppBar(
            title: Text('Medicamentos y tratamientos - $role'),
          ),
          body: AppBackground(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (readOnly)
                  Card(
                    color: Colors.amber.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Modo solo lectura: puedes revisar tratamientos, pero no crear ni editar.',
                      ),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle(text: 'Registrar tratamiento'),
                          const SizedBox(height: 10),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _animalesRef
                                .where('creadoPor', isEqualTo: user.uid)
                                .snapshots(),
                            builder: (context, snap) {
                              final docs = snap.data?.docs ?? [];
                              if (docs.isEmpty) {
                                return const Text(
                                  'No tienes vacas registradas para asignar tratamiento.',
                                );
                              }

                              _ensureAnimalSeleccionada(docs);
                              final selectedId =
                                  docs.any((d) => d.id == _animalId)
                                      ? _animalId
                                      : null;

                              return DropdownButtonFormField<String>(
                                value: selectedId,
                                decoration: const InputDecoration(
                                  labelText: 'Vaca',
                                  border: OutlineInputBorder(),
                                ),
                                items: docs
                                    .map(
                                      (d) => DropdownMenuItem<String>(
                                        value: d.id,
                                        child: Text(
                                          (d.data()['nombre'] ?? 'Sin nombre')
                                              .toString(),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: readOnly
                                    ? null
                                    : (v) {
                                        if (v == null) return;
                                        final doc = docs.firstWhere(
                                          (x) => x.id == v,
                                          orElse: () => docs.first,
                                        );
                                        setState(() {
                                          _animalId = v;
                                          _animalNombre =
                                              (doc.data()['nombre'] ??
                                                      'Sin nombre')
                                                  .toString();
                                        });
                                      },
                                validator: (v) => (v ?? _animalId) == null
                                    ? 'Selecciona una vaca'
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _nombreCtrl,
                            enabled: !readOnly,
                            decoration: const InputDecoration(
                              labelText: 'Medicamento',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _dosisCtrl,
                            enabled: !readOnly,
                            decoration: const InputDecoration(
                              labelText: 'Dosis',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _obsCtrl,
                            enabled: !readOnly,
                            minLines: 2,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Observaciones',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    readOnly ? null : _pickFechaAplicacion,
                                icon: const Icon(Icons.event_available),
                                label: Text(
                                  'Aplicado: ${_fmtFecha(_fechaAplicacion)}',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: readOnly ? null : _pickFechaProxima,
                                icon: const Icon(Icons.event_repeat),
                                label: Text(
                                  _fechaProxima == null
                                      ? 'Proxima aplicacion'
                                      : 'Proxima: ${_fmtFecha(_fechaProxima!)}',
                                ),
                              ),
                              if (_fechaProxima != null && !readOnly)
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _fechaProxima = null),
                                  child: const Text('Quitar proxima fecha'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _guardando
                                  ? null
                                  : () => _guardarMedicamento(
                                        user,
                                        readOnly: readOnly,
                                      ),
                              icon: _guardando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(
                                _guardando
                                    ? 'Guardando...'
                                    : 'Guardar tratamiento',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SectionTitle(text: 'Historial de tratamientos'),
                const SizedBox(height: 8),
                TextField(
                  controller: _buscarCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por medicamento, vaca o estado',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() => _pagina = 0),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _medicamentosRef
                      .where('creadoPor', isEqualTo: user.uid)
                      .snapshots(includeMetadataChanges: true),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Text('Error cargando tratamientos: ${snap.error}');
                    }

                    final snapshot = snap.data;
                    final docs = (snapshot?.docs ?? []).toList();
                    final pendingCount =
                        docs.where((d) => d.metadata.hasPendingWrites).length;
                    final isFromCache = snapshot?.metadata.isFromCache ?? false;
                    final query = _buscarCtrl.text.trim().toLowerCase();
                    docs.sort((a, b) {
                      final ad =
                          (a.data()['fechaProxima'] as Timestamp?)?.toDate();
                      final bd =
                          (b.data()['fechaProxima'] as Timestamp?)?.toDate();
                      if (ad == null && bd == null) return 0;
                      if (ad == null) return 1;
                      if (bd == null) return -1;
                      return ad.compareTo(bd);
                    });

                    final filtrados = query.isEmpty
                        ? docs
                        : docs.where((d) {
                            final m = d.data();
                            final med = (m['nombreMedicamento'] ?? '')
                                .toString()
                                .toLowerCase();
                            final vaca = (m['animalNombre'] ?? '')
                                .toString()
                                .toLowerCase();
                            final estado =
                                (m['estado'] ?? '').toString().toLowerCase();
                            return med.contains(query) ||
                                vaca.contains(query) ||
                                estado.contains(query);
                          }).toList();

                    final header = SyncSummaryCard(
                      pendingCount: pendingCount,
                      isFromCache: isFromCache,
                    );

                    if (filtrados.isEmpty) {
                      return Column(
                        children: [
                          header,
                          const EmptyStateCard(
                            message: 'Aun no hay tratamientos registrados.',
                          ),
                        ],
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
                        header,
                        Row(
                          children: [
                            Text(
                              'Mostrando ${inicio + 1}-$fin de ${filtrados.length}',
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: paginaActual > 0
                                  ? () =>
                                      setState(() => _pagina = paginaActual - 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('${paginaActual + 1}/$totalPaginas'),
                            IconButton(
                              onPressed: paginaActual < totalPaginas - 1
                                  ? () =>
                                      setState(() => _pagina = paginaActual + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        ...pageDocs.map((d) {
                          final m = d.data();
                          final prox =
                              (m['fechaProxima'] as Timestamp?)?.toDate();
                          final aplicado =
                              (m['fechaAplicacion'] as Timestamp?)?.toDate();
                          final estado = (m['estado'] ?? 'activo').toString();

                          final now = DateTime.now();
                          final hoy = DateTime(now.year, now.month, now.day);
                          final proxDay = prox == null
                              ? null
                              : DateTime(prox.year, prox.month, prox.day);
                          final dias = proxDay == null
                              ? null
                              : proxDay.difference(hoy).inDays;

                          Color tone = Colors.blueGrey;
                          String tag = estado;
                          if (estado == 'completado') {
                            tone = Colors.green;
                            tag = 'completado';
                          } else if (dias != null && dias < 0) {
                            tone = Colors.red;
                            tag = 'vencido';
                          } else if (dias != null && dias <= 7) {
                            tone = Colors.orange;
                            tag = 'por vencer';
                          }

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
                                          (m['nombreMedicamento'] ??
                                                  'Medicamento')
                                              .toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tone.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          tag,
                                          style: TextStyle(
                                            color: tone,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      SyncStatusChip(
                                        hasPendingWrites:
                                            d.metadata.hasPendingWrites,
                                        isFromCache: d.metadata.isFromCache,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Vaca: ${(m['animalNombre'] ?? 'Sin nombre')}',
                                  ),
                                  Text('Dosis: ${(m['dosis'] ?? '')}'),
                                  Text('Aplicado: ${_fmtFecha(aplicado)}'),
                                  Text(
                                    'Proxima: ${prox == null ? 'Sin fecha' : _fmtFecha(prox)}',
                                  ),
                                  if ((m['observaciones'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Text('Obs: ${m['observaciones']}'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if (!readOnly && estado != 'completado')
                                        TextButton.icon(
                                          onPressed: () =>
                                              _marcarCompletado(d.reference),
                                          icon: const Icon(Icons.check_circle),
                                          label: const Text('Completar'),
                                        ),
                                      if (!readOnly)
                                        TextButton.icon(
                                          onPressed: () =>
                                              _eliminarTratamiento(d.reference),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          label: const Text('Eliminar'),
                                        ),
                                    ],
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
      },
    );
  }

  static String _fmtFecha(DateTime? d) {
    if (d == null) return 'Sin fecha';
    return '${d.day}/${d.month}/${d.year}';
  }
}
