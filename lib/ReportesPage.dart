import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/app_config.dart';
import 'services/offline_outbox_service.dart';
import 'widgets/ui/app_background.dart';
import 'widgets/ui/empty_state_card.dart';
import 'widgets/ui/section_title.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  int _periodoDias = 30;
  bool _exportando = false;
  bool _exportandoMensual = false;

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

  CollectionReference<Map<String, dynamic>> get _medicamentosRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('medicamentos');

  CollectionReference<Map<String, dynamic>> get _eventosRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('eventos');

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesion para ver reportes.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes y exportacion'),
      ),
      body: AppBackground(
        child: ValueListenableBuilder<List<OutboxItem>>(
          valueListenable: OfflineOutboxService.instance.items,
          builder: (context, outboxItems, __) {
            return FutureBuilder<_ReporteData>(
              future: _loadReporte(user.uid, _periodoDias, outboxItems),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                      child: Text('Error cargando reportes: ${snap.error}'));
                }

                final r = snap.data ?? _ReporteData.empty(_periodoDias);
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Periodo',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 10),
                          DropdownButton<int>(
                            value: _periodoDias,
                            items: const [
                              DropdownMenuItem(value: 7, child: Text('7 dias')),
                              DropdownMenuItem(
                                  value: 30, child: Text('30 dias')),
                              DropdownMenuItem(
                                  value: 90, child: Text('90 dias')),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _periodoDias = v);
                            },
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: _exportando
                                ? null
                                : () => _exportarCsv(context, r),
                            icon: const Icon(Icons.file_download_outlined),
                            label: Text(
                                _exportando ? 'Exportando...' : 'Exportar CSV'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: _exportandoMensual
                              ? null
                              : () => _exportarCsvMensual(context, r),
                          icon: const Icon(Icons.table_chart_outlined),
                          label: Text(
                            _exportandoMensual
                                ? 'Exportando mensual...'
                                : 'Exportar mensual (6 meses)',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _kpiGrid(r),
                      const SizedBox(height: 10),
                      _comparativaMensualCard(r),
                      const SizedBox(height: 14),
                      const SectionTitle(text: 'Top vacas por produccion'),
                      const SizedBox(height: 8),
                      if (r.topVacas.isEmpty)
                        const EmptyStateCard(
                          message:
                              'No hay produccion registrada para este periodo.',
                        )
                      else
                        ...r.topVacas.map(
                          (t) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.emoji_events_outlined),
                              title: Text(t.nombre),
                              subtitle: Text('ID: ${t.animalId}'),
                              trailing:
                                  Text('${t.litros.toStringAsFixed(1)} L'),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const SectionTitle(text: 'Comparativa mensual por vaca'),
                      const SizedBox(height: 8),
                      if (r.comparativaVacas.isEmpty)
                        const EmptyStateCard(
                          message:
                              'Sin datos suficientes para comparativa por vaca.',
                        )
                      else
                        ...r.comparativaVacas.map(
                          (c) {
                            final down = c.variacionPct < 0;
                            final tone = down ? Colors.red : Colors.green;
                            final icon =
                                down ? Icons.trending_down : Icons.trending_up;
                            final sign = c.variacionPct > 0 ? '+' : '';
                            return Card(
                              child: ListTile(
                                leading: Icon(icon, color: tone),
                                title: Text(c.animalNombre),
                                subtitle: Text(
                                  'Actual: ${c.litrosActual.toStringAsFixed(1)} L | Anterior: ${c.litrosAnterior.toStringAsFixed(1)} L',
                                ),
                                trailing: Text(
                                  '$sign${c.variacionPct.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: tone,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 12),
                      const SectionTitle(text: 'Resumen mensual por vaca'),
                      const SizedBox(height: 8),
                      if (r.resumenMensual.isEmpty)
                        const EmptyStateCard(
                          message: 'Sin datos mensuales para mostrar.',
                        )
                      else
                        ...r.resumenMensual.take(12).map(
                              (m) => Card(
                                child: ListTile(
                                  leading:
                                      const Icon(Icons.calendar_month_outlined),
                                  title:
                                      Text('${m.mesLabel} - ${m.animalNombre}'),
                                  subtitle: Text('Registros: ${m.registros}'),
                                  trailing: Text(
                                      '${m.totalLitros.toStringAsFixed(1)} L'),
                                ),
                              ),
                            ),
                      const SizedBox(height: 10),
                      _insightCard(r),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _kpiGrid(_ReporteData r) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _kpiCard('Vacas', '${r.totalVacas}', Icons.pets),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _kpiCard(
                'Produccion',
                '${r.totalLitros.toStringAsFixed(1)} L',
                Icons.local_drink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _kpiCard(
                'Promedio dia',
                '${r.promedioDiario.toStringAsFixed(1)} L',
                Icons.show_chart,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _kpiCard(
                'Tratamientos activos',
                '${r.tratamientosPorVencer}',
                Icons.medication,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _kpiCard(
                'Tareas pendientes',
                '${r.tareasPendientes}',
                Icons.task_alt,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _kpiCard(
                'Eventos proximos',
                '${r.eventosProximos}',
                Icons.event,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kpiCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.green.shade700),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _insightCard(_ReporteData r) {
    String insight;
    if (r.totalLitros <= 0) {
      insight = 'Aun no hay datos de produccion para generar tendencias.';
    } else if (r.promedioDiario >= 20) {
      insight = 'Rendimiento alto en el periodo seleccionado.';
    } else if (r.promedioDiario >= 10) {
      insight = 'Rendimiento estable con oportunidad de mejora.';
    } else {
      insight = 'Rendimiento bajo: revisa alimentacion, salud y ordeño.';
    }

    return Card(
      color: Colors.lightGreen.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Insight rapido',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(insight),
          ],
        ),
      ),
    );
  }

  Widget _comparativaMensualCard(_ReporteData r) {
    final actual = r.litrosMesActual;
    final anterior = r.litrosMesAnterior;
    final varPct = r.variacionMensualPct;

    final bool noBase = anterior <= 0;
    final bool baja = !noBase && (varPct ?? 0) < 0;
    final bool bajaFuerte = !noBase && (varPct ?? 0) <= -15;

    final tone = bajaFuerte
        ? Colors.red
        : baja
            ? Colors.orange
            : Colors.green;
    final icon = baja ? Icons.trending_down : Icons.trending_up;

    final subtitle = noBase
        ? 'No hay base suficiente del mes anterior para calcular variacion.'
        : 'Variacion: ${(varPct ?? 0).toStringAsFixed(1)}%';

    return Card(
      color: tone.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: tone),
                const SizedBox(width: 8),
                const Text(
                  'Comparativa mensual',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Mes actual: ${actual.toStringAsFixed(1)} L'),
            Text('Mes anterior: ${anterior.toStringAsFixed(1)} L'),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: tone,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (bajaFuerte)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Alerta: caida fuerte de produccion mensual, revisar salud y manejo.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportarCsv(BuildContext context, _ReporteData r) async {
    setState(() => _exportando = true);
    try {
      final b = StringBuffer();
      b.writeln('reporte,bovi_control');
      b.writeln('periodo_dias,${r.periodoDias}');
      b.writeln('total_vacas,${r.totalVacas}');
      b.writeln('total_litros,${r.totalLitros.toStringAsFixed(2)}');
      b.writeln(
          'promedio_diario_litros,${r.promedioDiario.toStringAsFixed(2)}');
      b.writeln('tratamientos_activos,${r.tratamientosPorVencer}');
      b.writeln('tareas_pendientes,${r.tareasPendientes}');
      b.writeln('eventos_proximos,${r.eventosProximos}');
      b.writeln('litros_mes_actual,${r.litrosMesActual.toStringAsFixed(2)}');
      b.writeln(
          'litros_mes_anterior,${r.litrosMesAnterior.toStringAsFixed(2)}');
      b.writeln(
          'variacion_mensual_pct,${(r.variacionMensualPct ?? 0).toStringAsFixed(2)}');
      b.writeln('');
      b.writeln('top_vacas');
      b.writeln('animal_id,nombre,litros');
      for (final t in r.topVacas) {
        b.writeln(
            '${_esc(t.animalId)},${_esc(t.nombre)},${t.litros.toStringAsFixed(2)}');
      }
      b.writeln('');
      b.writeln('comparativa_vaca_mensual');
      b.writeln(
          'animal_id,animal_nombre,litros_mes_actual,litros_mes_anterior,variacion_pct');
      for (final c in r.comparativaVacas) {
        b.writeln(
          '${_esc(c.animalId)},${_esc(c.animalNombre)},${c.litrosActual.toStringAsFixed(2)},${c.litrosAnterior.toStringAsFixed(2)},${c.variacionPct.toStringAsFixed(2)}',
        );
      }

      final csv = b.toString();
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV copiado al portapapeles.'),
        ),
      );

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Exportacion lista'),
          content: const Text(
            'Se copio el contenido CSV al portapapeles para pegarlo en Excel o Google Sheets.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _exportarCsvMensual(BuildContext context, _ReporteData r) async {
    setState(() => _exportandoMensual = true);
    try {
      final b = StringBuffer();
      b.writeln('reporte_mensual,bovi_control');
      b.writeln('mes,animal_id,animal_nombre,total_litros,registros');
      for (final m in r.resumenMensual) {
        b.writeln(
          '${_esc(m.mesLabel)},${_esc(m.animalId)},${_esc(m.animalNombre)},${m.totalLitros.toStringAsFixed(2)},${m.registros}',
        );
      }

      await Clipboard.setData(ClipboardData(text: b.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV mensual copiado al portapapeles.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _exportandoMensual = false);
    }
  }

  static String _esc(String v) {
    final q = v.replaceAll('"', '""');
    return '"$q"';
  }

  Future<_ReporteData> _loadReporte(
    String uid,
    int periodoDias,
    List<OutboxItem> outboxItems,
  ) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: periodoDias - 1));

    final vacasSnap =
        await _animalesRef.where('creadoPor', isEqualTo: uid).get();
    final totalVacas = vacasSnap.docs.length;

    final porVaca = <String, _TopVaca>{};
    final porMes = <String, _MesResumen>{};
    double totalLitros = 0;

    for (final vaca in vacasSnap.docs) {
      final vacaData = vaca.data();
      final animalId = vaca.id;
      final animalNombre = (vacaData['nombre'] ?? 'Sin nombre').toString();

      final prodsSnap = await vaca.reference
          .collection('producciones')
          .where('creadoPor', isEqualTo: uid)
          .get();

      for (final p in prodsSnap.docs) {
        final data = p.data();
        final fecha = (data['fecha'] as Timestamp?)?.toDate();
        if (fecha == null) continue;
        final litros = ((data['litros'] ?? 0) as num).toDouble();

        final mesKey =
            '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}';
        final mesAnimalKey = '$mesKey|$animalId';
        final mesCurrent = porMes[mesAnimalKey] ??
            _MesResumen(
              mesLabel: mesKey,
              animalId: animalId,
              animalNombre: animalNombre,
              totalLitros: 0,
              registros: 0,
            );
        porMes[mesAnimalKey] = _MesResumen(
          mesLabel: mesCurrent.mesLabel,
          animalId: mesCurrent.animalId,
          animalNombre: mesCurrent.animalNombre,
          totalLitros: mesCurrent.totalLitros + litros,
          registros: mesCurrent.registros + 1,
        );

        if (fecha.isBefore(start)) continue;
        totalLitros += litros;

        final current = porVaca[animalId] ??
            _TopVaca(animalId: animalId, nombre: animalNombre, litros: 0);
        porVaca[animalId] = _TopVaca(
          animalId: animalId,
          nombre: animalNombre,
          litros: current.litros + litros,
        );
      }
    }

    final promedioDiario = periodoDias <= 0 ? 0.0 : (totalLitros / periodoDias);

    final finRango =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
    final tareasSnap = await _tareasRef
        .where('creadoPor', isEqualTo: uid)
        .where('estado', isEqualTo: 'pendiente')
        .get();
    final tareasPendientes = tareasSnap.docs.where((d) {
      final fecha = (d.data()['fecha'] as Timestamp?)?.toDate();
      if (fecha == null) return false;
      return !fecha.isBefore(start) && !fecha.isAfter(finRango);
    }).length;

    final medsSnap =
        await _medicamentosRef.where('creadoPor', isEqualTo: uid).get();
    final tratamientosPorVencer = medsSnap.docs.where((d) {
      final data = d.data();
      final estado = (data['estado'] ?? 'activo').toString();
      return estado != 'completado';
    }).length;

    final eventosSnap =
        await _eventosRef.where('creadoPor', isEqualTo: uid).get();
    final eventosProximos = eventosSnap.docs.where((d) {
      final fecha = (d.data()['fecha'] as Timestamp?)?.toDate();
      if (fecha == null) return false;
      final fechaDia = DateTime(fecha.year, fecha.month, fecha.day);
      return !fechaDia.isBefore(DateTime(now.year, now.month, now.day)) &&
          !fechaDia.isAfter(finRango);
    }).length;

    int tareasPendientesExtra = 0;
    int tratamientosPorVencerExtra = 0;
    int eventosProximosExtra = 0;

    for (final item in outboxItems) {
      final payload = item.payload;
      final payloadUid = (payload['uid'] ?? '').toString();
      if (payloadUid != uid) continue;

      if (item.type == 'tarea_create') {
        final estado = (payload['estado'] ?? 'pendiente').toString();
        if (estado != 'pendiente') continue;
        final fechaMillis = (payload['fechaMillis'] ?? 0) as int;
        if (fechaMillis <= 0) continue;
        final fecha = DateTime.fromMillisecondsSinceEpoch(fechaMillis);
        if (!fecha.isBefore(start) && !fecha.isAfter(finRango)) {
          tareasPendientesExtra += 1;
        }
      }

      if (item.type == 'medicamento_create') {
        tratamientosPorVencerExtra += 1;
      }

      if (item.type == 'evento_create') {
        final fechaMillis = (payload['fechaMillis'] ?? 0) as int;
        if (fechaMillis <= 0) continue;
        final fecha = DateTime.fromMillisecondsSinceEpoch(fechaMillis);
        if (!fecha.isBefore(DateTime(now.year, now.month, now.day)) &&
            !fecha.isAfter(finRango)) {
          eventosProximosExtra += 1;
        }
      }
    }

    final top = porVaca.values.toList()
      ..sort((a, b) => b.litros.compareTo(a.litros));

    final mesActualKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    final mesAnteriorKey =
        '${prevMonth.year}-${prevMonth.month.toString().padLeft(2, '0')}';

    double litrosMesActual = 0;
    double litrosMesAnterior = 0;
    for (final m in porMes.values) {
      if (m.mesLabel == mesActualKey) litrosMesActual += m.totalLitros;
      if (m.mesLabel == mesAnteriorKey) litrosMesAnterior += m.totalLitros;
    }

    final actualByAnimal = <String, _MesResumen>{};
    final anteriorByAnimal = <String, _MesResumen>{};
    for (final m in porMes.values) {
      if (m.mesLabel == mesActualKey) {
        actualByAnimal[m.animalId] = m;
      } else if (m.mesLabel == mesAnteriorKey) {
        anteriorByAnimal[m.animalId] = m;
      }
    }

    double? variacionMensualPct;
    if (litrosMesAnterior > 0) {
      variacionMensualPct =
          ((litrosMesActual - litrosMesAnterior) / litrosMesAnterior) * 100;
    }

    final minMensual = DateTime(now.year, now.month - 5, 1);
    final resumenMensual = porMes.values.where((m) {
      final parts = m.mesLabel.split('-');
      if (parts.length != 2) return false;
      final y = int.tryParse(parts[0]);
      final mm = int.tryParse(parts[1]);
      if (y == null || mm == null) return false;
      final mesDt = DateTime(y, mm, 1);
      return !mesDt.isBefore(minMensual);
    }).toList()
      ..sort((a, b) {
        final c = b.mesLabel.compareTo(a.mesLabel);
        if (c != 0) return c;
        return b.totalLitros.compareTo(a.totalLitros);
      });

    final idsComparables = actualByAnimal.keys
        .where((id) => anteriorByAnimal.containsKey(id))
        .toList();
    final comparativaVacas = idsComparables.map((id) {
      final a = actualByAnimal[id]!;
      final p = anteriorByAnimal[id]!;
      final variacion = p.totalLitros <= 0
          ? 0.0
          : ((a.totalLitros - p.totalLitros) / p.totalLitros) * 100;
      return _ComparativaVaca(
        animalId: id,
        animalNombre: a.animalNombre,
        litrosActual: a.totalLitros,
        litrosAnterior: p.totalLitros,
        variacionPct: variacion,
      );
    }).toList()
      ..sort((x, y) => x.variacionPct.compareTo(y.variacionPct));

    return _ReporteData(
      periodoDias: periodoDias,
      totalVacas: totalVacas,
      totalLitros: totalLitros,
      promedioDiario: promedioDiario,
      tareasPendientes: tareasPendientes + tareasPendientesExtra,
      tratamientosPorVencer: tratamientosPorVencer + tratamientosPorVencerExtra,
      eventosProximos: eventosProximos + eventosProximosExtra,
      topVacas: top.take(5).toList(),
      resumenMensual: resumenMensual,
      comparativaVacas: comparativaVacas.take(5).toList(),
      litrosMesActual: litrosMesActual,
      litrosMesAnterior: litrosMesAnterior,
      variacionMensualPct: variacionMensualPct,
    );
  }
}

class _ReporteData {
  final int periodoDias;
  final int totalVacas;
  final double totalLitros;
  final double promedioDiario;
  final int tareasPendientes;
  final int tratamientosPorVencer;
  final int eventosProximos;
  final List<_TopVaca> topVacas;
  final List<_MesResumen> resumenMensual;
  final List<_ComparativaVaca> comparativaVacas;
  final double litrosMesActual;
  final double litrosMesAnterior;
  final double? variacionMensualPct;

  _ReporteData({
    required this.periodoDias,
    required this.totalVacas,
    required this.totalLitros,
    required this.promedioDiario,
    required this.tareasPendientes,
    required this.tratamientosPorVencer,
    required this.eventosProximos,
    required this.topVacas,
    required this.resumenMensual,
    required this.comparativaVacas,
    required this.litrosMesActual,
    required this.litrosMesAnterior,
    required this.variacionMensualPct,
  });

  factory _ReporteData.empty(int periodo) {
    return _ReporteData(
      periodoDias: periodo,
      totalVacas: 0,
      totalLitros: 0,
      promedioDiario: 0,
      tareasPendientes: 0,
      tratamientosPorVencer: 0,
      eventosProximos: 0,
      topVacas: const [],
      resumenMensual: const [],
      comparativaVacas: const [],
      litrosMesActual: 0,
      litrosMesAnterior: 0,
      variacionMensualPct: null,
    );
  }
}

class _TopVaca {
  final String animalId;
  final String nombre;
  final double litros;

  _TopVaca({
    required this.animalId,
    required this.nombre,
    required this.litros,
  });
}

class _MesResumen {
  final String mesLabel;
  final String animalId;
  final String animalNombre;
  final double totalLitros;
  final int registros;

  _MesResumen({
    required this.mesLabel,
    required this.animalId,
    required this.animalNombre,
    required this.totalLitros,
    required this.registros,
  });
}

class _ComparativaVaca {
  final String animalId;
  final String animalNombre;
  final double litrosActual;
  final double litrosAnterior;
  final double variacionPct;

  _ComparativaVaca({
    required this.animalId,
    required this.animalNombre,
    required this.litrosActual,
    required this.litrosAnterior,
    required this.variacionPct,
  });
}
