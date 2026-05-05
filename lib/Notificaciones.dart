import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'widgets/ui/app_background.dart';
import 'widgets/ui/empty_state_card.dart';
import 'widgets/ui/section_title.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({super.key});

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  bool _soloCriticas = false;

  CollectionReference<Map<String, dynamic>> get _animalesRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('animales');

  CollectionReference<Map<String, dynamic>> get _eventosRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('eventos');

  CollectionReference<Map<String, dynamic>> get _tareasRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('tareas');

  CollectionReference<Map<String, dynamic>> get _medicamentosRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('medicamentos');

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notificaciones'),
          backgroundColor: Colors.green,
        ),
        body: const Center(
          child: Text('Debes iniciar sesion para ver tus notificaciones.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: SwitchListTile(
                value: _soloCriticas,
                onChanged: (v) => setState(() => _soloCriticas = v),
                title: const Text('Modo enfoque'),
                subtitle: const Text('Mostrar solo alertas criticas'),
                secondary: const Icon(Icons.filter_alt_outlined),
              ),
            ),
            const SizedBox(height: 10),
            const SectionTitle(text: 'Tareas vencidas'),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _tareasRef
                  .where('creadoPor', isEqualTo: user.uid)
                  .where('estado', isEqualTo: 'pendiente')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Text('Error cargando tareas vencidas: ${snap.error}');
                }

                final now = DateTime.now();
                final hoy = DateTime(now.year, now.month, now.day);
                final docs = (snap.data?.docs ?? []).where((d) {
                  final fecha = (d.data()['fecha'] as Timestamp?)?.toDate();
                  if (fecha == null) return false;
                  final fechaDia = DateTime(fecha.year, fecha.month, fecha.day);
                  return fechaDia.isBefore(hoy);
                }).toList();

                docs.sort((a, b) {
                  final aDate = (a.data()['fecha'] as Timestamp?)?.toDate();
                  final bDate = (b.data()['fecha'] as Timestamp?)?.toDate();
                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return aDate.compareTo(bDate);
                });

                if (docs.isEmpty) {
                  return const EmptyStateCard(
                      message: 'No hay tareas vencidas.');
                }

                return Column(
                  children: docs.map((d) {
                    final data = d.data();
                    final fecha = (data['fecha'] as Timestamp?)?.toDate();
                    return _NotifCard(
                      icon: Icons.warning_amber_rounded,
                      color: Colors.red,
                      title: (data['titulo'] ?? 'Tarea').toString(),
                      subtitle:
                          '${(data['descripcion'] ?? '').toString()}\nVencida desde: ${_fmtFecha(fecha)}',
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            const SectionTitle(text: 'Vacunas proximas (7 dias)'),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _animalesRef
                  .where('creadoPor', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, animalesSnap) {
                if (animalesSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (animalesSnap.hasError) {
                  return Text('Error cargando vacas: ${animalesSnap.error}');
                }

                final animales = <String, String>{
                  for (final doc in animalesSnap.data?.docs ?? [])
                    doc.id: (doc.data()['nombre'] ?? 'Sin nombre').toString(),
                };

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _eventosRef
                      .where('creadoPor', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Text('Error cargando vacunas: ${snap.error}');
                    }

                    final now = DateTime.now();
                    final hoy = DateTime(now.year, now.month, now.day);
                    final max = hoy.add(const Duration(days: 7));

                    final docs = (snap.data?.docs ?? []).where((d) {
                      final data = d.data();
                      final tipo =
                          (data['tipo'] ?? '').toString().toLowerCase();
                      if (!tipo.contains('vacun')) return false;
                      final fecha = (data['fecha'] as Timestamp?)?.toDate();
                      if (fecha == null) return false;
                      final fechaDia =
                          DateTime(fecha.year, fecha.month, fecha.day);
                      return !fechaDia.isBefore(hoy) && !fechaDia.isAfter(max);
                    }).toList();

                    docs.sort((a, b) {
                      final aDate = (a.data()['fecha'] as Timestamp?)?.toDate();
                      final bDate = (b.data()['fecha'] as Timestamp?)?.toDate();
                      if (aDate == null && bDate == null) return 0;
                      if (aDate == null) return 1;
                      if (bDate == null) return -1;
                      return aDate.compareTo(bDate);
                    });

                    if (docs.isEmpty) {
                      return const EmptyStateCard(
                        message:
                            'No hay vacunas programadas en los proximos 7 dias.',
                      );
                    }

                    return Column(
                      children: docs.map((d) {
                        final data = d.data();
                        final fecha = (data['fecha'] as Timestamp?)?.toDate();
                        final animalId = (data['animalId'] ?? '').toString();
                        final animalNombre =
                            animales[animalId] ?? 'No especificado';
                        return _NotifCard(
                          icon: Icons.vaccines_outlined,
                          color: Colors.blue,
                          title: (data['titulo'] ?? 'Vacunacion').toString(),
                          subtitle:
                              'Animal: $animalNombre\nFecha: ${_fmtFecha(fecha)}',
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            const SectionTitle(text: 'Alertas de produccion'),
            const SizedBox(height: 8),
            FutureBuilder<List<_ProduccionAlert>>(
              future: _loadProduccionAlerts(user.uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Text('Error cargando alertas: ${snap.error}');
                }

                final alerts = snap.data ?? [];
                if (alerts.isEmpty) {
                  return const EmptyStateCard(
                    message: 'No hay caidas significativas de produccion.',
                  );
                }

                return Column(
                  children: alerts
                      .map(
                        (a) => _NotifCard(
                          icon: Icons.trending_down,
                          color: Colors.red,
                          title: 'Caida de produccion en ${a.animalNombre}',
                          subtitle:
                              'Ultimos 7d: ${a.actual.toStringAsFixed(1)} L | 7d previos: ${a.previo.toStringAsFixed(1)} L\nDisminucion: ${a.caidaPct.toStringAsFixed(0)}%',
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            const SectionTitle(text: 'Medicamentos por vencer'),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _medicamentosRef
                  .where('creadoPor', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Text('Error cargando medicamentos: ${snap.error}');
                }

                final now = DateTime.now();
                final hoy = DateTime(now.year, now.month, now.day);
                final docs = (snap.data?.docs ?? []).where((d) {
                  final data = d.data();
                  final estado = (data['estado'] ?? 'activo').toString();
                  final fecha = (data['fechaProxima'] as Timestamp?)?.toDate();
                  if (estado == 'completado' || fecha == null) return false;
                  final fechaDia = DateTime(fecha.year, fecha.month, fecha.day);
                  final dias = fechaDia.difference(hoy).inDays;
                  return dias <= 7;
                }).toList();

                docs.sort((a, b) {
                  final aDate =
                      (a.data()['fechaProxima'] as Timestamp?)?.toDate();
                  final bDate =
                      (b.data()['fechaProxima'] as Timestamp?)?.toDate();
                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return aDate.compareTo(bDate);
                });

                if (docs.isEmpty) {
                  return const EmptyStateCard(
                    message: 'No hay medicamentos proximos a vencer en 7 dias.',
                  );
                }

                return Column(
                  children: docs.map((d) {
                    final data = d.data();
                    final fecha =
                        (data['fechaProxima'] as Timestamp?)?.toDate();
                    final fechaDia = fecha == null
                        ? null
                        : DateTime(fecha.year, fecha.month, fecha.day);
                    final dias =
                        fechaDia == null ? 0 : fechaDia.difference(hoy).inDays;
                    final vencido = dias < 0;
                    final color = vencido ? Colors.red : Colors.orange;
                    final nombre =
                        (data['nombreMedicamento'] ?? 'Medicamento').toString();
                    final animal =
                        (data['animalNombre'] ?? 'Sin nombre').toString();
                    final textoDias = vencido
                        ? 'Vencido hace ${dias.abs()} dias'
                        : 'Vence en $dias dias';

                    return _NotifCard(
                      icon: Icons.medication_liquid,
                      color: color,
                      title: '$nombre - $animal',
                      subtitle: '$textoDias\nFecha: ${_fmtFecha(fecha)}',
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            const SectionTitle(text: 'Tareas pendientes'),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _tareasRef
                  .where('creadoPor', isEqualTo: user.uid)
                  .where('estado', isEqualTo: 'pendiente')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Text('Error cargando tareas: ${snap.error}');
                }

                final now = DateTime.now();
                final hoy = DateTime(now.year, now.month, now.day);
                final max = hoy.add(const Duration(days: 7));

                final docs = (snap.data?.docs ?? []).where((d) {
                  final fecha = (d.data()['fecha'] as Timestamp?)?.toDate();
                  if (fecha == null) return false;
                  if (!_soloCriticas) return true;
                  final fechaDia = DateTime(fecha.year, fecha.month, fecha.day);
                  return fechaDia.isBefore(hoy) || !fechaDia.isAfter(max);
                }).toList();

                docs.sort((a, b) {
                  final aDate = (a.data()['fecha'] as Timestamp?)?.toDate();
                  final bDate = (b.data()['fecha'] as Timestamp?)?.toDate();
                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return aDate.compareTo(bDate);
                });

                if (docs.isEmpty) {
                  return EmptyStateCard(
                    message: _soloCriticas
                        ? 'No hay tareas vencidas o proximas.'
                        : 'No tienes tareas pendientes.',
                  );
                }

                return Column(
                  children: docs.map((d) {
                    final data = d.data();
                    final fecha = (data['fecha'] as Timestamp?)?.toDate();
                    return _NotifCard(
                      icon: Icons.checklist,
                      color: Colors.orange,
                      title: (data['titulo'] ?? 'Tarea').toString(),
                      subtitle:
                          '${(data['descripcion'] ?? '').toString()}\nFecha: ${_fmtFecha(fecha)}',
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            const SectionTitle(text: 'Eventos proximos'),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _eventosRef
                  .where('creadoPor', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Text('Error cargando eventos: ${snap.error}');
                }

                final now = DateTime.now();
                final hoy = DateTime(now.year, now.month, now.day);
                final max = hoy.add(const Duration(days: 7));

                final docs = (snap.data?.docs ?? []).where((d) {
                  final fecha = (d.data()['fecha'] as Timestamp?)?.toDate();
                  if (fecha == null) return false;
                  final fechaDia = DateTime(fecha.year, fecha.month, fecha.day);
                  if (!_soloCriticas) {
                    return !fechaDia.isBefore(hoy);
                  }
                  return fechaDia.isBefore(hoy) || !fechaDia.isAfter(max);
                }).toList();

                docs.sort((a, b) {
                  final aDate = (a.data()['fecha'] as Timestamp?)?.toDate();
                  final bDate = (b.data()['fecha'] as Timestamp?)?.toDate();
                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return aDate.compareTo(bDate);
                });

                if (docs.isEmpty) {
                  return EmptyStateCard(
                    message: _soloCriticas
                        ? 'No hay eventos vencidos o proximos.'
                        : 'No tienes eventos proximos.',
                  );
                }

                final limited = _soloCriticas ? docs : docs.take(20).toList();
                return Column(
                  children: limited.map((d) {
                    final data = d.data();
                    final fecha = (data['fecha'] as Timestamp?)?.toDate();
                    return _NotifCard(
                      icon: Icons.event,
                      color: Colors.blue,
                      title: (data['titulo'] ?? 'Evento').toString(),
                      subtitle:
                          '${(data['descripcion'] ?? '').toString()}\nFecha: ${_fmtFecha(fecha)}',
                    );
                  }).toList(),
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

  Future<List<_ProduccionAlert>> _loadProduccionAlerts(String uid) async {
    final vacasSnap =
        await _animalesRef.where('creadoPor', isEqualTo: uid).get();
    if (vacasSnap.docs.isEmpty) return [];

    final now = DateTime.now();
    final start7 = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final startPrev7 = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 13));

    final alerts = <_ProduccionAlert>[];

    for (final vaca in vacasSnap.docs) {
      final vacaData = vaca.data();
      final nombre = (vacaData['nombre'] ?? 'Sin nombre').toString();

      final prodSnap = await vaca.reference
          .collection('producciones')
          .where('creadoPor', isEqualTo: uid)
          .get();

      double actual = 0;
      double previo = 0;

      for (final p in prodSnap.docs) {
        final data = p.data();
        final dt = (data['fecha'] as Timestamp?)?.toDate();
        if (dt == null) continue;
        final litros = ((data['litros'] ?? 0) as num).toDouble();

        if (!dt.isBefore(start7)) {
          actual += litros;
        } else if (!dt.isBefore(startPrev7) && dt.isBefore(start7)) {
          previo += litros;
        }
      }

      if (previo > 0 && actual < (previo * 0.8)) {
        final caidaPct =
            ((1 - (actual / previo)) * 100).clamp(0, 100).toDouble();
        alerts.add(
          _ProduccionAlert(
            animalNombre: nombre,
            actual: actual,
            previo: previo,
            caidaPct: caidaPct,
          ),
        );
      }
    }

    return alerts;
  }
}

class _ProduccionAlert {
  final String animalNombre;
  final double actual;
  final double previo;
  final double caidaPct;

  _ProduccionAlert({
    required this.animalNombre,
    required this.actual,
    required this.previo,
    required this.caidaPct,
  });
}

class _NotifCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _NotifCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
