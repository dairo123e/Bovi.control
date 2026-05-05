import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'ProduccionVacaPage.dart';
import 'config/app_config.dart';
import 'services/offline_outbox_service.dart';
import 'widgets/ui/app_background.dart';
import 'widgets/ui/empty_state_card.dart';
import 'widgets/ui/section_title.dart';

class TusVacasPage extends StatefulWidget {
  const TusVacasPage({super.key});

  @override
  State<TusVacasPage> createState() => _TusVacasPageState();
}

class _ProduccionResumenVaca {
  final String vacaNombre;
  final double total7;
  final double promedioDiario;
  final List<double> dailyLitros;
  final List<String> labels;

  _ProduccionResumenVaca({
    required this.vacaNombre,
    required this.total7,
    required this.promedioDiario,
    required this.dailyLitros,
    required this.labels,
  });
}

class _TusVacasPageState extends State<TusVacasPage> {
  final _buscarCtrl = TextEditingController();
  int _pagina = 0;
  static const int _itemsPorPagina = 6;
  String? _vacaResumenId;

  CollectionReference<Map<String, dynamic>> get _animalesRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('animales');

  CollectionReference<Map<String, dynamic>> get _fincasRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('fincas');

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  InputDecoration _buildDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.green[700]),
      filled: true,
      fillColor: Colors.green[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _chipInfo(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Uint8List? _decodeImage(Map<String, dynamic> vaca) {
    final base64Value = (vaca['fotoBase64'] ?? '').toString();
    if (base64Value.isEmpty) return null;
    try {
      return base64Decode(base64Value);
    } catch (_) {
      return null;
    }
  }

  String _weekdayLabel(DateTime date) {
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return labels[(date.weekday - 1).clamp(0, 6)];
  }

  Future<_ProduccionResumenVaca> _loadProduccionResumen(
    String uid,
    String vacaId,
    String vacaNombre,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));

    final daily = List<double>.filled(7, 0);
    final prodSnap = await _animalesRef
        .doc(vacaId)
        .collection('producciones')
        .where('creadoPor', isEqualTo: uid)
        .get();
    for (final p in prodSnap.docs) {
      final data = p.data();
      final dt = (data['fecha'] as Timestamp?)?.toDate();
      if (dt == null) continue;
      final day = DateTime(dt.year, dt.month, dt.day);
      if (day.isBefore(start) || day.isAfter(today)) continue;
      final index = day.difference(start).inDays;
      if (index < 0 || index >= daily.length) continue;
      final litros = ((data['litros'] ?? 0) as num).toDouble();
      daily[index] += litros;
    }

    final total = daily.fold<double>(0, (sum, v) => sum + v);
    final avgDiario = total / 7;
    final labels = List<String>.generate(7, (i) {
      final date = start.add(Duration(days: i));
      return _weekdayLabel(date);
    });

    return _ProduccionResumenVaca(
      vacaNombre: vacaNombre,
      total7: total,
      promedioDiario: avgDiario,
      dailyLitros: daily,
      labels: labels,
    );
  }

  Widget _buildProduccionChart(_ProduccionResumenVaca resumen) {
    final maxVal =
        resumen.dailyLitros.isEmpty ? 0.0 : resumen.dailyLitros.reduce(max);

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(resumen.dailyLitros.length, (i) {
          final value = resumen.dailyLitros[i];
          final height = maxVal == 0 ? 6.0 : (value / maxVal) * 90 + 6;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  resumen.labels[i],
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildResumenProduccion(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _animalesRef.where('creadoPor', isEqualTo: uid).snapshots(),
      builder: (context, vacasSnap) {
        if (vacasSnap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        }
        if (vacasSnap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Error cargando resumen: ${vacasSnap.error}'),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> vacas =
            vacasSnap.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (vacas.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay vacas registradas para el resumen.'),
            ),
          );
        }

        if (_vacaResumenId == null ||
            !vacas.any((v) => v.id == _vacaResumenId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _vacaResumenId = vacas.first.id);
          });
        }

        var selected = vacas.first;
        if (_vacaResumenId != null) {
          final match = vacas.where((v) => v.id == _vacaResumenId).toList();
          if (match.isNotEmpty) {
            selected = match.first;
          }
        }
        final nombre = (selected.data()['nombre'] ?? 'Sin nombre').toString();

        return Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(text: 'Produccion diaria por vaca'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selected.id,
                  items: vacas
                      .map(
                        (doc) => DropdownMenuItem(
                          value: doc.id,
                          child: Text(
                            (doc.data()['nombre'] ?? 'Sin nombre').toString(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _vacaResumenId = value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Selecciona una vaca',
                    prefixIcon: Icon(Icons.pets),
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<_ProduccionResumenVaca>(
                  future: _loadProduccionResumen(
                    uid,
                    selected.id,
                    nombre,
                  ),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      );
                    }
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('Error cargando resumen: ${snap.error}'),
                      );
                    }

                    final resumen = snap.data;
                    if (resumen == null) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resumen.vacaNombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _summaryKpi(
                                'Total 7 dias',
                                '${resumen.total7.toStringAsFixed(1)} L',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _summaryKpi(
                                'Prom/dia',
                                '${resumen.promedioDiario.toStringAsFixed(1)} L',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildProduccionChart(resumen),
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

  Widget _summaryKpi(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(bool canManage) {
    if (!canManage) {
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(text: 'Registrar nueva vaca'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _NuevaVacaPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Registrar vaca'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteVaca(String id) async {
    try {
      await _animalesRef.doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro eliminado')),
      );
    } catch (_) {
      await OfflineOutboxService.instance.enqueueVacaDelete(vacaId: id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Eliminacion guardada localmente. Se sincronizara.'),
        ),
      );
    }
  }

  Future<void> _editarVaca(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? <String, dynamic>{};
    final nombreCtrl =
        TextEditingController(text: (data['nombre'] ?? '').toString());
    final razaCtrl =
        TextEditingController(text: (data['raza'] ?? '').toString());
    final fechaCtrl = TextEditingController(
      text: _formatDate((data['fechaNacimiento'] as Timestamp?)?.toDate()),
    );
    final partosCtrl =
        TextEditingController(text: (data['cantidadPartos'] ?? 0).toString());
    final produccionCtrl = TextEditingController(
        text: (data['promedioProduccion'] ?? 0).toString());
    final vacunasCtrl =
        TextEditingController(text: (data['vacunas'] ?? '').toString());

    DateTime? fechaNacimiento =
        (data['fechaNacimiento'] as Timestamp?)?.toDate();
    String sexo = (data['sexo'] ?? 'hembra').toString();
    String estado = (data['estado'] ?? 'activo').toString();
    String estadoReproductivo =
        (data['estadoReproductivo'] ?? 'sin definir').toString();
    String? fincaId = (data['fincaId'] ?? '').toString().isEmpty
        ? null
        : (data['fincaId'] ?? '').toString();
    String? potreroId = (data['potreroId'] ?? '').toString().isEmpty
        ? null
        : (data['potreroId'] ?? '').toString();
    Uint8List? imageBytes = _decodeImage(data);
    bool imageChanged = false;
    bool dialogOpen = true;

    final formKey = GlobalKey<FormState>();

    Future<void> pickImage(StateSetter setLocalState) async {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1400,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!dialogOpen) return;
      setLocalState(() {
        imageBytes = bytes;
        imageChanged = true;
      });
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text('Editar ${(data['nombre'] ?? '').toString()}'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nombreCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Nombre'),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Ingresa el nombre'
                                  : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: razaCtrl,
                          decoration: const InputDecoration(labelText: 'Raza'),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Ingresa la raza'
                                  : null,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: sexo,
                          decoration: const InputDecoration(labelText: 'Sexo'),
                          items: const [
                            DropdownMenuItem(
                                value: 'hembra', child: Text('Hembra')),
                            DropdownMenuItem(
                                value: 'toro', child: Text('Toro')),
                            DropdownMenuItem(
                                value: 'novilla', child: Text('Novilla')),
                            DropdownMenuItem(
                                value: 'novillo', child: Text('Novillo')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setLocalState(() => sexo = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: estado,
                          decoration:
                              const InputDecoration(labelText: 'Estado'),
                          items: const [
                            DropdownMenuItem(
                                value: 'activo', child: Text('Activo')),
                            DropdownMenuItem(
                                value: 'vendido', child: Text('Vendido')),
                            DropdownMenuItem(
                                value: 'muerto', child: Text('Muerto')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setLocalState(() => estado = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: estadoReproductivo,
                          decoration: const InputDecoration(
                              labelText: 'Estado reproductivo'),
                          items: const [
                            DropdownMenuItem(
                                value: 'sin definir',
                                child: Text('Sin definir')),
                            DropdownMenuItem(
                                value: 'vaca', child: Text('Vaca')),
                            DropdownMenuItem(
                                value: 'novilla', child: Text('Novilla')),
                            DropdownMenuItem(
                                value: 'gestante', child: Text('Gestante')),
                            DropdownMenuItem(
                                value: 'seca', child: Text('Seca')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setLocalState(() => estadoReproductivo = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: fechaCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Fecha de nacimiento',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          onTap: () async {
                            final selected = await showDatePicker(
                              context: dialogContext,
                              initialDate: fechaNacimiento ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (selected == null) return;
                            setLocalState(() {
                              fechaNacimiento = selected;
                              fechaCtrl.text = _formatDate(selected);
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: partosCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cantidad de partos',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: produccionCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Promedio de produccion',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: vacunasCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Vacunas'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.green.shade200),
                                  image: imageBytes == null
                                      ? null
                                      : DecorationImage(
                                          image: MemoryImage(imageBytes!),
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                alignment: Alignment.center,
                                child: imageBytes == null
                                    ? const Text('Sin imagen')
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => pickImage(setLocalState),
                                  icon: const Icon(Icons.image, size: 18),
                                  label: Text(
                                    imageBytes == null ? 'Subir' : 'Cambiar',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green.shade800,
                                    side: BorderSide(
                                        color: Colors.green.shade700),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    minimumSize: const Size(90, 36),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'JPG o PNG',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _fincasRef
                              .where('propietario',
                                  isEqualTo:
                                      FirebaseAuth.instance.currentUser?.uid)
                              .snapshots(),
                          builder: (context, fincasSnap) {
                            final fincas = fincasSnap.data?.docs ?? [];
                            if (fincas.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No hay fincas disponibles.'),
                              );
                            }
                            if (fincaId != null &&
                                !fincas.any((doc) => doc.id == fincaId)) {
                              fincaId = fincas.first.id;
                              potreroId = null;
                            }
                            return Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value: fincaId,
                                  decoration:
                                      const InputDecoration(labelText: 'Finca'),
                                  items: fincas
                                      .map(
                                        (doc) => DropdownMenuItem(
                                          value: doc.id,
                                          child: Text(
                                              (doc.data()['nombre'] ?? '')
                                                  .toString()),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setLocalState(() {
                                      fincaId = value;
                                      potreroId = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 10),
                                if (fincaId != null)
                                  StreamBuilder<
                                      QuerySnapshot<Map<String, dynamic>>>(
                                    stream: _fincasRef
                                        .doc(fincaId)
                                        .collection('potreros')
                                        .snapshots(),
                                    builder: (context, potrerosSnap) {
                                      final potreros =
                                          potrerosSnap.data?.docs ?? [];
                                      return DropdownButtonFormField<String>(
                                        value: potreroId ?? '',
                                        decoration: const InputDecoration(
                                          labelText: 'Potrero',
                                        ),
                                        items: [
                                          const DropdownMenuItem<String>(
                                            value: '',
                                            child: Text('Sin potrero'),
                                          ),
                                          ...potreros.map(
                                            (doc) => DropdownMenuItem<String>(
                                              value: doc.id,
                                              child: Text(
                                                (doc.data()['nombre'] ?? '')
                                                    .toString(),
                                              ),
                                            ),
                                          ),
                                        ].cast<DropdownMenuItem<String>>(),
                                        onChanged: (value) {
                                          setLocalState(() {
                                            potreroId =
                                                value == null || value.isEmpty
                                                    ? null
                                                    : value;
                                          });
                                        },
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() != true) return;
                    if (fincaId == null || fincaId!.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Selecciona una finca.')),
                      );
                      return;
                    }

                    try {
                      final fincaDoc = await _fincasRef.doc(fincaId).get();
                      final fincaNombre =
                          (fincaDoc.data()?['nombre'] ?? '').toString();
                      String potreroNombre = '';
                      if (potreroId != null && potreroId!.isNotEmpty) {
                        final potreroDoc = await _fincasRef
                            .doc(fincaId)
                            .collection('potreros')
                            .doc(potreroId)
                            .get();
                        potreroNombre =
                            (potreroDoc.data()?['nombre'] ?? '').toString();
                      }

                      final update = <String, dynamic>{
                        'nombre': nombreCtrl.text.trim(),
                        'raza': razaCtrl.text.trim(),
                        'sexo': sexo,
                        'estado': estado,
                        'estadoReproductivo': estadoReproductivo,
                        'fechaNacimiento': Timestamp.fromDate(
                          fechaNacimiento ?? DateTime.now(),
                        ),
                        'cantidadPartos':
                            int.tryParse(partosCtrl.text.trim()) ?? 0,
                        'promedioProduccion':
                            double.tryParse(produccionCtrl.text.trim()) ?? 0.0,
                        'vacunas': vacunasCtrl.text.trim(),
                        'fincaId': fincaId,
                        'fincaNombre': fincaNombre,
                        'potreroId': potreroId ?? '',
                        'potreroNombre': potreroNombre,
                        'updatedAt': FieldValue.serverTimestamp(),
                      };

                      if (imageChanged) {
                        update['fotoBase64'] =
                            imageBytes == null ? '' : base64Encode(imageBytes!);
                      }

                      await doc.reference.set(update, SetOptions(merge: true));

                      if (!mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vaca actualizada.')),
                      );
                    } catch (_) {
                      await OfflineOutboxService.instance.enqueueVacaUpdate(
                        vacaId: doc.id,
                        nombre: nombreCtrl.text.trim(),
                        raza: razaCtrl.text.trim(),
                        sexo: sexo,
                        estado: estado,
                        estadoReproductivo: estadoReproductivo,
                        fechaNacimientoMillis:
                            (fechaNacimiento ?? DateTime.now())
                                .millisecondsSinceEpoch,
                        cantidadPartos:
                            int.tryParse(partosCtrl.text.trim()) ?? 0,
                        promedioProduccion:
                            double.tryParse(produccionCtrl.text.trim()) ?? 0.0,
                        vacunas: vacunasCtrl.text.trim(),
                        fincaId: fincaId ?? '',
                        potreroId: potreroId ?? '',
                        fotoBase64: imageChanged
                            ? (imageBytes == null
                                ? ''
                                : base64Encode(imageBytes!))
                            : null,
                      );
                      if (!mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Actualizacion guardada localmente. Se sincronizara.',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    dialogOpen = false;

    nombreCtrl.dispose();
    razaCtrl.dispose();
    fechaCtrl.dispose();
    partosCtrl.dispose();
    produccionCtrl.dispose();
    vacunasCtrl.dispose();
  }

  Widget _buildVacaCard(
    DocumentSnapshot<Map<String, dynamic>> doc,
    bool canManage,
  ) {
    final vaca = doc.data() ?? <String, dynamic>{};
    final fecha = (vaca['fechaNacimiento'] as Timestamp?)?.toDate();
    final sexo = (vaca['sexo'] ?? '').toString();
    final estado = (vaca['estado'] ?? '').toString();
    final fincaNombre = (vaca['fincaNombre'] ?? '').toString();
    final potreroNombre = (vaca['potreroNombre'] ?? '').toString();
    final avatar = _decodeImage(vaca);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProduccionVacaPage(
                animalRef: doc.reference,
                animalNombre: (vaca['nombre'] ?? '').toString(),
                canManage: canManage,
              ),
            ),
          );
        },
        child: SizedBox(
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (avatar != null)
                Image.memory(avatar, fit: BoxFit.cover)
              else
                Container(color: Colors.green.shade200),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.75),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: PopupMenuButton<String>(
                  color: Colors.white,
                  onSelected: (value) {
                    if (value == 'produccion') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProduccionVacaPage(
                            animalRef: doc.reference,
                            animalNombre: (vaca['nombre'] ?? '').toString(),
                            canManage: canManage,
                          ),
                        ),
                      );
                    }
                    if (value == 'editar' && canManage) {
                      _editarVaca(doc);
                    }
                    if (value == 'eliminar' && canManage) {
                      _deleteVaca(doc.id);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'produccion',
                      child: Text('Produccion'),
                    ),
                    if (canManage)
                      const PopupMenuItem(
                        value: 'editar',
                        child: Text('Editar'),
                      ),
                    if (canManage)
                      const PopupMenuItem(
                        value: 'eliminar',
                        child: Text('Eliminar'),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (vaca['nombre'] ?? '').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _chipInfo('Raza: ${(vaca['raza'] ?? '').toString()}'),
                        _chipInfo('Partos: ${(vaca['cantidadPartos'] ?? 0)}'),
                        _chipInfo(
                            'Prom: ${(vaca['promedioProduccion'] ?? 0)} L'),
                        _chipInfo('Nac: ${_formatDate(fecha)}'),
                        _chipInfo('Sexo: $sexo'),
                        _chipInfo('Estado: $estado'),
                        if (fincaNombre.isNotEmpty)
                          _chipInfo('Finca: $fincaNombre'),
                        if (potreroNombre.isNotEmpty)
                          _chipInfo('Potrero: $potreroNombre'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVacasList(
      QuerySnapshot<Map<String, dynamic>>? snap, bool canManage) {
    final docs = [
      ...(snap?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
    ];
    docs.sort((a, b) {
      final aDate = (a.data()['creadoEn'] as Timestamp?)?.toDate();
      final bDate = (b.data()['creadoEn'] as Timestamp?)?.toDate();
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    final query = _buscarCtrl.text.trim().toLowerCase();
    final filtrados = query.isEmpty
        ? docs
        : docs.where((doc) {
            final data = doc.data();
            final nombre = (data['nombre'] ?? '').toString().toLowerCase();
            final raza = (data['raza'] ?? '').toString().toLowerCase();
            final vacunas = (data['vacunas'] ?? '').toString().toLowerCase();
            final finca = (data['fincaNombre'] ?? '').toString().toLowerCase();
            return nombre.contains(query) ||
                raza.contains(query) ||
                vacunas.contains(query) ||
                finca.contains(query);
          }).toList();

    if (filtrados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: EmptyStateCard(
          message: 'Todavia no hay registros para mostrar.',
        ),
      );
    }

    final inicio = _pagina * _itemsPorPagina;
    final paginaDocs = filtrados.skip(inicio).take(_itemsPorPagina).toList();
    final totalPaginas = (filtrados.length / _itemsPorPagina).ceil();
    if (_pagina >= totalPaginas && totalPaginas > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _pagina = 0);
      });
    }

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: paginaDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _buildVacaCard(paginaDocs[index], canManage),
        ),
        if (totalPaginas > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed:
                    _pagina == 0 ? null : () => setState(() => _pagina -= 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Pagina ${_pagina + 1} de $totalPaginas'),
              IconButton(
                onPressed: _pagina >= totalPaginas - 1
                    ? null
                    : () => setState(() => _pagina += 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBody(bool canManage, String uid) {
    return AppBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!canManage)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Tu rol es solo lectura. Puedes consultar vacas y su produccion, pero no crear ni editar.',
                    ),
                  ),
                ),
              ),
            _buildResumenProduccion(uid),
            const SizedBox(height: 16),
            _buildCreateButton(canManage),
            const SizedBox(height: 20),
            const SectionTitle(
              text: 'Vacas registradas',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _buscarCtrl,
              decoration: _buildDecoration(
                'Buscar por nombre, raza, vacuna o finca',
                Icons.search,
              ),
              onChanged: (_) => setState(() => _pagina = 0),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  _animalesRef.where('creadoPor', isEqualTo: uid).snapshots(),
              builder: (context, animalsSnap) {
                if (animalsSnap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (animalsSnap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Error cargando vacas: ${animalsSnap.error}'),
                  );
                }
                return _buildVacasList(animalsSnap.data, canManage);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tus Vacas'),
        backgroundColor: const Color.fromARGB(255, 37, 68, 38),
        elevation: 5,
        shadowColor: Colors.greenAccent,
      ),
      body: user == null
          ? const Center(child: Text('Debes iniciar sesion para acceder.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .doc('tenants/$kTenantId/users/${user.uid}')
                  .snapshots(),
              builder: (context, userSnap) {
                final role = (userSnap.data?.data()?['role'] ??
                        userSnap.data?.data()?['rol'] ??
                        '')
                    .toString()
                    .toLowerCase();
                final canManage = role.isEmpty || role == 'ganadero';
                return _buildBody(canManage, user.uid);
              },
            ),
    );
  }
}

Widget _sectionCard(String title, List<Widget> children) {
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class _NuevaVacaPage extends StatefulWidget {
  const _NuevaVacaPage();

  @override
  State<_NuevaVacaPage> createState() => _NuevaVacaPageState();
}

class _NuevaVacaPageState extends State<_NuevaVacaPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _razaCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  final _partosCtrl = TextEditingController();
  final _produccionCtrl = TextEditingController();
  final _vacunasCtrl = TextEditingController();

  String _sexo = 'hembra';
  String _estado = 'activo';
  String _estadoReproductivo = 'sin definir';
  String? _fincaId;
  String? _potreroId;
  DateTime? _fechaNacimiento;
  Uint8List? _imageBytes;
  bool _guardando = false;

  CollectionReference<Map<String, dynamic>> get _animalesRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('animales');

  CollectionReference<Map<String, dynamic>> get _fincasRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('fincas');

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _razaCtrl.dispose();
    _fechaCtrl.dispose();
    _partosCtrl.dispose();
    _produccionCtrl.dispose();
    _vacunasCtrl.dispose();
    super.dispose();
  }

  InputDecoration _buildDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.green[700]),
      filled: true,
      fillColor: Colors.green[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1400,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _imageBytes = bytes);
  }

  Future<void> _pickFecha({DateTime? initial}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: initial ?? _fechaNacimiento ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    if (!mounted) return;
    setState(() {
      _fechaNacimiento = selected;
      _fechaCtrl.text = _formatDate(selected);
    });
  }

  void _ensureFincaInicial(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return;
    if (_fincaId != null && docs.any((doc) => doc.id == _fincaId)) return;
    final first = docs.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _fincaId = first.id;
        _potreroId = null;
      });
    });
  }

  Future<void> _saveVaca() async {
    if (_guardando) return;
    if (_formKey.currentState?.validate() != true) return;
    if (_fincaId == null || _fincaId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una finca.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesion para registrar.')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      String fotoBase64 = '';
      if (_imageBytes != null) {
        fotoBase64 = base64Encode(_imageBytes!);
      }

      final opId = 'vaca_${user.uid}_${DateTime.now().microsecondsSinceEpoch}';
      final fincaDoc = await _fincasRef.doc(_fincaId).get();
      final fincaNombre = (fincaDoc.data()?['nombre'] ?? '').toString();
      String potreroNombre = '';
      if ((_potreroId ?? '').isNotEmpty) {
        final potreroDoc = await _fincasRef
            .doc(_fincaId)
            .collection('potreros')
            .doc(_potreroId)
            .get();
        potreroNombre = (potreroDoc.data()?['nombre'] ?? '').toString();
      }

      await _animalesRef.doc(opId).set({
        'nombre': _nombreCtrl.text.trim(),
        'raza': _razaCtrl.text.trim(),
        'sexo': _sexo,
        'estado': _estado,
        'estadoReproductivo': _estadoReproductivo,
        'fechaNacimiento': Timestamp.fromDate(
          _fechaNacimiento ?? DateTime.now(),
        ),
        'cantidadPartos': int.tryParse(_partosCtrl.text.trim()) ?? 0,
        'promedioProduccion':
            double.tryParse(_produccionCtrl.text.trim()) ?? 0.0,
        'vacunas': _vacunasCtrl.text.trim(),
        'fotoUrl': '',
        'fotoBase64': fotoBase64,
        'fincaId': _fincaId,
        'fincaNombre': fincaNombre,
        'potreroId': _potreroId ?? '',
        'potreroNombre': potreroNombre,
        'creadoPor': user.uid,
        'sourceOperationId': opId,
        'updatedAt': FieldValue.serverTimestamp(),
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vaca registrada exitosamente')),
      );
    } catch (e) {
      await OfflineOutboxService.instance.enqueueVacaCreate(
        uid: user.uid,
        nombre: _nombreCtrl.text.trim(),
        raza: _razaCtrl.text.trim(),
        sexo: _sexo,
        estado: _estado,
        estadoReproductivo: _estadoReproductivo,
        fechaNacimientoMillis:
            (_fechaNacimiento ?? DateTime.now()).millisecondsSinceEpoch,
        cantidadPartos: int.tryParse(_partosCtrl.text.trim()) ?? 0,
        promedioProduccion: double.tryParse(_produccionCtrl.text.trim()) ?? 0.0,
        vacunas: _vacunasCtrl.text.trim(),
        fotoUrl: '',
        fotoBase64: _imageBytes == null ? '' : base64Encode(_imageBytes!),
        fincaId: _fincaId ?? '',
        potreroId: _potreroId ?? '',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vaca guardada localmente. Se sincronizara.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar nueva vaca'),
      ),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionCard(
                  'Datos basicos',
                  [
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: _buildDecoration('Nombre', Icons.pets),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Ingresa el nombre'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _razaCtrl,
                      decoration: _buildDecoration('Raza', Icons.category),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Ingresa la raza'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _sexo,
                      decoration: _buildDecoration('Sexo', Icons.wc),
                      items: const [
                        DropdownMenuItem(
                            value: 'hembra', child: Text('Hembra')),
                        DropdownMenuItem(value: 'toro', child: Text('Toro')),
                        DropdownMenuItem(
                            value: 'novilla', child: Text('Novilla')),
                        DropdownMenuItem(
                            value: 'novillo', child: Text('Novillo')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _sexo = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  'Estado y fechas',
                  [
                    DropdownButtonFormField<String>(
                      value: _estado,
                      decoration: _buildDecoration('Estado', Icons.flag),
                      items: const [
                        DropdownMenuItem(
                            value: 'activo', child: Text('Activo')),
                        DropdownMenuItem(
                            value: 'vendido', child: Text('Vendido')),
                        DropdownMenuItem(
                            value: 'muerto', child: Text('Muerto')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _estado = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _estadoReproductivo,
                      decoration: _buildDecoration(
                        'Estado reproductivo',
                        Icons.favorite,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'sin definir', child: Text('Sin definir')),
                        DropdownMenuItem(value: 'vaca', child: Text('Vaca')),
                        DropdownMenuItem(
                            value: 'novilla', child: Text('Novilla')),
                        DropdownMenuItem(
                            value: 'gestante', child: Text('Gestante')),
                        DropdownMenuItem(value: 'seca', child: Text('Seca')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _estadoReproductivo = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fechaCtrl,
                      readOnly: true,
                      decoration: _buildDecoration(
                        'Fecha de nacimiento',
                        Icons.calendar_month,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.date_range),
                          onPressed: () => _pickFecha(),
                        ),
                      ),
                      onTap: () => _pickFecha(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  'Produccion y vacunas',
                  [
                    TextFormField(
                      controller: _partosCtrl,
                      decoration: _buildDecoration(
                        'Cantidad de partos',
                        Icons.child_care,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _produccionCtrl,
                      decoration: _buildDecoration(
                        'Promedio produccion',
                        Icons.water_drop,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _vacunasCtrl,
                      decoration: _buildDecoration('Vacunas', Icons.vaccines),
                      maxLines: 2,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  'Ubicacion',
                  [
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _fincasRef
                          .where('propietario',
                              isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                          .snapshots(),
                      builder: (context, snap) {
                        final fincas = snap.data?.docs ?? [];
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(),
                          );
                        }
                        if (fincas.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Primero crea una finca para registrar vacas.',
                            ),
                          );
                        }
                        _ensureFincaInicial(fincas);
                        return Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _fincaId,
                              decoration: _buildDecoration('Finca', Icons.map),
                              items: fincas
                                  .map(
                                    (doc) => DropdownMenuItem(
                                      value: doc.id,
                                      child: Text(
                                        (doc.data()['nombre'] ?? '').toString(),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _fincaId = value;
                                  _potreroId = null;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            if (_fincaId != null)
                              StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>>(
                                stream: _fincasRef
                                    .doc(_fincaId)
                                    .collection('potreros')
                                    .snapshots(),
                                builder: (context, potreroSnap) {
                                  final potreros = potreroSnap.data?.docs ?? [];
                                  return DropdownButtonFormField<String>(
                                    decoration: _buildDecoration(
                                      'Potrero',
                                      Icons.grass,
                                    ),
                                    value: _potreroId ?? '',
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: '',
                                        child: Text('Sin potrero'),
                                      ),
                                      ...potreros.map(
                                        (doc) => DropdownMenuItem<String>(
                                          value: doc.id,
                                          child: Text(
                                            (doc.data()['nombre'] ?? '')
                                                .toString(),
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _potreroId = value?.isEmpty == true
                                            ? null
                                            : value;
                                      });
                                    },
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  'Foto',
                  [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                              image: _imageBytes == null
                                  ? null
                                  : DecorationImage(
                                      image: MemoryImage(_imageBytes!),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            alignment: Alignment.center,
                            child: _imageBytes == null
                                ? const Text('Sin imagen')
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.image, size: 18),
                              label: Text(
                                _imageBytes == null ? 'Subir' : 'Cambiar',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green.shade800,
                                side: BorderSide(color: Colors.green.shade700),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(90, 36),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'JPG o PNG',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _guardando ? null : _saveVaca,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _guardando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Registrar vaca'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
