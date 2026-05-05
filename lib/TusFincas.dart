import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'services/offline_outbox_service.dart';
import 'widgets/ui/app_background.dart';
import 'widgets/ui/empty_state_card.dart';
import 'widgets/ui/section_title.dart';

class TusFincasPage extends StatefulWidget {
  const TusFincasPage({super.key});

  @override
  State<TusFincasPage> createState() => _TusFincasPageState();
}

class _TusFincasPageState extends State<TusFincasPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _ubicacionCtrl = TextEditingController();
  final _extensionCtrl = TextEditingController();
  final _potrerosCtrl = TextEditingController();
  final _buscarCtrl = TextEditingController();
  bool _guardando = false;
  int _pagina = 0;
  static const int _itemsPorPagina = 6;

  CollectionReference<Map<String, dynamic>> get _fincasRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('fincas');

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _ubicacionCtrl.dispose();
    _extensionCtrl.dispose();
    _potrerosCtrl.dispose();
    _buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> _crearFinca() async {
    if (_guardando) return;
    if (_formKey.currentState?.validate() != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Debes iniciar sesión para crear fincas.')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final opId = 'finca_${user.uid}_${DateTime.now().microsecondsSinceEpoch}';
      await _fincasRef.doc(opId).set({
        'nombre': _nombreCtrl.text.trim(),
        'ubicacion': _ubicacionCtrl.text.trim(),
        'extensionHa': _extensionCtrl.text.trim(),
        'cantidadPotreros': int.tryParse(_potrerosCtrl.text.trim()) ?? 0,
        'propietario': user.uid,
        'sourceOperationId': opId,
        'updatedAt': FieldValue.serverTimestamp(),
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _nombreCtrl.clear();
      _ubicacionCtrl.clear();
      _extensionCtrl.clear();
      _potrerosCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finca guardada correctamente.')),
      );
    } catch (e) {
      await OfflineOutboxService.instance.enqueueFincaCreate(
        propietario: user.uid,
        nombre: _nombreCtrl.text.trim(),
        ubicacion: _ubicacionCtrl.text.trim(),
        extensionHa: _extensionCtrl.text.trim(),
        cantidadPotreros: int.tryParse(_potrerosCtrl.text.trim()) ?? 0,
      );
      _nombreCtrl.clear();
      _ubicacionCtrl.clear();
      _extensionCtrl.clear();
      _potrerosCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finca guardada localmente. Se sincronizara.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _editarFinca(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final nombreCtrl =
        TextEditingController(text: (data['nombre'] ?? '').toString());
    final ubicacionCtrl =
        TextEditingController(text: (data['ubicacion'] ?? '').toString());
    final extensionCtrl =
        TextEditingController(text: (data['extensionHa'] ?? '').toString());
    final potrerosCtrl = TextEditingController(
      text: (data['cantidadPotreros'] ?? 0).toString(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar finca'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ubicacionCtrl,
              decoration: const InputDecoration(labelText: 'Ubicación'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: extensionCtrl,
              decoration: const InputDecoration(labelText: 'Extensión (ha)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: potrerosCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Cantidad de potreros'),
            ),
          ],
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
      await doc.reference.set({
        'nombre': nombreCtrl.text.trim(),
        'ubicacion': ubicacionCtrl.text.trim(),
        'extensionHa': extensionCtrl.text.trim(),
        'cantidadPotreros': int.tryParse(potrerosCtrl.text.trim()) ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finca actualizada.')),
      );
    } catch (e) {
      await OfflineOutboxService.instance.enqueueFincaUpdate(
        fincaId: doc.id,
        nombre: nombreCtrl.text.trim(),
        ubicacion: ubicacionCtrl.text.trim(),
        extensionHa: extensionCtrl.text.trim(),
        cantidadPotreros: int.tryParse(potrerosCtrl.text.trim()) ?? 0,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Actualizacion guardada localmente. Se sincronizara.'),
        ),
      );
    }
  }

  Future<void> _crearPotrero(
    DocumentSnapshot<Map<String, dynamic>> fincaDoc,
    String nombre,
    String descripcion,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final fincaId = fincaDoc.id;
    final opId = 'potrero_${user.uid}_${DateTime.now().microsecondsSinceEpoch}';

    try {
      await fincaDoc.reference.collection('potreros').doc(opId).set({
        'nombre': nombre.trim(),
        'descripcion': descripcion.trim(),
        'estado': 'activo',
        'creadoPor': user.uid,
        'sourceOperationId': opId,
        'updatedAt': FieldValue.serverTimestamp(),
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
    } catch (_) {
      await OfflineOutboxService.instance.enqueuePotreroCreate(
        fincaId: fincaId,
        nombre: nombre,
        descripcion: descripcion,
        estado: 'activo',
        creadoPor: user.uid,
        operationId: opId,
      );
    }
  }

  Future<void> _mostrarPotreros(
    DocumentSnapshot<Map<String, dynamic>> fincaDoc,
  ) async {
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            'Potreros de ${(fincaDoc.data()?['nombre'] ?? '').toString()}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del potrero'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (nombreCtrl.text.trim().isEmpty) return;
                    await _crearPotrero(
                      fincaDoc,
                      nombreCtrl.text.trim(),
                      descCtrl.text.trim(),
                    );
                    nombreCtrl.clear();
                    descCtrl.clear();
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Potrero guardado.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar potrero'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Potreros registrados',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: fincaDoc.reference.collection('potreros').snapshots(),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Text('Aun no hay potreros registrados.');
                    }
                    return Column(
                      children: docs.map((d) {
                        final potrero = d.data();
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.nature_people_outlined),
                          title: Text((potrero['nombre'] ?? '').toString()),
                          subtitle:
                              Text((potrero['descripcion'] ?? '').toString()),
                          trailing:
                              Text((potrero['estado'] ?? 'activo').toString()),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );

    nombreCtrl.dispose();
    descCtrl.dispose();
  }

  Future<void> _eliminarFinca(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar finca'),
        content: const Text('¿Deseas eliminar esta finca?'),
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

    if (confirm != true) return;

    try {
      await _fincasRef.doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finca eliminada.')),
      );
    } catch (e) {
      await OfflineOutboxService.instance.enqueueFincaDelete(fincaId: id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Eliminacion guardada localmente. Se sincronizara.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tus Fincas'),
          backgroundColor: Colors.green,
        ),
        body: const Center(
          child: Text('Debes iniciar sesion para ver tus fincas.'),
        ),
      );
    }

    final userRef =
        FirebaseFirestore.instance.doc('tenants/$kTenantId/users/${user.uid}');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() ?? {};
        final roleRaw =
            (userData['role'] ?? userData['rol'] ?? 'ganadero').toString();
        final role = roleRaw.trim().toLowerCase();
        final canManage = role == 'ganadero';

        return Scaffold(
          appBar: AppBar(
            title: Text('Tus Fincas - $role'),
          ),
          body: AppBackground(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!canManage)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Modo solo lectura para rol veterinario.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SectionTitle(text: 'Registrar Finca'),
                  const SizedBox(height: 12),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nombreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la finca',
                            prefixIcon: Icon(Icons.home_outlined),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Ingresa un nombre'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _ubicacionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ubicación',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Ingresa una ubicación'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _extensionCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Extensión (ha)',
                            prefixIcon: Icon(Icons.square_foot_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            if (double.tryParse(v) == null) {
                              return 'Ingresa un número válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _potrerosCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cantidad de potreros',
                            prefixIcon: Icon(Icons.landscape_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            if (int.tryParse(v) == null) {
                              return 'Ingresa un número válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _guardando || !canManage ? null : _crearFinca,
                            icon: const Icon(Icons.save_outlined),
                            label: _guardando
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Guardar finca'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionTitle(text: 'Fincas registradas'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _buscarCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nombre o ubicacion',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() => _pagina = 0),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _fincasRef
                        .where('propietario', isEqualTo: user.uid)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snap.hasError) {
                        return Text(
                          'Error cargando fincas: ${snap.error}',
                          style: TextStyle(color: Colors.red.shade700),
                        );
                      }

                      final docs = snap.data?.docs ?? [];
                      final query = _buscarCtrl.text.trim().toLowerCase();
                      docs.sort((a, b) {
                        final aDate =
                            (a.data()['creadoEn'] as Timestamp?)?.toDate();
                        final bDate =
                            (b.data()['creadoEn'] as Timestamp?)?.toDate();
                        if (aDate == null && bDate == null) return 0;
                        if (aDate == null) return 1;
                        if (bDate == null) return -1;
                        return bDate.compareTo(aDate);
                      });

                      final filtrados = query.isEmpty
                          ? docs
                          : docs.where((d) {
                              final f = d.data();
                              final nombre =
                                  (f['nombre'] ?? '').toString().toLowerCase();
                              final ubic = (f['ubicacion'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              return nombre.contains(query) ||
                                  ubic.contains(query);
                            }).toList();

                      if (filtrados.isEmpty) {
                        return const EmptyStateCard(
                          message: 'No hay fincas registradas.',
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
                                tooltip: 'Pagina anterior',
                                onPressed: paginaActual > 0
                                    ? () => setState(
                                        () => _pagina = paginaActual - 1)
                                    : null,
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Text('${paginaActual + 1}/$totalPaginas'),
                              IconButton(
                                tooltip: 'Pagina siguiente',
                                onPressed: paginaActual < totalPaginas - 1
                                    ? () => setState(
                                        () => _pagina = paginaActual + 1)
                                    : null,
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pageDocs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final d = pageDocs[i];
                              final finca = d.data();
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.green.shade100,
                                    child: Icon(Icons.landscape,
                                        color: Colors.green.shade700),
                                  ),
                                  title:
                                      Text((finca['nombre'] ?? '').toString()),
                                  subtitle: Text(
                                    'Ubicación: ${(finca['ubicacion'] ?? '').toString()}\n'
                                    'Extensión: ${(finca['extensionHa'] ?? '').toString()} ha · '
                                    'Potreros: ${(finca['cantidadPotreros'] ?? 0).toString()}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                            Icons.grid_view_outlined),
                                        tooltip: 'Potreros',
                                        onPressed: () => _mostrarPotreros(d),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: canManage
                                            ? () => _editarFinca(d)
                                            : null,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: Colors.red.shade700,
                                        onPressed: canManage
                                            ? () => _eliminarFinca(d.id)
                                            : null,
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
            ),
          ),
        );
      },
    );
  }
}
