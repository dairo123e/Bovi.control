import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'config/design_tokens.dart';
import 'services/connectivity_service.dart';
import 'services/offline_outbox_service.dart';
import 'widgets/ui/app_background.dart';
import 'widgets/ui/empty_state_card.dart';
import 'widgets/ui/section_title.dart';

class DashboardGanaderoPage extends StatefulWidget {
  const DashboardGanaderoPage({super.key});

  @override
  State<DashboardGanaderoPage> createState() => _DashboardGanaderoPageState();
}

class _DashboardGanaderoPageState extends State<DashboardGanaderoPage> {
  static const String _cacheKey = 'dashboard_cache_v1';
  Map<String, dynamic> _lastData = const <String, dynamic>{};

  CollectionReference<Map<String, dynamic>> get _animalesRef =>
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(kTenantId)
          .collection('animales');

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  double _pendingLitros(
    List<OutboxItem> items,
    String uid,
    int days,
  ) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));

    double total = 0;
    for (final item in items) {
      if (item.type != 'produccion_create') continue;
      final payloadUid = (item.payload['uid'] ?? '').toString();
      if (payloadUid != uid) continue;

      final fechaMillis = ((item.payload['fechaMillis'] ?? 0) as num).toInt();
      final fecha = DateTime.fromMillisecondsSinceEpoch(fechaMillis);
      if (fecha.isBefore(start)) continue;

      total += ((item.payload['litros'] ?? 0) as num).toDouble();
    }

    return total;
  }

  List<_TopItem> _mergeTopWithPending(
    List<_TopItem> baseTop,
    List<OutboxItem> items,
    String uid,
  ) {
    final now = DateTime.now();
    final start30 = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 29));

    final byAnimal = <String, _TopItem>{
      for (final t in baseTop)
        t.animalId: _TopItem(
          animalId: t.animalId,
          nombre: t.nombre,
          litros: t.litros,
        ),
    };

    for (final item in items) {
      if (item.type != 'produccion_create') continue;
      final payload = item.payload;
      if ((payload['uid'] ?? '').toString() != uid) continue;

      final fechaMillis = ((payload['fechaMillis'] ?? 0) as num).toInt();
      final fecha = DateTime.fromMillisecondsSinceEpoch(fechaMillis);
      if (fecha.isBefore(start30)) continue;

      final animalId = (payload['animalId'] ?? '').toString();
      final animalNombre = (payload['animalNombre'] ?? 'Sin nombre').toString();
      final litros = ((payload['litros'] ?? 0) as num).toDouble();

      final current = byAnimal[animalId] ??
          _TopItem(animalId: animalId, nombre: animalNombre, litros: 0);
      byAnimal[animalId] = _TopItem(
        animalId: animalId,
        nombre: animalNombre,
        litros: current.litros + litros,
      );
    }

    final merged = byAnimal.values.toList()
      ..sort((a, b) => b.litros.compareTo(a.litros));
    return merged.take(5).toList();
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final topRaw = (map['top'] as List<dynamic>? ?? const <dynamic>[]);
      final top = topRaw
          .whereType<Map>()
          .map(
            (e) => _TopItem(
              animalId: (e['animalId'] ?? '').toString(),
              nombre: (e['nombre'] ?? 'Sin nombre').toString(),
              litros: ((e['litros'] ?? 0) as num).toDouble(),
            ),
          )
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _lastData = {
          'totalVacas': ((map['totalVacas'] ?? 0) as num).toInt(),
          'litros7': ((map['litros7'] ?? 0) as num).toDouble(),
          'litros30': ((map['litros30'] ?? 0) as num).toDouble(),
          'top': top,
        };
      });
    } catch (_) {
      // Ignora cache invalida y usa carga normal.
    }
  }

  Future<void> _saveCachedData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final top = (data['top'] as List<_TopItem>? ?? const <_TopItem>[])
        .map(
          (t) => {
            'animalId': t.animalId,
            'nombre': t.nombre,
            'litros': t.litros,
          },
        )
        .toList(growable: false);

    final payload = {
      'totalVacas': data['totalVacas'] ?? 0,
      'litros7': data['litros7'] ?? 0,
      'litros30': data['litros30'] ?? 0,
      'top': top,
    };
    await prefs.setString(_cacheKey, jsonEncode(payload));
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
        title: const Text('Dashboard Ganadero'),
      ),
      body: AppBackground(
        child: ValueListenableBuilder<bool>(
          valueListenable: ConnectivityService.instance.isOffline,
          builder: (context, offline, _) {
            return ValueListenableBuilder<List<OutboxItem>>(
              valueListenable: OfflineOutboxService.instance.items,
              builder: (context, outboxItems, __) {
                final Future<Map<String, dynamic>> future =
                    (offline && _lastData.isNotEmpty)
                        ? Future.value(_lastData)
                        : _loadData(user.uid);

                return FutureBuilder<Map<String, dynamic>>(
                  future: future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        _lastData.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError && _lastData.isEmpty) {
                      return Center(child: Text('Error: ${snap.error}'));
                    }

                    if (!offline && snap.hasData) {
                      final incoming = snap.data!;
                      final incomingVacas =
                          (incoming['totalVacas'] as int? ?? 0);
                      final cachedVacas =
                          (_lastData['totalVacas'] as int? ?? 0);

                      // Evita reemplazar cache estable por lecturas parciales transitorias.
                      final shouldAccept =
                          incomingVacas > 0 || cachedVacas == 0;
                      if (shouldAccept) {
                        _lastData = incoming;
                        _saveCachedData(incoming);
                      }
                    }

                    final data = snap.data ?? _lastData;
                    final totalVacas = data['totalVacas'] as int? ?? 0;
                    final litros7Base = data['litros7'] as double? ?? 0;
                    final litros30Base = data['litros30'] as double? ?? 0;
                    final topBase = (data['top'] as List<_TopItem>? ?? []);

                    final litros7 =
                        litros7Base + _pendingLitros(outboxItems, user.uid, 7);
                    final litros30 = litros30Base +
                        _pendingLitros(outboxItems, user.uid, 30);
                    final top =
                        _mergeTopWithPending(topBase, outboxItems, user.uid);

                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                      },
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          if (offline && _lastData.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Mostrando dashboard en cache con pendientes locales.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: _kpiCard(
                                    'Vacas', '$totalVacas', Icons.pets),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: _kpiCard(
                                  'Produccion 7d',
                                  '${litros7.toStringAsFixed(1)} L',
                                  Icons.calendar_view_week,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _kpiCard(
                            'Produccion 30d',
                            '${litros30.toStringAsFixed(1)} L',
                            Icons.calendar_month,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const SectionTitle(
                              text: 'Top vacas por produccion (30 dias)'),
                          const SizedBox(height: 8),
                          if (top.isEmpty)
                            const EmptyStateCard(
                              message: 'Sin datos de produccion suficientes.',
                            )
                          else
                            ...top.map((t) => Card(
                                  child: ListTile(
                                    leading:
                                        const Icon(Icons.emoji_events_outlined),
                                    title: Text(t.nombre),
                                    subtitle: Text('Animal ID: ${t.animalId}'),
                                    trailing: Text(
                                        '${t.litros.toStringAsFixed(1)} L'),
                                  ),
                                )),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
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

  Future<Map<String, dynamic>> _loadData(String uid) async {
    final vacasSnap =
        await _animalesRef.where('creadoPor', isEqualTo: uid).get();
    final totalVacas = vacasSnap.docs.length;

    final now = DateTime.now();
    final start7 = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final start30 = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 29));

    double litros7 = 0;
    double litros30 = 0;
    final byAnimal = <String, _TopItem>{};

    for (final vaca in vacasSnap.docs) {
      final vacaData = vaca.data();
      final animalId = vaca.id;
      final animalNombre = (vacaData['nombre'] ?? 'Sin nombre').toString();

      final prodsSnap = await vaca.reference
          .collection('producciones')
          .where('creadoPor', isEqualTo: uid)
          .get();

      for (final d in prodsSnap.docs) {
        final data = d.data();
        final dt = (data['fecha'] as Timestamp?)?.toDate();
        final litros = ((data['litros'] ?? 0) as num).toDouble();
        if (dt == null) continue;

        if (!dt.isBefore(start7)) litros7 += litros;
        if (!dt.isBefore(start30)) {
          litros30 += litros;
          final current = byAnimal[animalId] ??
              _TopItem(animalId: animalId, nombre: animalNombre, litros: 0);
          byAnimal[animalId] = _TopItem(
            animalId: current.animalId,
            nombre: animalNombre,
            litros: current.litros + litros,
          );
        }
      }
    }

    final top = byAnimal.values.toList()
      ..sort((a, b) => b.litros.compareTo(a.litros));

    return {
      'totalVacas': totalVacas,
      'litros7': litros7,
      'litros30': litros30,
      'top': top.take(5).toList(),
    };
  }
}

class _TopItem {
  final String animalId;
  final String nombre;
  final double litros;

  _TopItem({
    required this.animalId,
    required this.nombre,
    required this.litros,
  });
}
