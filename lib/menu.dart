import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'DashboardGanaderoPage.dart';
import 'EventosTareasPage.dart';
import 'MedicamentosPage.dart';
import 'Notificaciones.dart';
import 'OutboxPage.dart';
import 'ReportesPage.dart';
import 'SoportePage.dart';
import 'TusFincas.dart';
import 'TusVacas.dart';
import 'config/app_config.dart';
import 'config/design_tokens.dart';
import 'perfil.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/offline_outbox_service.dart';
import 'widgets/menu/menu_components.dart';
import 'widgets/menu/menu_option.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _litrosCtrl = TextEditingController();
  final _authSvc = AuthService();
  String _query = '';
  String? _animalIdSeleccionado;
  bool _guardandoLeche = false;
  int _bottomIndex = 0;
  bool _guardandoHeroFoto = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lastVacasDocs = [];
  Map<String, String> _nombresVacasCache = <String, String>{};
  Map<String, dynamic> _lastDashboardData = const <String, dynamic>{};

  late final List<MenuOption> _allOptions = [
    MenuOption.icon(
      title: 'Dashboard',
      icon: Icons.analytics_outlined,
      color: Colors.green,
      page: const DashboardGanaderoPage(),
    ),
    MenuOption.icon(
      title: 'Perfil',
      icon: Icons.person,
      color: Colors.blue,
      page: PerfilPage(),
    ),
    MenuOption.icon(
      title: 'Eventos y Tareas',
      icon: Icons.event,
      color: Colors.orange,
      page: EventosTareasPage(),
    ),
    MenuOption.asset(
      title: 'Tus Vacas',
      assetPath: 'assets/logo vaca.jpg',
      color: Colors.brown,
      page: TusVacasPage(),
    ),
    MenuOption.icon(
      title: 'Tus Fincas',
      icon: Icons.landscape,
      color: Colors.teal,
      page: TusFincasPage(),
    ),
    MenuOption.icon(
      title: 'Notificaciones',
      icon: Icons.notifications,
      color: Colors.red,
      page: NotificacionesPage(),
    ),
    MenuOption.icon(
      title: 'Medicamentos',
      icon: Icons.medication,
      color: Colors.indigo,
      page: const MedicamentosPage(),
    ),
    MenuOption.icon(
      title: 'Reportes',
      icon: Icons.summarize_outlined,
      color: Colors.cyan,
      page: const ReportesPage(),
    ),
    MenuOption.icon(
      title: 'Soporte',
      icon: Icons.support_agent,
      color: Colors.purple,
      page: const SoportePage(),
    ),
    MenuOption.icon(
      title: 'Sincronizacion',
      icon: Icons.sync,
      color: Colors.blueGrey,
      page: const OutboxPage(),
    ),
  ];

  DocumentReference<Map<String, dynamic>>? get _userRef {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .doc('tenants/$kTenantId/users/${user.uid}');
  }

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    _litrosCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadDashboardData(String uid) async {
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
    for (final vaca in vacasSnap.docs) {
      final prodsSnap = await vaca.reference
          .collection('producciones')
          .where('creadoPor', isEqualTo: uid)
          .get();
      for (final p in prodsSnap.docs) {
        final data = p.data();
        final dt = (data['fecha'] as Timestamp?)?.toDate();
        if (dt == null) continue;
        final litros = ((data['litros'] ?? 0) as num).toDouble();
        if (!dt.isBefore(start7)) litros7 += litros;
        if (!dt.isBefore(start30)) litros30 += litros;
      }
    }

    return {
      'totalVacas': totalVacas,
      'litros7': litros7,
      'litros30': litros30,
    };
  }

  Future<void> _registroRapidoLeche({
    required User user,
    required bool canManage,
  }) async {
    if (!canManage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu rol es solo lectura.')),
      );
      return;
    }
    if (_guardandoLeche) return;
    if (_animalIdSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecciona una vaca para registrar leche.')),
      );
      return;
    }
    final litros = double.tryParse(_litrosCtrl.text.trim());
    if (litros == null || litros <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un valor valido de litros.')),
      );
      return;
    }

    final operationId =
        'prod_${user.uid}_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';

    setState(() => _guardandoLeche = true);
    try {
      final animalId = _animalIdSeleccionado!;
      final animalNombre =
          _nombresVacasCache[animalId]?.trim().isNotEmpty == true
              ? _nombresVacasCache[animalId]!
              : 'Sin nombre';
      final fecha = DateTime.now();

      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final prodDoc = _animalesRef
          .doc(animalId)
          .collection('producciones')
          .doc(operationId);
      final eventoDoc = _eventosRef.doc('${operationId}_event');

      batch.set(
          prodDoc,
          {
            'fecha': Timestamp.fromDate(fecha),
            'litros': litros,
            'animalId': animalId,
            'animalNombre': animalNombre,
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
                'Se registraron ${litros.toStringAsFixed(1)} L para $animalNombre.',
            'fecha': Timestamp.fromDate(fecha),
            'animalId': animalId,
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
        const SnackBar(
            content: Text('Registro diario guardado correctamente.')),
      );
      setState(() {});
    } catch (e) {
      final animalId = _animalIdSeleccionado!;
      final animalNombre =
          _nombresVacasCache[animalId]?.trim().isNotEmpty == true
              ? _nombresVacasCache[animalId]!
              : 'Sin nombre';
      await OfflineOutboxService.instance.enqueueProduccionCreate(
        uid: user.uid,
        animalId: animalId,
        animalNombre: animalNombre,
        litros: litros,
        fechaMillis: DateTime.now().millisecondsSinceEpoch,
        operationId: operationId,
      );

      _litrosCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Guardado localmente. Se sincronizara al reconectar.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardandoLeche = false);
    }
  }

  ImageProvider<Object>? _resolveBgImage(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> vacas,
  ) {
    for (final d in vacas) {
      final data = d.data();
      final fotoBase64 = (data['fotoBase64'] ?? '').toString();
      final fotoUrl = (data['fotoUrl'] ?? '').toString();
      if (fotoBase64.isNotEmpty) {
        try {
          return MemoryImage(base64Decode(fotoBase64));
        } catch (_) {
          // ignore decode errors and continue
        }
      }
      if (fotoUrl.isNotEmpty) return NetworkImage(fotoUrl);
    }
    return null;
  }

  ImageProvider<Object>? _resolveHeroImage(
    Map<String, dynamic> userData,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> vacas,
  ) {
    final heroBase64 = (userData['heroPhotoBase64'] ?? '').toString();
    final heroUrl = (userData['heroPhotoUrl'] ?? '').toString();
    if (heroBase64.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(heroBase64));
      } catch (_) {
        // ignore decode errors
      }
    }
    if (heroUrl.isNotEmpty) return NetworkImage(heroUrl);
    return _resolveBgImage(vacas);
  }

  ImageProvider<Object>? _resolveUserAvatar(Map<String, dynamic> userData) {
    final photoBase64 = (userData['photoBase64'] ?? '').toString();
    final photoUrl =
        (userData['photoUrl'] ?? userData['fotoUrl'] ?? '').toString();
    if (photoBase64.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(photoBase64));
      } catch (_) {
        // ignore decode errors
      }
    }
    if (photoUrl.isNotEmpty) return NetworkImage(photoUrl);
    return null;
  }

  Future<void> _pickHeroImage({
    required User user,
    required bool canManage,
  }) async {
    if (!canManage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu rol es solo lectura.')),
      );
      return;
    }
    if (_guardandoHeroFoto) return;
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1400,
    );
    if (image == null) return;

    final Uint8List bytes = await image.readAsBytes();
    if (bytes.lengthInBytes > 420000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La foto es muy pesada. Elige una imagen mas liviana.'),
        ),
      );
      return;
    }

    setState(() => _guardandoHeroFoto = true);
    try {
      await FirebaseFirestore.instance
          .doc('tenants/$kTenantId/users/${user.uid}')
          .set({
        'heroPhotoBase64': base64Encode(bytes),
        'heroPhotoUrl': '',
        'heroPhotoUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto del resumen actualizada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar la foto. Intenta de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardandoHeroFoto = false);
    }
  }

  double _pendingProduccionLitros(
    List<OutboxItem> outboxItems,
    String uid,
    int days,
  ) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));

    double total = 0;
    for (final item in outboxItems) {
      if (item.type != 'produccion_create') continue;

      final payloadUid = (item.payload['uid'] ?? '').toString();
      if (payloadUid != uid) continue;

      final fechaMillis = ((item.payload['fechaMillis'] ?? 0) as num).toInt();
      final fecha = DateTime.fromMillisecondsSinceEpoch(fechaMillis);
      if (fecha.isBefore(start)) continue;

      final litros = ((item.payload['litros'] ?? 0) as num).toDouble();
      total += litros;
    }

    return total;
  }

  String _formatTiempoRelativo(DateTime fecha) {
    final diff = DateTime.now().difference(fecha);
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes.clamp(1, 59);
      return 'Hace $mins min';
    }
    if (diff.inHours < 24) {
      return 'Hace ${diff.inHours} horas';
    }
    return 'Hace ${diff.inDays} dias';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1100
        ? 4
        : width >= 800
            ? 3
            : 2;

    final userRef = _userRef;
    if (userRef == null) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesion para acceder al menu.')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, userSnap) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return const Scaffold(
            body: Center(
                child: Text('Debes iniciar sesion para acceder al menu.')),
          );
        }

        final userData = userSnap.data?.data() ?? {};
        final roleRaw =
            (userData['role'] ?? userData['rol'] ?? 'ganadero').toString();
        final role = roleRaw.trim().toLowerCase();
        final canManage = role == 'ganadero';

        final visibleOptions = role == 'veterinario'
            ? _allOptions.where((o) => o.title != 'Tus Fincas').toList()
            : _allOptions;
        const bottomNavTitles = {
          'Dashboard',
          'Tus Vacas',
          'Eventos y Tareas',
          'Notificaciones',
        };
        const drawerTitles = {
          'Perfil',
          'Tus Fincas',
          'Sincronizacion',
          'Soporte',
        };
        final baseList = _query.isEmpty
            ? visibleOptions
                .where((o) => !bottomNavTitles.contains(o.title))
                .where((o) => !drawerTitles.contains(o.title))
                .toList()
            : visibleOptions
                .where((o) => o.title.toLowerCase().contains(_query))
                .where((o) => !bottomNavTitles.contains(o.title))
                .where((o) => !drawerTitles.contains(o.title))
                .toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Bovi Control'),
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      role,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withOpacity(0.18),
                  backgroundImage: _resolveUserAvatar(userData),
                  child: _resolveUserAvatar(userData) == null
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
              ),
              IconButton(
                tooltip: 'Cerrar sesión',
                icon: const Icon(Icons.logout),
                onPressed: () async => _authSvc.signOut(),
              ),
            ],
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brandForest, AppColors.brandLeaf],
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        backgroundImage: _resolveUserAvatar(userData),
                        child: _resolveUserAvatar(userData) == null
                            ? const Icon(Icons.person,
                                color: AppColors.textMuted)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              (userData['displayName'] ??
                                      user.displayName ??
                                      'Usuario')
                                  .toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rol: $role',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Perfil'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PerfilPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.landscape),
                  title: const Text('Tus fincas'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => TusFincasPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Sincronizacion'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OutboxPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: const Text('Contacto y soporte'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SoportePage()),
                    );
                  },
                ),
              ],
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE7F4EA),
                  Color(0xFFF4F8F2),
                ],
              ),
            ),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _animalesRef
                  .where('creadoPor', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, animalSnap) {
                final liveVacas = animalSnap.data?.docs ?? [];
                if (liveVacas.isNotEmpty) {
                  _lastVacasDocs = liveVacas;
                }
                final vacas = liveVacas.isNotEmpty ? liveVacas : _lastVacasDocs;
                _nombresVacasCache = {
                  for (final d in vacas)
                    d.id: (d.data()['nombre'] ?? 'Sin nombre').toString(),
                };
                if (_animalIdSeleccionado == null && vacas.isNotEmpty) {
                  _animalIdSeleccionado = vacas.first.id;
                }
                if (_animalIdSeleccionado != null &&
                    vacas.isNotEmpty &&
                    !vacas.any((d) => d.id == _animalIdSeleccionado)) {
                  _animalIdSeleccionado = vacas.first.id;
                }
                final bgImage = _resolveHeroImage(userData, vacas);

                return ValueListenableBuilder<bool>(
                  valueListenable: ConnectivityService.instance.isOffline,
                  builder: (context, offline, __) {
                    return ValueListenableBuilder<List<OutboxItem>>(
                      valueListenable: OfflineOutboxService.instance.items,
                      builder: (context, outboxItems, ___) {
                        final pendingLitros7 =
                            _pendingProduccionLitros(outboxItems, user.uid, 7);
                        final pendingLitros30 =
                            _pendingProduccionLitros(outboxItems, user.uid, 30);

                        final Future<Map<String, dynamic>> future =
                            (offline && _lastDashboardData.isNotEmpty)
                                ? Future.value(_lastDashboardData)
                                : _loadDashboardData(user.uid);

                        return FutureBuilder<Map<String, dynamic>>(
                          future: future,
                          builder: (context, kpiSnap) {
                            if (!offline && kpiSnap.hasData) {
                              _lastDashboardData = kpiSnap.data!;
                            }

                            final kpi = offline
                                ? (_lastDashboardData.isNotEmpty
                                    ? _lastDashboardData
                                    : (kpiSnap.data ??
                                        const <String, dynamic>{}))
                                : (kpiSnap.data ??
                                    (_lastDashboardData.isNotEmpty
                                        ? _lastDashboardData
                                        : const <String, dynamic>{}));
                            final totalVacas = kpi['totalVacas'] as int? ?? 0;
                            final litros7 = (kpi['litros7'] as double? ?? 0) +
                                pendingLitros7;
                            final litros30 = (kpi['litros30'] as double? ?? 0) +
                                pendingLitros30;

                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.95, end: 1),
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOut,
                              builder: (context, scale, child) {
                                return Transform.scale(
                                    scale: scale, child: child);
                              },
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    HeroDashboardCard(
                                      role: role,
                                      totalVacas: totalVacas,
                                      litros7: litros7,
                                      litros30: litros30,
                                      bgImage: bgImage,
                                      onChangePhoto: () {
                                        _pickHeroImage(
                                          user: user,
                                          canManage: canManage,
                                        );
                                      },
                                    ),
                                    if (offline &&
                                        _lastDashboardData.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.cloud_off,
                                                size: 18,
                                                color: Colors.blueGrey.shade700,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Mostrando resumen de produccion en cache hasta reconectar.',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors
                                                        .blueGrey.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (pendingLitros30 > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.orange.withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.sync,
                                                size: 18,
                                                color: Colors.orange.shade800,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Incluye ${pendingLitros30.toStringAsFixed(1)} L pendientes de sincronizar.',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        Colors.orange.shade800,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: AppSpacing.lg),
                                    SearchBarMenu(
                                      controller: _searchCtrl,
                                      hintText:
                                          'Buscar modulo, ejemplo: reportes',
                                      onChanged: (txt) => setState(
                                        () => _query = txt.trim().toLowerCase(),
                                      ),
                                      onClear: () {
                                        _searchCtrl.clear();
                                        setState(() => _query = '');
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: const [
                                        HintChip(label: 'Produccion diaria'),
                                        HintChip(label: 'Eventos'),
                                        HintChip(label: 'Medicamentos'),
                                        HintChip(label: 'Soporte'),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    QuickLecheCard(
                                      vacas: vacas,
                                      canManage: canManage,
                                      litrosCtrl: _litrosCtrl,
                                      animalIdSeleccionado:
                                          _animalIdSeleccionado,
                                      guardandoLeche: _guardandoLeche,
                                      onAnimalChanged: (v) => setState(
                                          () => _animalIdSeleccionado = v),
                                      onRegistrar: () => _registroRapidoLeche(
                                        user: user,
                                        canManage: canManage,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Actividad reciente',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    NotificacionesPage(),
                                              ),
                                            );
                                          },
                                          child: const Text('Ver todo'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    StreamBuilder<
                                        QuerySnapshot<Map<String, dynamic>>>(
                                      stream: _eventosRef
                                          .where('creadoPor',
                                              isEqualTo: user.uid)
                                          .snapshots(),
                                      builder: (context, eventosSnap) {
                                        if (eventosSnap.connectionState ==
                                            ConnectionState.waiting) {
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        }
                                        if (eventosSnap.hasError) {
                                          return Text(
                                            'Error cargando eventos: ${eventosSnap.error}',
                                          );
                                        }

                                        final now = DateTime.now();
                                        final hoy = DateTime(
                                            now.year, now.month, now.day);
                                        final max =
                                            hoy.add(const Duration(days: 7));

                                        final eventos =
                                            (eventosSnap.data?.docs ?? [])
                                                .where((d) {
                                          final data = d.data();
                                          final tipo = (data['tipo'] ?? '')
                                              .toString()
                                              .toLowerCase();
                                          if (!tipo.contains('vacun') &&
                                              !tipo.contains('parto')) {
                                            return false;
                                          }
                                          final fecha =
                                              (data['fecha'] as Timestamp?)
                                                  ?.toDate();
                                          if (fecha == null) return false;
                                          final fechaDia = DateTime(
                                            fecha.year,
                                            fecha.month,
                                            fecha.day,
                                          );
                                          return !fechaDia.isBefore(hoy) &&
                                              !fechaDia.isAfter(max);
                                        }).toList();

                                        return StreamBuilder<
                                            QuerySnapshot<
                                                Map<String, dynamic>>>(
                                          stream: _tareasRef
                                              .where('creadoPor',
                                                  isEqualTo: user.uid)
                                              .where('estado',
                                                  isEqualTo: 'pendiente')
                                              .snapshots(),
                                          builder: (context, tareasSnap) {
                                            if (tareasSnap.connectionState ==
                                                ConnectionState.waiting) {
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            }
                                            if (tareasSnap.hasError) {
                                              return Text(
                                                'Error cargando tareas: ${tareasSnap.error}',
                                              );
                                            }

                                            final tasks =
                                                tareasSnap.data?.docs ?? [];

                                            final items =
                                                <Map<String, dynamic>>[
                                              for (final t in tasks)
                                                {
                                                  'title':
                                                      (t.data()['titulo'] ??
                                                              'Tarea')
                                                          .toString(),
                                                  'description': (t.data()[
                                                              'descripcion'] ??
                                                          '')
                                                      .toString(),
                                                  'date': (t.data()['fecha']
                                                          as Timestamp?)
                                                      ?.toDate(),
                                                  'tone': 'tarea',
                                                },
                                              for (final e in eventos)
                                                {
                                                  'title':
                                                      (e.data()['titulo'] ??
                                                              'Evento')
                                                          .toString(),
                                                  'description': (e.data()[
                                                              'descripcion'] ??
                                                          '')
                                                      .toString(),
                                                  'date': (e.data()['fecha']
                                                          as Timestamp?)
                                                      ?.toDate(),
                                                  'tone': (e.data()['tipo'] ??
                                                          'evento')
                                                      .toString(),
                                                },
                                            ];

                                            items.sort((a, b) {
                                              final aDate =
                                                  a['date'] as DateTime?;
                                              final bDate =
                                                  b['date'] as DateTime?;
                                              if (aDate == null &&
                                                  bDate == null) {
                                                return 0;
                                              }
                                              if (aDate == null) return 1;
                                              if (bDate == null) return -1;
                                              return aDate.compareTo(bDate);
                                            });

                                            final limited =
                                                items.take(4).toList();
                                            if (limited.isEmpty) {
                                              return Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.all(14),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: AppColors.brandForest
                                                        .withOpacity(0.08),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Sin actividades pendientes.',
                                                  style: TextStyle(
                                                    color: AppColors.textMuted,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              );
                                            }

                                            return Column(
                                              children: limited.map((item) {
                                                final fecha =
                                                    item['date'] as DateTime?;
                                                final tiempo = fecha == null
                                                    ? 'Sin fecha'
                                                    : _formatTiempoRelativo(
                                                        fecha,
                                                      );
                                                final descripcion =
                                                    (item['description']
                                                            as String)
                                                        .trim();
                                                final tone =
                                                    (item['tone'] as String)
                                                        .toLowerCase();
                                                final subtitle = descripcion
                                                        .isEmpty
                                                    ? 'Para: $tiempo'
                                                    : '$descripcion\nPara: $tiempo';

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 10),
                                                  child: ActivityItemCard(
                                                    title:
                                                        item['title'] as String,
                                                    subtitle: subtitle,
                                                    tone: tone,
                                                    onTap: () {
                                                      Navigator.of(context)
                                                          .push(
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              NotificacionesPage(),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                );
                                              }).toList(),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    Text(
                                      _query.isEmpty
                                          ? 'Accesos rapidos'
                                          : 'Resultados: ${baseList.length}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    GridView.builder(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      shrinkWrap: true,
                                      itemCount: baseList.length,
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 14,
                                        childAspectRatio: 1.08,
                                      ),
                                      itemBuilder: (context, i) {
                                        final option = baseList[i];
                                        return MenuTile(option: option);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _bottomIndex,
            selectedItemColor: AppColors.brandForest,
            unselectedItemColor: AppColors.textMuted,
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              setState(() => _bottomIndex = index);
              if (index == 0) return;
              if (index == 1) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TusVacasPage()),
                );
                return;
              }
              if (index == 2) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EventosTareasPage()),
                );
                return;
              }
              if (index == 3) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => NotificacionesPage()),
                );
              }
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_filled),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.pets),
                label: 'Tus vacas',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.event),
                label: 'Eventos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications),
                label: 'Alertas',
              ),
            ],
          ),
        );
      },
    );
  }
}
