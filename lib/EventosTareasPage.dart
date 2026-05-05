import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'config/app_config.dart';
import 'services/offline_outbox_service.dart';
import 'widgets/ui/app_background.dart';
import 'widgets/ui/empty_state_card.dart';
import 'widgets/ui/section_title.dart';
import 'widgets/ui/sync_state_widgets.dart';

class EventosTareasPage extends StatefulWidget {
  const EventosTareasPage({super.key});

  @override
  State<EventosTareasPage> createState() => _EventosTareasPageState();
}

class _EventosTareasPageState extends State<EventosTareasPage>
    with SingleTickerProviderStateMixin {
  final _eventoFormKey = GlobalKey<FormState>();
  final _tareaFormKey = GlobalKey<FormState>();

  final _eventoTituloCtrl = TextEditingController();
  final _eventoDescCtrl = TextEditingController();
  String _eventoTipo = 'Vacunación';
  DateTime _eventoFecha = DateTime.now();
  String? _animalIdSeleccionado;

  final _tareaTituloCtrl = TextEditingController();
  final _tareaDescCtrl = TextEditingController();
  String? _tareaAnimalIdSeleccionado;
  String _tareaPrioridad = 'media';
  String _tareaEstado = 'pendiente';
  DateTime _tareaFecha = DateTime.now();

  bool _guardandoEvento = false;
  bool _guardandoTarea = false;
  late final TabController _tabController;

  CollectionReference<Map<String, dynamic>> get _eventosRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('eventos');

  CollectionReference<Map<String, dynamic>> get _animalesRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('animales');

  CollectionReference<Map<String, dynamic>> get _tareasRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('tareas');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eventoTituloCtrl.dispose();
    _eventoDescCtrl.dispose();
    _tareaTituloCtrl.dispose();
    _tareaDescCtrl.dispose();
    super.dispose();
  }

  Widget _animalSelector({
    required String uid,
    required String? selectedId,
    required ValueChanged<String?> onChanged,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _animalesRef.where('creadoPor', isEqualTo: uid).snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }

        return DropdownButtonFormField<String>(
          value: selectedId,
          items: [
            ...docs.map(
              (doc) => DropdownMenuItem<String>(
                value: doc.id,
                child: Text(
                  (doc.data()['nombre'] ?? 'Sin nombre').toString(),
                ),
              ),
            ),
          ],
          onChanged: onChanged,
          decoration: const InputDecoration(labelText: 'Vaca (opcional)'),
        );
      },
    );
  }

  Future<void> _pickFechaEvento() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _eventoFecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _eventoFecha = d);
  }

  Future<void> _pickFechaTarea() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _tareaFecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _tareaFecha = d);
  }

  Future<void> _guardarEvento() async {
    if (_guardandoEvento) return;
    if (_eventoFormKey.currentState?.validate() != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('Debes iniciar sesión para crear eventos.');
      return;
    }

    final operationId =
        'evento_${user.uid}_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';

    setState(() => _guardandoEvento = true);
    try {
      await _eventosRef.doc(operationId).set({
        'titulo': _eventoTituloCtrl.text.trim(),
        'descripcion': _eventoDescCtrl.text.trim(),
        'fecha': Timestamp.fromDate(_eventoFecha),
        'animalId': _animalIdSeleccionado ?? '',
        'tipo': _eventoTipo,
        'creadoPor': user.uid,
        'sourceOperationId': operationId,
        'updatedAt': FieldValue.serverTimestamp(),
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 6));
      _eventoTituloCtrl.clear();
      _eventoDescCtrl.clear();
      setState(() {
        _eventoTipo = 'Vacunación';
        _eventoFecha = DateTime.now();
        _animalIdSeleccionado = null;
      });
      _snack('Evento guardado.');
    } catch (e) {
      await OfflineOutboxService.instance.enqueueEventoCreate(
        uid: user.uid,
        titulo: _eventoTituloCtrl.text.trim(),
        descripcion: _eventoDescCtrl.text.trim(),
        tipo: _eventoTipo,
        animalId: _animalIdSeleccionado ?? '',
        fechaMillis: _eventoFecha.millisecondsSinceEpoch,
        operationId: operationId,
      );
      _eventoTituloCtrl.clear();
      _eventoDescCtrl.clear();
      setState(() {
        _eventoTipo = 'Vacunación';
        _eventoFecha = DateTime.now();
        _animalIdSeleccionado = null;
      });
      _snack('Sin red/servidor. Evento en cola local para sincronizar.');
    } finally {
      if (mounted) setState(() => _guardandoEvento = false);
    }
  }

  Future<void> _guardarTarea() async {
    if (_guardandoTarea) return;
    if (_tareaFormKey.currentState?.validate() != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('Debes iniciar sesión para crear tareas.');
      return;
    }

    final operationId =
        'tarea_${user.uid}_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';

    setState(() => _guardandoTarea = true);
    try {
      await _tareasRef.doc(operationId).set({
        'titulo': _tareaTituloCtrl.text.trim(),
        'descripcion': _tareaDescCtrl.text.trim(),
        'fecha': Timestamp.fromDate(_tareaFecha),
        'estado': _tareaEstado,
        'prioridad': _tareaPrioridad,
        'asignadoA': _tareaAnimalIdSeleccionado ?? '',
        'creadoPor': user.uid,
        'sourceOperationId': operationId,
        'updatedAt': FieldValue.serverTimestamp(),
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 6));
      _tareaTituloCtrl.clear();
      _tareaDescCtrl.clear();
      setState(() {
        _tareaPrioridad = 'media';
        _tareaEstado = 'pendiente';
        _tareaFecha = DateTime.now();
        _tareaAnimalIdSeleccionado = null;
      });
      _snack('Tarea guardada.');
    } catch (e) {
      await OfflineOutboxService.instance.enqueueTareaCreate(
        uid: user.uid,
        titulo: _tareaTituloCtrl.text.trim(),
        descripcion: _tareaDescCtrl.text.trim(),
        estado: _tareaEstado,
        prioridad: _tareaPrioridad,
        asignadoA: _tareaAnimalIdSeleccionado ?? '',
        fechaMillis: _tareaFecha.millisecondsSinceEpoch,
        operationId: operationId,
      );
      _tareaTituloCtrl.clear();
      _tareaDescCtrl.clear();
      setState(() {
        _tareaPrioridad = 'media';
        _tareaEstado = 'pendiente';
        _tareaFecha = DateTime.now();
        _tareaAnimalIdSeleccionado = null;
      });
      _snack('Sin red/servidor. Tarea en cola local para sincronizar.');
    } finally {
      if (mounted) setState(() => _guardandoTarea = false);
    }
  }

  Future<void> _editarEvento(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final tituloCtrl =
        TextEditingController(text: (data['titulo'] ?? '').toString());
    final descCtrl =
        TextEditingController(text: (data['descripcion'] ?? '').toString());
    final tipoCtrl =
        TextEditingController(text: (data['tipo'] ?? '').toString());
    String? animalId = (data['animalId'] ?? '').toString().isEmpty
        ? null
        : (data['animalId'] ?? '').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar evento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tituloCtrl,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tipoCtrl,
                decoration: const InputDecoration(labelText: 'Tipo'),
              ),
              const SizedBox(height: 8),
              _animalSelector(
                uid: FirebaseAuth.instance.currentUser?.uid ?? '',
                selectedId: animalId,
                onChanged: (value) => animalId = value,
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
    );

    if (ok != true) return;
    try {
      await doc.reference.update({
        'titulo': tituloCtrl.text.trim(),
        'descripcion': descCtrl.text.trim(),
        'tipo': tipoCtrl.text.trim(),
        'animalId': animalId ?? '',
      });
      _snack('Evento actualizado.');
    } catch (_) {
      await OfflineOutboxService.instance.enqueueEventoUpdate(
        eventoId: doc.id,
        titulo: tituloCtrl.text.trim(),
        descripcion: descCtrl.text.trim(),
        tipo: tipoCtrl.text.trim(),
        animalId: animalId ?? '',
      );
      _snack('Actualizacion guardada localmente. Se sincronizara.');
    }
  }

  Future<void> _editarTarea(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final tituloCtrl =
        TextEditingController(text: (data['titulo'] ?? '').toString());
    final descCtrl =
        TextEditingController(text: (data['descripcion'] ?? '').toString());
    String prioridad = (data['prioridad'] ?? 'media').toString();
    String estado = (data['estado'] ?? 'pendiente').toString();
    String? animalId = (data['asignadoA'] ?? '').toString().isEmpty
        ? null
        : (data['asignadoA'] ?? '').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Editar tarea'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tituloCtrl,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
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
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: estado,
                  items: const [
                    DropdownMenuItem(
                      value: 'pendiente',
                      child: Text('pendiente'),
                    ),
                    DropdownMenuItem(
                      value: 'completada',
                      child: Text('completada'),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => estado = v ?? 'pendiente'),
                  decoration: const InputDecoration(labelText: 'Estado'),
                ),
                const SizedBox(height: 8),
                _animalSelector(
                  uid: FirebaseAuth.instance.currentUser?.uid ?? '',
                  selectedId: animalId,
                  onChanged: (value) => animalId = value,
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
      await doc.reference.update({
        'titulo': tituloCtrl.text.trim(),
        'descripcion': descCtrl.text.trim(),
        'prioridad': prioridad,
        'estado': estado,
        'asignadoA': animalId ?? '',
      });
      _snack('Tarea actualizada.');
    } catch (_) {
      await OfflineOutboxService.instance.enqueueTareaUpdate(
        tareaId: doc.id,
        titulo: tituloCtrl.text.trim(),
        descripcion: descCtrl.text.trim(),
        prioridad: prioridad,
        estado: estado,
        asignadoA: animalId ?? '',
      );
      _snack('Actualizacion guardada localmente. Se sincronizara.');
    }
  }

  Future<void> _eliminarDoc(DocumentReference<Map<String, dynamic>> ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text('¿Deseas eliminar este elemento?'),
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
      _snack('Registro eliminado.');
    } catch (_) {
      final path = ref.path;
      if (path.contains('/eventos/')) {
        await OfflineOutboxService.instance.enqueueEventoDelete(
          eventoId: ref.id,
        );
      } else if (path.contains('/tareas/')) {
        await OfflineOutboxService.instance.enqueueTareaDelete(
          tareaId: ref.id,
        );
      }
      _snack('Eliminacion guardada localmente. Se sincronizara.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtFecha(DateTime? d) {
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Eventos y Tareas'),
        ),
        body: const Center(
          child: Text('Debes iniciar sesion para ver este modulo.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos y Tareas'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Eventos'),
            Tab(text: 'Tareas'),
          ],
        ),
      ),
      body: AppBackground(
        child: TabBarView(
          controller: _tabController,
          children: [_eventosTab(user.uid), _tareasTab(user.uid)],
        ),
      ),
    );
  }

  Widget _eventosTab(String uid) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Form(
            key: _eventoFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _eventoTituloCtrl,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa un título'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _eventoDescCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 2,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa una descripción'
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _eventoTipo,
                  items: const [
                    DropdownMenuItem(
                        value: 'Vacunación', child: Text('Vacunación')),
                    DropdownMenuItem(value: 'Parto', child: Text('Parto')),
                    DropdownMenuItem(
                        value: 'Revisión veterinaria',
                        child: Text('Revisión veterinaria')),
                    DropdownMenuItem(
                        value: 'Alimentación', child: Text('Alimentación')),
                  ],
                  onChanged: (v) =>
                      setState(() => _eventoTipo = v ?? 'Vacunación'),
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),
                const SizedBox(height: 10),
                _animalSelector(
                  uid: uid,
                  selectedId: _animalIdSeleccionado,
                  onChanged: (value) =>
                      setState(() => _animalIdSeleccionado = value),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text('Fecha: ${_fmtFecha(_eventoFecha)}'),
                    ),
                    TextButton.icon(
                      onPressed: _pickFechaEvento,
                      icon: const Icon(Icons.date_range),
                      label: const Text('Cambiar fecha'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _guardandoEvento ? null : _guardarEvento,
                    icon: const Icon(Icons.save_outlined),
                    label: _guardandoEvento
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Guardar evento'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle(text: 'Eventos registrados'),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _eventosRef
                .where('creadoPor', isEqualTo: uid)
                .snapshots(includeMetadataChanges: true),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Text('Error: ${snap.error}');
              }
              final snapshot = snap.data;
              final docs = snapshot?.docs ?? [];
              final pendingCount =
                  docs.where((d) => d.metadata.hasPendingWrites).length;
              final isFromCache = snapshot?.metadata.isFromCache ?? false;
              docs.sort((a, b) {
                final aDate = (a.data()['fecha'] as Timestamp?)?.toDate();
                final bDate = (b.data()['fecha'] as Timestamp?)?.toDate();
                if (aDate == null && bDate == null) return 0;
                if (aDate == null) return 1;
                if (bDate == null) return -1;
                return aDate.compareTo(bDate);
              });

              final header = SyncSummaryCard(
                pendingCount: pendingCount,
                isFromCache: isFromCache,
              );

              if (docs.isEmpty) {
                return Column(
                  children: [
                    header,
                    const EmptyStateCard(
                      message: 'No hay eventos registrados.',
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  header,
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final e = d.data();
                      final fecha = (e['fecha'] as Timestamp?)?.toDate();
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.event),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text((e['titulo'] ?? '').toString()),
                              ),
                              SyncStatusChip(
                                hasPendingWrites: d.metadata.hasPendingWrites,
                                isFromCache: d.metadata.isFromCache,
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Tipo: ${(e['tipo'] ?? '').toString()}\n'
                            'Fecha: ${_fmtFecha(fecha)}\n'
                            '${(e['descripcion'] ?? '').toString()}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editarEvento(d),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.red.shade700,
                                onPressed: () => _eliminarDoc(d.reference),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tareasTab(String uid) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Form(
            key: _tareaFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _tareaTituloCtrl,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa un título'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _tareaDescCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 2,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa una descripción'
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _tareaPrioridad,
                  items: const [
                    DropdownMenuItem(value: 'alta', child: Text('alta')),
                    DropdownMenuItem(value: 'media', child: Text('media')),
                    DropdownMenuItem(value: 'baja', child: Text('baja')),
                  ],
                  onChanged: (v) =>
                      setState(() => _tareaPrioridad = v ?? 'media'),
                  decoration: const InputDecoration(labelText: 'Prioridad'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _tareaEstado,
                  items: const [
                    DropdownMenuItem(
                        value: 'pendiente', child: Text('pendiente')),
                    DropdownMenuItem(
                        value: 'completada', child: Text('completada')),
                  ],
                  onChanged: (v) =>
                      setState(() => _tareaEstado = v ?? 'pendiente'),
                  decoration: const InputDecoration(labelText: 'Estado'),
                ),
                const SizedBox(height: 10),
                _animalSelector(
                  uid: uid,
                  selectedId: _tareaAnimalIdSeleccionado,
                  onChanged: (value) =>
                      setState(() => _tareaAnimalIdSeleccionado = value),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text('Fecha: ${_fmtFecha(_tareaFecha)}')),
                    TextButton.icon(
                      onPressed: _pickFechaTarea,
                      icon: const Icon(Icons.date_range),
                      label: const Text('Cambiar fecha'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _guardandoTarea ? null : _guardarTarea,
                    icon: const Icon(Icons.save_outlined),
                    label: _guardandoTarea
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Guardar tarea'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle(text: 'Tareas registradas'),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _tareasRef
                .where('creadoPor', isEqualTo: uid)
                .snapshots(includeMetadataChanges: true),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Text('Error: ${snap.error}');
              }
              final snapshot = snap.data;
              final docs = snapshot?.docs ?? [];
              final pendingCount =
                  docs.where((d) => d.metadata.hasPendingWrites).length;
              final isFromCache = snapshot?.metadata.isFromCache ?? false;
              docs.sort((a, b) {
                final aDate = (a.data()['fecha'] as Timestamp?)?.toDate();
                final bDate = (b.data()['fecha'] as Timestamp?)?.toDate();
                if (aDate == null && bDate == null) return 0;
                if (aDate == null) return 1;
                if (bDate == null) return -1;
                return aDate.compareTo(bDate);
              });

              final header = SyncSummaryCard(
                pendingCount: pendingCount,
                isFromCache: isFromCache,
              );

              if (docs.isEmpty) {
                return Column(
                  children: [
                    header,
                    const EmptyStateCard(
                      message: 'No hay tareas registradas.',
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  header,
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final t = d.data();
                      final fecha = (t['fecha'] as Timestamp?)?.toDate();
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.checklist),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text((t['titulo'] ?? '').toString()),
                              ),
                              SyncStatusChip(
                                hasPendingWrites: d.metadata.hasPendingWrites,
                                isFromCache: d.metadata.isFromCache,
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Estado: ${(t['estado'] ?? '').toString()} · '
                            'Prioridad: ${(t['prioridad'] ?? '').toString()}\n'
                            'Fecha: ${_fmtFecha(fecha)}\n'
                            '${(t['descripcion'] ?? '').toString()}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editarTarea(d),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.red.shade700,
                                onPressed: () => _eliminarDoc(d.reference),
                              ),
                            ],
                          ),
                          onTap: () {
                            final next =
                                (t['estado'] ?? 'pendiente') == 'pendiente'
                                    ? 'completada'
                                    : 'pendiente';
                            d.reference
                                .set({
                                  'estado': next,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true))
                                .timeout(const Duration(seconds: 4))
                                .catchError((_) async {
                                  await OfflineOutboxService.instance
                                      .enqueueTareaToggleEstado(
                                    tareaId: d.id,
                                    estado: next,
                                  );
                                  _snack(
                                      'Cambio guardado localmente. Se sincronizara.');
                                });
                          },
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
