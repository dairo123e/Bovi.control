import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'config/app_config.dart';
import 'services/offline_outbox_service.dart';

class ProduccionVacaPage extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> animalRef;
  final String animalNombre;
  final bool canManage;

  const ProduccionVacaPage({
    super.key,
    required this.animalRef,
    required this.animalNombre,
    required this.canManage,
  });

  @override
  State<ProduccionVacaPage> createState() => _ProduccionVacaPageState();
}

class _ProduccionVacaPageState extends State<ProduccionVacaPage> {
  final _formKey = GlobalKey<FormState>();
  final _litrosCtrl = TextEditingController();

  DateTime _fecha = DateTime.now();
  bool _guardando = false;
  int _diasFiltro = 30;

  CollectionReference<Map<String, dynamic>> get _produccionRef =>
      widget.animalRef.collection('producciones');

  CollectionReference<Map<String, dynamic>> get _eventosRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('eventos');

  @override
  void dispose() {
    _litrosCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _fecha = d);
  }

  Future<void> _registrarProduccion() async {
    if (!widget.canManage) return;
    if (_guardando) return;
    if (_formKey.currentState?.validate() != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final litros = double.tryParse(_litrosCtrl.text.trim()) ?? 0.0;
    final operationId =
        'prod_${user.uid}_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';

    setState(() => _guardando = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final prodDoc = _produccionRef.doc(operationId);
      final eventoDoc = _eventosRef.doc('${operationId}_event');

      batch.set(
          prodDoc,
          {
            'fecha': Timestamp.fromDate(_fecha),
            'litros': litros,
            'animalId': widget.animalRef.id,
            'animalNombre': widget.animalNombre,
            'creadoPor': user.uid,
            'sourceOperationId': operationId,
            'updatedAt': FieldValue.serverTimestamp(),
            'creadoEn': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      batch.set(
          eventoDoc,
          {
            'titulo': 'Registro de produccion',
            'descripcion':
                'Se registraron ${litros.toStringAsFixed(1)} L para ${widget.animalNombre}.',
            'fecha': Timestamp.fromDate(_fecha),
            'animalId': widget.animalRef.id,
            'tipo': 'Ordeño',
            'creadoPor': user.uid,
            'sourceOperationId': operationId,
            'updatedAt': FieldValue.serverTimestamp(),
            'creadoEn': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      await batch.commit().timeout(const Duration(seconds: 6));

      _litrosCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produccion registrada.')),
      );
    } catch (e) {
      await OfflineOutboxService.instance.enqueueProduccionCreate(
        uid: user.uid,
        animalId: widget.animalRef.id,
        animalNombre: widget.animalNombre,
        litros: litros,
        fechaMillis: _fecha.millisecondsSinceEpoch,
        operationId: operationId,
      );

      _litrosCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produccion guardada localmente. Se sincronizara.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminarProduccion(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    try {
      await doc.reference.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro eliminado.')),
      );
    } catch (e) {
      await OfflineOutboxService.instance.enqueueProduccionDelete(
        animalId: widget.animalRef.id,
        produccionId: doc.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Eliminacion guardada localmente. Se sincronizara.'),
        ),
      );
    }
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Widget _chart(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: _diasFiltro - 1));

    final filtered = docs.where((d) {
      final dt = (d.data()['fecha'] as Timestamp?)?.toDate();
      return dt != null && !dt.isBefore(start);
    }).toList();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Sin datos en el periodo seleccionado.'),
      );
    }

    final byDay = <String, double>{};
    for (final d in filtered) {
      final dt = (d.data()['fecha'] as Timestamp).toDate();
      final key = '${dt.year}-${dt.month}-${dt.day}';
      byDay[key] =
          (byDay[key] ?? 0) + ((d.data()['litros'] ?? 0) as num).toDouble();
    }

    final entries = byDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final maxVal = entries.fold<double>(
      0,
      (prev, e) => e.value > prev ? e.value : prev,
    );
    final divisor = maxVal <= 0 ? 1.0 : maxVal;

    final total = entries.fold<double>(0, (acc, e) => acc + e.value);
    final promedio = total / entries.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: ${total.toStringAsFixed(1)} L'),
            Text('Promedio diario: ${promedio.toStringAsFixed(1)} L'),
            const SizedBox(height: 10),
            ...entries.map((e) {
              final parts = e.key.split('-');
              final label = '${parts[2]}/${parts[1]}';
              final value = e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label),
                        Text('${value.toStringAsFixed(1)} L'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (value / divisor).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.green.shade100,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesion.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Produccion - ${widget.animalNombre}'),
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.canManage)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Modo solo lectura para rol veterinario.'),
              ),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Fecha: ${_fmt(_fecha)}')),
                      TextButton.icon(
                        onPressed: widget.canManage ? _pickFecha : null,
                        icon: const Icon(Icons.date_range),
                        label: const Text('Cambiar'),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: _litrosCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Litros producidos',
                      prefixIcon: Icon(Icons.water_drop_outlined),
                    ),
                    validator: (v) {
                      final x = double.tryParse(v ?? '');
                      if (x == null || x <= 0) return 'Ingresa un valor valido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.canManage && !_guardando
                          ? _registrarProduccion
                          : null,
                      icon: const Icon(Icons.save_outlined),
                      label: _guardando
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Registrar produccion'),
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
            Row(
              children: [
                const Text(
                  'Periodo:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _diasFiltro,
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('Semana')),
                    DropdownMenuItem(value: 30, child: Text('Mes')),
                    DropdownMenuItem(value: 90, child: Text('Trimestre')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _diasFiltro = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _produccionRef
                  .where('creadoPor', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Text('Error cargando produccion: ${snap.error}');
                }

                final docs = snap.data?.docs ?? [];
                docs.sort((a, b) {
                  final aDate = (a.data()['fecha'] as Timestamp?)?.toDate();
                  final bDate = (b.data()['fecha'] as Timestamp?)?.toDate();
                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return bDate.compareTo(aDate);
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _chart(docs),
                    const SizedBox(height: 10),
                    const Text(
                      'Historial',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (docs.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Text('Aun no hay registros de produccion.'),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final d = docs[i];
                          final data = d.data();
                          final dt = (data['fecha'] as Timestamp?)?.toDate();
                          final litros =
                              ((data['litros'] ?? 0) as num).toDouble();
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.bar_chart),
                              title: Text('${litros.toStringAsFixed(1)} L'),
                              subtitle:
                                  Text('Fecha: ${dt != null ? _fmt(dt) : '-'}'),
                              trailing: widget.canManage
                                  ? IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _eliminarProduccion(d),
                                    )
                                  : null,
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
    );
  }
}
