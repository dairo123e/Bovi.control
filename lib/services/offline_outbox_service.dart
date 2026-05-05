import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'connectivity_service.dart';

class OutboxItem {
  OutboxItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    required this.nextRetryAt,
    this.lastError,
  });

  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final int createdAt;
  final int attempts;
  final int nextRetryAt;
  final String? lastError;

  DateTime get createdAtDate => DateTime.fromMillisecondsSinceEpoch(createdAt);

  DateTime get nextRetryAtDate =>
      DateTime.fromMillisecondsSinceEpoch(nextRetryAt);

  bool get waitingForRetry =>
      nextRetryAt > 0 && DateTime.now().millisecondsSinceEpoch < nextRetryAt;

  String get title {
    if (type == 'evento_create') {
      return 'Evento: ${(payload['titulo'] ?? '').toString()}';
    }
    if (type == 'evento_update') {
      return 'Actualizar evento';
    }
    if (type == 'evento_delete') {
      return 'Eliminar evento';
    }
    if (type == 'tarea_create') {
      return 'Tarea: ${(payload['titulo'] ?? '').toString()}';
    }
    if (type == 'tarea_update') {
      return 'Actualizar tarea';
    }
    if (type == 'tarea_toggle_estado') {
      return 'Cambiar estado de tarea';
    }
    if (type == 'tarea_delete') {
      return 'Eliminar tarea';
    }
    if (type == 'medicamento_create') {
      return 'Tratamiento: ${(payload['nombreMedicamento'] ?? '').toString()}';
    }
    if (type == 'medicamento_complete') {
      return 'Completar tratamiento';
    }
    if (type == 'medicamento_delete') {
      return 'Eliminar tratamiento';
    }
    if (type == 'produccion_create') {
      return 'Produccion: ${(payload['litros'] ?? 0).toString()} L';
    }
    if (type == 'vaca_create') {
      return 'Vaca: ${(payload['nombre'] ?? '').toString()}';
    }
    if (type == 'vaca_update') {
      return 'Actualizar vaca: ${(payload['nombre'] ?? '').toString()}';
    }
    if (type == 'potrero_create') {
      return 'Registrar potrero';
    }
    if (type == 'vaca_delete') {
      return 'Eliminar vaca';
    }
    if (type == 'finca_create') {
      return 'Finca: ${(payload['nombre'] ?? '').toString()}';
    }
    if (type == 'finca_update') {
      return 'Actualizar finca';
    }
    if (type == 'finca_delete') {
      return 'Eliminar finca';
    }
    if (type == 'support_ticket_create') {
      return 'Ticket: ${(payload['asunto'] ?? '').toString()}';
    }
    if (type == 'support_ticket_update') {
      return 'Actualizar ticket';
    }
    if (type == 'support_ticket_delete') {
      return 'Eliminar ticket';
    }
    if (type == 'perfil_update') {
      return 'Actualizar perfil';
    }
    if (type == 'produccion_delete') {
      return 'Eliminar produccion';
    }
    return type;
  }

  String get subtitle {
    if (type == 'evento_create') {
      return 'Tipo: ${(payload['tipo'] ?? '').toString()}';
    }
    if (type == 'evento_update') {
      return 'Evento ID: ${(payload['eventoId'] ?? '').toString()}';
    }
    if (type == 'tarea_create') {
      return 'Prioridad: ${(payload['prioridad'] ?? '').toString()}';
    }
    if (type == 'tarea_update' || type == 'tarea_toggle_estado') {
      return 'Tarea ID: ${(payload['tareaId'] ?? '').toString()}';
    }
    if (type == 'medicamento_create') {
      return 'Vaca: ${(payload['animalNombre'] ?? '').toString()}';
    }
    if (type == 'medicamento_complete' || type == 'medicamento_delete') {
      return 'Tratamiento ID: ${(payload['medicamentoId'] ?? '').toString()}';
    }
    if (type == 'produccion_create') {
      return 'Vaca: ${(payload['animalNombre'] ?? '').toString()}';
    }
    if (type == 'vaca_create') {
      return 'Raza: ${(payload['raza'] ?? '').toString()}';
    }
    if (type == 'vaca_update') {
      return 'Vaca ID: ${(payload['vacaId'] ?? '').toString()}';
    }
    if (type == 'finca_create' || type == 'finca_update') {
      return 'Ubicacion: ${(payload['ubicacion'] ?? '').toString()}';
    }
    if (type == 'support_ticket_create') {
      return 'Prioridad: ${(payload['prioridad'] ?? '').toString()}';
    }
    if (type == 'support_ticket_update' || type == 'support_ticket_delete') {
      return 'Ticket ID: ${(payload['ticketId'] ?? '').toString()}';
    }
    return '';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'payload': payload,
      'createdAt': createdAt,
      'attempts': attempts,
      'nextRetryAt': nextRetryAt,
      if (lastError != null) 'lastError': lastError,
    };
  }

  static OutboxItem fromMap(Map<String, dynamic> map) {
    return OutboxItem(
      id: (map['id'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      payload: ((map['payload'] as Map?) ?? <String, dynamic>{})
          .cast<String, dynamic>(),
      createdAt: ((map['createdAt'] ?? 0) as num).toInt(),
      attempts: ((map['attempts'] ?? 0) as num).toInt(),
      nextRetryAt: ((map['nextRetryAt'] ?? 0) as num).toInt(),
      lastError: map['lastError']?.toString(),
    );
  }
}

class OfflineOutboxService {
  OfflineOutboxService._();

  static final OfflineOutboxService instance = OfflineOutboxService._();

  static const String _storageKey = 'offline_outbox_v1';
  static const int _maxAttempts = 8;

  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  final ValueNotifier<List<OutboxItem>> items = ValueNotifier<List<OutboxItem>>(
    const <OutboxItem>[],
  );

  bool _initialized = false;
  bool _processing = false;
  SharedPreferences? _prefs;
  VoidCallback? _connectivityListener;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _prefs = await SharedPreferences.getInstance();
    await _refreshNotifiers();

    _connectivityListener = () {
      if (!ConnectivityService.instance.isOffline.value) {
        unawaited(processPending());
      }
    };
    ConnectivityService.instance.isOffline.addListener(_connectivityListener!);

    if (!ConnectivityService.instance.isOffline.value) {
      await processPending();
    }
  }

  Future<void> enqueueEventoCreate({
    required String uid,
    required String titulo,
    required String descripcion,
    required String tipo,
    required String animalId,
    required int fechaMillis,
    String? operationId,
  }) async {
    await _enqueue(
      type: 'evento_create',
      payload: {
        'uid': uid,
        'titulo': titulo,
        'descripcion': descripcion,
        'tipo': tipo,
        'animalId': animalId,
        'fechaMillis': fechaMillis,
      },
      operationId: operationId,
    );
  }

  Future<void> enqueueEventoUpdate({
    required String eventoId,
    required String titulo,
    required String descripcion,
    required String tipo,
    required String animalId,
  }) async {
    await _enqueue(
      type: 'evento_update',
      payload: {
        'eventoId': eventoId,
        'titulo': titulo,
        'descripcion': descripcion,
        'tipo': tipo,
        'animalId': animalId,
      },
    );
  }

  Future<void> enqueueEventoDelete({required String eventoId}) async {
    await _enqueue(
      type: 'evento_delete',
      payload: {'eventoId': eventoId},
    );
  }

  Future<void> enqueueTareaCreate({
    required String uid,
    required String titulo,
    required String descripcion,
    required String estado,
    required String prioridad,
    required String asignadoA,
    required int fechaMillis,
    String? operationId,
  }) async {
    await _enqueue(
      type: 'tarea_create',
      payload: {
        'uid': uid,
        'titulo': titulo,
        'descripcion': descripcion,
        'estado': estado,
        'prioridad': prioridad,
        'asignadoA': asignadoA,
        'fechaMillis': fechaMillis,
      },
      operationId: operationId,
    );
  }

  Future<void> enqueueTareaUpdate({
    required String tareaId,
    required String titulo,
    required String descripcion,
    required String prioridad,
    required String estado,
    required String asignadoA,
  }) async {
    await _enqueue(
      type: 'tarea_update',
      payload: {
        'tareaId': tareaId,
        'titulo': titulo,
        'descripcion': descripcion,
        'prioridad': prioridad,
        'estado': estado,
        'asignadoA': asignadoA,
      },
    );
  }

  Future<void> enqueueTareaToggleEstado({
    required String tareaId,
    required String estado,
  }) async {
    await _enqueue(
      type: 'tarea_toggle_estado',
      payload: {
        'tareaId': tareaId,
        'estado': estado,
      },
    );
  }

  Future<void> enqueueTareaDelete({required String tareaId}) async {
    await _enqueue(
      type: 'tarea_delete',
      payload: {'tareaId': tareaId},
    );
  }

  Future<void> enqueueMedicamentoCreate({
    required String uid,
    required String userEmailOrUid,
    required String nombreMedicamento,
    required String dosis,
    required String observaciones,
    required String animalId,
    required String animalNombre,
    required int fechaAplicacionMillis,
    int? fechaProximaMillis,
    String? operationId,
  }) async {
    await _enqueue(
      type: 'medicamento_create',
      payload: {
        'uid': uid,
        'userEmailOrUid': userEmailOrUid,
        'nombreMedicamento': nombreMedicamento,
        'dosis': dosis,
        'observaciones': observaciones,
        'animalId': animalId,
        'animalNombre': animalNombre,
        'fechaAplicacionMillis': fechaAplicacionMillis,
        'fechaProximaMillis': fechaProximaMillis,
      },
      operationId: operationId,
    );
  }

  Future<void> enqueueMedicamentoComplete({
    required String medicamentoId,
  }) async {
    await _enqueue(
      type: 'medicamento_complete',
      payload: {'medicamentoId': medicamentoId},
    );
  }

  Future<void> enqueueMedicamentoDelete({
    required String medicamentoId,
  }) async {
    await _enqueue(
      type: 'medicamento_delete',
      payload: {'medicamentoId': medicamentoId},
    );
  }

  Future<void> enqueueProduccionCreate({
    required String uid,
    required String animalId,
    required String animalNombre,
    required double litros,
    required int fechaMillis,
    String? operationId,
  }) async {
    await _enqueue(
      type: 'produccion_create',
      payload: {
        'uid': uid,
        'animalId': animalId,
        'animalNombre': animalNombre,
        'litros': litros,
        'fechaMillis': fechaMillis,
      },
      operationId: operationId,
    );
  }

  Future<void> enqueueProduccionDelete({
    required String animalId,
    required String produccionId,
  }) async {
    await _enqueue(
      type: 'produccion_delete',
      payload: {
        'animalId': animalId,
        'produccionId': produccionId,
      },
    );
  }

  Future<void> enqueueVacaCreate({
    required String uid,
    required String nombre,
    required String raza,
    required int fechaNacimientoMillis,
    required int cantidadPartos,
    required double promedioProduccion,
    required String vacunas,
    required String fotoUrl,
    required String fotoBase64,
    required String sexo,
    required String estado,
    required String estadoReproductivo,
    required String fincaId,
    required String potreroId,
    String? operationId,
  }) async {
    await _enqueue(
      type: 'vaca_create',
      payload: {
        'uid': uid,
        'nombre': nombre,
        'raza': raza,
        'sexo': sexo,
        'estado': estado,
        'estadoReproductivo': estadoReproductivo,
        'fechaNacimientoMillis': fechaNacimientoMillis,
        'cantidadPartos': cantidadPartos,
        'promedioProduccion': promedioProduccion,
        'vacunas': vacunas,
        'fotoUrl': fotoUrl,
        'fotoBase64': fotoBase64,
        'fincaId': fincaId,
        'potreroId': potreroId,
      },
      operationId: operationId,
    );
  }

  Future<void> enqueueVacaDelete({
    required String vacaId,
  }) async {
    await _enqueue(
      type: 'vaca_delete',
      payload: {
        'vacaId': vacaId,
      },
    );
  }

  Future<void> enqueueVacaUpdate({
    required String vacaId,
    required String nombre,
    required String raza,
    required String sexo,
    required String estado,
    required String estadoReproductivo,
    required int fechaNacimientoMillis,
    required int cantidadPartos,
    required double promedioProduccion,
    required String vacunas,
    required String fincaId,
    required String potreroId,
    String? fotoBase64,
  }) async {
    await _enqueue(
      type: 'vaca_update',
      payload: {
        'vacaId': vacaId,
        'nombre': nombre,
        'raza': raza,
        'sexo': sexo,
        'estado': estado,
        'estadoReproductivo': estadoReproductivo,
        'fechaNacimientoMillis': fechaNacimientoMillis,
        'cantidadPartos': cantidadPartos,
        'promedioProduccion': promedioProduccion,
        'vacunas': vacunas,
        'fincaId': fincaId,
        'potreroId': potreroId,
        if (fotoBase64 != null) 'fotoBase64': fotoBase64,
      },
    );
  }

  Future<void> enqueueFincaCreate({
    required String propietario,
    required String nombre,
    required String ubicacion,
    required String extensionHa,
    required int cantidadPotreros,
    String? operationId,
  }) async {
    await _enqueue(
      type: 'finca_create',
      payload: {
        'propietario': propietario,
        'nombre': nombre,
        'ubicacion': ubicacion,
        'extensionHa': extensionHa,
        'cantidadPotreros': cantidadPotreros,
      },
      operationId: operationId,
    );
  }

  Future<void> enqueueFincaUpdate({
    required String fincaId,
    required String nombre,
    required String ubicacion,
    required String extensionHa,
    required int cantidadPotreros,
  }) async {
    await _enqueue(
      type: 'finca_update',
      payload: {
        'fincaId': fincaId,
        'nombre': nombre,
        'ubicacion': ubicacion,
        'extensionHa': extensionHa,
        'cantidadPotreros': cantidadPotreros,
      },
    );
  }

  Future<void> enqueuePotreroCreate({
    required String fincaId,
    required String nombre,
    required String descripcion,
    required String estado,
    required String creadoPor,
    String? operationId,
  }) async {
    await _enqueue(
      type: 'potrero_create',
      payload: {
        'fincaId': fincaId,
        'nombre': nombre,
        'descripcion': descripcion,
        'estado': estado,
        'creadoPor': creadoPor,
      },
      operationId: operationId,
    );
  }

  Future<void> enqueueFincaDelete({
    required String fincaId,
  }) async {
    await _enqueue(
      type: 'finca_delete',
      payload: {
        'fincaId': fincaId,
      },
    );
  }

  Future<void> enqueueSupportTicketCreate({
    required String uid,
    required String email,
    required String asunto,
    required String detalle,
    required String prioridad,
    String? operationId,
  }) async {
    await _enqueue(
      type: 'support_ticket_create',
      payload: {
        'uid': uid,
        'email': email,
        'asunto': asunto,
        'detalle': detalle,
        'prioridad': prioridad,
      },
      operationId: operationId,
    );
  }

  Future<void> enqueueSupportTicketUpdate({
    required String ticketId,
    required String asunto,
    required String detalle,
    required String prioridad,
  }) async {
    await _enqueue(
      type: 'support_ticket_update',
      payload: {
        'ticketId': ticketId,
        'asunto': asunto,
        'detalle': detalle,
        'prioridad': prioridad,
      },
    );
  }

  Future<void> enqueueSupportTicketDelete({
    required String ticketId,
  }) async {
    await _enqueue(
      type: 'support_ticket_delete',
      payload: {
        'ticketId': ticketId,
      },
    );
  }

  Future<void> enqueuePerfilUpdate({
    required String uid,
    required String displayName,
    required String nombreGanadero,
    required String nombreFinca,
    required String ubicacionFinca,
    required int numeroCabezas,
    required String tipoGanado,
    String? photoUrl,
    String? photoBase64,
  }) async {
    await _enqueue(
      type: 'perfil_update',
      payload: {
        'uid': uid,
        'displayName': displayName,
        'nombreGanadero': nombreGanadero,
        'nombreFinca': nombreFinca,
        'ubicacionFinca': ubicacionFinca,
        'numeroCabezas': numeroCabezas,
        'tipoGanado': tipoGanado,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (photoBase64 != null) 'photoBase64': photoBase64,
      },
    );
  }

  Future<void> processPending() async {
    if (_processing) return;
    if (ConnectivityService.instance.isOffline.value) return;

    _processing = true;
    try {
      final currentItems = await _readItems();
      if (currentItems.isEmpty) {
        await _refreshNotifiers();
        return;
      }

      final remaining = <Map<String, dynamic>>[];
      for (final item in currentItems) {
        if (!_isDue(item)) {
          remaining.add(item);
          continue;
        }

        try {
          await _processOne(item);
        } catch (e) {
          remaining.add(_withFailureMetadata(item, e));
        }
      }

      await _writeItems(remaining);
      await _refreshNotifiers();
    } finally {
      _processing = false;
    }
  }

  Future<void> processItemById(String id) async {
    if (ConnectivityService.instance.isOffline.value) return;
    final current = await _readItems();
    final idx = current.indexWhere((e) => (e['id'] ?? '').toString() == id);
    if (idx < 0) return;

    final target = Map<String, dynamic>.from(current[idx]);
    try {
      await _processOne(target);
      current.removeAt(idx);
    } catch (e) {
      current[idx] = _withFailureMetadata(target, e);
    }

    await _writeItems(current);
    await _refreshNotifiers();
  }

  Future<void> removeItemById(String id) async {
    final current = await _readItems();
    current.removeWhere((e) => (e['id'] ?? '').toString() == id);
    await _writeItems(current);
    await _refreshNotifiers();
  }

  Future<void> clearAll() async {
    await _writeItems(const <Map<String, dynamic>>[]);
    await _refreshNotifiers();
  }

  Future<void> _processOne(Map<String, dynamic> item) async {
    final type = (item['type'] ?? '').toString();
    final payload = (item['payload'] as Map).cast<String, dynamic>();

    final db = FirebaseFirestore.instance;
    final opId = (item['opId'] ?? item['id'] ?? '').toString();

    if (type == 'evento_create') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('eventos')
          .doc(opId)
          .set({
        'titulo': (payload['titulo'] ?? '').toString(),
        'descripcion': (payload['descripcion'] ?? '').toString(),
        'fecha': Timestamp.fromMillisecondsSinceEpoch(
          (payload['fechaMillis'] ?? 0) as int,
        ),
        'animalId': (payload['animalId'] ?? '').toString(),
        'tipo': (payload['tipo'] ?? '').toString(),
        'creadoPor': (payload['uid'] ?? '').toString(),
        'updatedAt': FieldValue.serverTimestamp(),
        'sourceOperationId': opId,
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    if (type == 'evento_update') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('eventos')
          .doc((payload['eventoId'] ?? '').toString())
          .set({
        'titulo': (payload['titulo'] ?? '').toString(),
        'descripcion': (payload['descripcion'] ?? '').toString(),
        'tipo': (payload['tipo'] ?? '').toString(),
        'animalId': (payload['animalId'] ?? '').toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    if (type == 'evento_delete') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('eventos')
          .doc((payload['eventoId'] ?? '').toString())
          .delete();
      return;
    }

    if (type == 'potrero_create') {
      final fincaId = (payload['fincaId'] ?? '').toString();
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('fincas')
          .doc(fincaId)
          .collection('potreros')
          .doc(opId)
          .set({
        'nombre': (payload['nombre'] ?? '').toString(),
        'descripcion': (payload['descripcion'] ?? '').toString(),
        'estado': (payload['estado'] ?? 'activo').toString(),
        'creadoPor': (payload['creadoPor'] ?? '').toString(),
        'sourceOperationId': opId,
        'updatedAt': FieldValue.serverTimestamp(),
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }
    if (type == 'tarea_create') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('tareas')
          .doc(opId)
          .set({
        'titulo': (payload['titulo'] ?? '').toString(),
        'descripcion': (payload['descripcion'] ?? '').toString(),
        'fecha': Timestamp.fromMillisecondsSinceEpoch(
          (payload['fechaMillis'] ?? 0) as int,
        ),
        'estado': (payload['estado'] ?? 'pendiente').toString(),
        'prioridad': (payload['prioridad'] ?? 'media').toString(),
        'asignadoA': (payload['asignadoA'] ?? '').toString(),
        'creadoPor': (payload['uid'] ?? '').toString(),
        'updatedAt': FieldValue.serverTimestamp(),
        'sourceOperationId': opId,
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    if (type == 'tarea_update') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('tareas')
          .doc((payload['tareaId'] ?? '').toString())
          .set({
        'titulo': (payload['titulo'] ?? '').toString(),
        'descripcion': (payload['descripcion'] ?? '').toString(),
        'prioridad': (payload['prioridad'] ?? 'media').toString(),
        'estado': (payload['estado'] ?? 'pendiente').toString(),
        'asignadoA': (payload['asignadoA'] ?? '').toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    if (type == 'tarea_toggle_estado') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('tareas')
          .doc((payload['tareaId'] ?? '').toString())
          .set({
        'estado': (payload['estado'] ?? 'pendiente').toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    if (type == 'tarea_delete') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('tareas')
          .doc((payload['tareaId'] ?? '').toString())
          .delete();
      return;
    }

    if (type == 'medicamento_create') {
      final fechaProximaMillis = payload['fechaProximaMillis'] as int?;

      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('medicamentos')
          .doc(opId)
          .set({
        'nombreMedicamento': (payload['nombreMedicamento'] ?? '').toString(),
        'dosis': (payload['dosis'] ?? '').toString(),
        'observaciones': (payload['observaciones'] ?? '').toString(),
        'animalId': (payload['animalId'] ?? '').toString(),
        'animalNombre': (payload['animalNombre'] ?? 'Sin nombre').toString(),
        'fechaAplicacion': Timestamp.fromMillisecondsSinceEpoch(
          (payload['fechaAplicacionMillis'] ?? 0) as int,
        ),
        'fechaProxima': fechaProximaMillis == null
            ? null
            : Timestamp.fromMillisecondsSinceEpoch(fechaProximaMillis),
        'estado': 'activo',
        'creadoPor': (payload['uid'] ?? '').toString(),
        'updatedAt': FieldValue.serverTimestamp(),
        'sourceOperationId': opId,
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (fechaProximaMillis != null) {
        await db
            .collection('tenants')
            .doc(kTenantId)
            .collection('tareas')
            .doc('${opId}_task')
            .set({
          'titulo':
              'Aplicar ${(payload['nombreMedicamento'] ?? '').toString()} a ${(payload['animalNombre'] ?? 'Sin nombre').toString()}',
          'descripcion':
              'Tarea automatica generada desde tratamientos. Dosis: ${(payload['dosis'] ?? '').toString()}.',
          'fecha': Timestamp.fromMillisecondsSinceEpoch(fechaProximaMillis),
          'estado': 'pendiente',
          'prioridad': 'alta',
          'asignadoA': (payload['userEmailOrUid'] ?? '').toString(),
          'animalId': (payload['animalId'] ?? '').toString(),
          'tipo': 'tratamiento',
          'creadoPor': (payload['uid'] ?? '').toString(),
          'updatedAt': FieldValue.serverTimestamp(),
          'sourceOperationId': opId,
          'creadoEn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return;
    }

    if (type == 'medicamento_complete') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('medicamentos')
          .doc((payload['medicamentoId'] ?? '').toString())
          .set({
        'estado': 'completado',
        'completadoEn': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    if (type == 'medicamento_delete') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('medicamentos')
          .doc((payload['medicamentoId'] ?? '').toString())
          .delete();
      return;
    }

    if (type == 'produccion_create') {
      final animalId = (payload['animalId'] ?? '').toString();
      final animalNombre = (payload['animalNombre'] ?? 'Sin nombre').toString();
      final litros = ((payload['litros'] ?? 0) as num).toDouble();
      final fechaMillis = ((payload['fechaMillis'] ?? 0) as num).toInt();

      final animalRef = db
          .collection('tenants')
          .doc(kTenantId)
          .collection('animales')
          .doc(animalId);

      await animalRef.collection('producciones').doc(opId).set({
        'fecha': Timestamp.fromMillisecondsSinceEpoch(fechaMillis),
        'litros': litros,
        'animalId': animalId,
        'animalNombre': animalNombre,
        'creadoPor': (payload['uid'] ?? '').toString(),
        'updatedAt': FieldValue.serverTimestamp(),
        'sourceOperationId': opId,
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('eventos')
          .doc('${opId}_event')
          .set({
        'titulo': 'Registro de produccion',
        'descripcion':
            'Se registraron ${litros.toStringAsFixed(1)} L para $animalNombre.',
        'fecha': Timestamp.fromMillisecondsSinceEpoch(fechaMillis),
        'animalId': animalId,
        'tipo': 'Ordeño',
        'creadoPor': (payload['uid'] ?? '').toString(),
        'updatedAt': FieldValue.serverTimestamp(),
        'sourceOperationId': opId,
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return;
    }

    if (type == 'produccion_delete') {
      final animalId = (payload['animalId'] ?? '').toString();
      final produccionId = (payload['produccionId'] ?? '').toString();

      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('animales')
          .doc(animalId)
          .collection('producciones')
          .doc(produccionId)
          .delete();
      return;
    }

    if (type == 'vaca_create') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('animales')
          .doc(opId)
          .set({
        'nombre': (payload['nombre'] ?? '').toString(),
        'raza': (payload['raza'] ?? '').toString(),
        'sexo': (payload['sexo'] ?? 'hembra').toString(),
        'estado': (payload['estado'] ?? 'activo').toString(),
        'estadoReproductivo':
            (payload['estadoReproductivo'] ?? 'sin definir').toString(),
        'fechaNacimiento': Timestamp.fromMillisecondsSinceEpoch(
          ((payload['fechaNacimientoMillis'] ?? 0) as num).toInt(),
        ),
        'cantidadPartos': ((payload['cantidadPartos'] ?? 0) as num).toInt(),
        'promedioProduccion':
            ((payload['promedioProduccion'] ?? 0) as num).toDouble(),
        'vacunas': (payload['vacunas'] ?? '').toString(),
        'fotoUrl': (payload['fotoUrl'] ?? '').toString(),
        'fotoBase64': (payload['fotoBase64'] ?? '').toString(),
        'fincaId': (payload['fincaId'] ?? '').toString(),
        'potreroId': (payload['potreroId'] ?? '').toString(),
        'creadoPor': (payload['uid'] ?? '').toString(),
        'sourceOperationId': opId,
        'updatedAt': FieldValue.serverTimestamp(),
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    if (type == 'vaca_delete') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('animales')
          .doc((payload['vacaId'] ?? '').toString())
          .delete();
      return;
    }

    if (type == 'vaca_update') {
      final vacaId = (payload['vacaId'] ?? '').toString();
      final fincaId = (payload['fincaId'] ?? '').toString();
      final potreroId = (payload['potreroId'] ?? '').toString();

      String fincaNombre = '';
      if (fincaId.isNotEmpty) {
        try {
          final fincaDoc = await db
              .collection('tenants')
              .doc(kTenantId)
              .collection('fincas')
              .doc(fincaId)
              .get();
          fincaNombre = (fincaDoc.data()?['nombre'] ?? '').toString();
        } catch (_) {}
      }

      String potreroNombre = '';
      if (fincaId.isNotEmpty && potreroId.isNotEmpty) {
        try {
          final potreroDoc = await db
              .collection('tenants')
              .doc(kTenantId)
              .collection('fincas')
              .doc(fincaId)
              .collection('potreros')
              .doc(potreroId)
              .get();
          potreroNombre = (potreroDoc.data()?['nombre'] ?? '').toString();
        } catch (_) {}
      }

      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('animales')
          .doc(vacaId)
          .set({
        'nombre': (payload['nombre'] ?? '').toString(),
        'raza': (payload['raza'] ?? '').toString(),
        'sexo': (payload['sexo'] ?? 'hembra').toString(),
        'estado': (payload['estado'] ?? 'activo').toString(),
        'estadoReproductivo':
            (payload['estadoReproductivo'] ?? 'sin definir').toString(),
        'fechaNacimiento': Timestamp.fromMillisecondsSinceEpoch(
          ((payload['fechaNacimientoMillis'] ?? 0) as num).toInt(),
        ),
        'cantidadPartos': ((payload['cantidadPartos'] ?? 0) as num).toInt(),
        'promedioProduccion':
            ((payload['promedioProduccion'] ?? 0) as num).toDouble(),
        'vacunas': (payload['vacunas'] ?? '').toString(),
        if (payload.containsKey('fotoBase64'))
          'fotoBase64': (payload['fotoBase64'] ?? '').toString(),
        'fincaId': fincaId,
        'fincaNombre': fincaNombre,
        'potreroId': potreroId,
        'potreroNombre': potreroNombre,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    if (type == 'finca_create') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('fincas')
          .doc(opId)
          .set({
        'nombre': (payload['nombre'] ?? '').toString(),
        'ubicacion': (payload['ubicacion'] ?? '').toString(),
        'extensionHa': (payload['extensionHa'] ?? '').toString(),
        'cantidadPotreros': ((payload['cantidadPotreros'] ?? 0) as num).toInt(),
        'propietario': (payload['propietario'] ?? '').toString(),
        'sourceOperationId': opId,
        'updatedAt': FieldValue.serverTimestamp(),
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    if (type == 'finca_update') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('fincas')
          .doc((payload['fincaId'] ?? '').toString())
          .set({
        'nombre': (payload['nombre'] ?? '').toString(),
        'ubicacion': (payload['ubicacion'] ?? '').toString(),
        'extensionHa': (payload['extensionHa'] ?? '').toString(),
        'cantidadPotreros': ((payload['cantidadPotreros'] ?? 0) as num).toInt(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    if (type == 'finca_delete') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('fincas')
          .doc((payload['fincaId'] ?? '').toString())
          .delete();
      return;
    }

    if (type == 'support_ticket_create') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('support_tickets')
          .doc(opId)
          .set({
        'asunto': (payload['asunto'] ?? '').toString(),
        'detalle': (payload['detalle'] ?? '').toString(),
        'prioridad': (payload['prioridad'] ?? 'media').toString(),
        'estado': 'abierto',
        'creadoPor': (payload['uid'] ?? '').toString(),
        'creadoPorEmail': (payload['email'] ?? '').toString(),
        'sourceOperationId': opId,
        'updatedAt': FieldValue.serverTimestamp(),
        'creadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    if (type == 'support_ticket_update') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('support_tickets')
          .doc((payload['ticketId'] ?? '').toString())
          .set({
        'asunto': (payload['asunto'] ?? '').toString(),
        'detalle': (payload['detalle'] ?? '').toString(),
        'prioridad': (payload['prioridad'] ?? 'media').toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    if (type == 'support_ticket_delete') {
      await db
          .collection('tenants')
          .doc(kTenantId)
          .collection('support_tickets')
          .doc((payload['ticketId'] ?? '').toString())
          .delete();
      return;
    }

    if (type == 'perfil_update') {
      await db
          .doc('tenants/$kTenantId/users/${(payload['uid'] ?? '').toString()}')
          .set({
        'displayName': (payload['displayName'] ?? '').toString(),
        if (payload.containsKey('photoUrl'))
          'photoUrl': (payload['photoUrl'] ?? '').toString(),
        if (payload.containsKey('photoBase64'))
          'photoBase64': (payload['photoBase64'] ?? '').toString(),
        'updatedAt': FieldValue.serverTimestamp(),
        'perfil': {
          'nombreGanadero': (payload['nombreGanadero'] ?? '').toString(),
          'nombreFinca': (payload['nombreFinca'] ?? '').toString(),
          'ubicacionFinca': (payload['ubicacionFinca'] ?? '').toString(),
          'numeroCabezas': ((payload['numeroCabezas'] ?? 0) as num).toInt(),
          'tipoGanado': (payload['tipoGanado'] ?? '').toString(),
        },
      }, SetOptions(merge: true));
      return;
    }

    throw StateError('Operacion no soportada: $type');
  }

  Future<void> _enqueue({
    required String type,
    required Map<String, dynamic> payload,
    String? operationId,
  }) async {
    final currentItems = await _readItems();
    final id =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
    final opId = operationId ?? id;

    currentItems.add({
      'id': id,
      'opId': opId,
      'type': type,
      'payload': payload,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'attempts': 0,
      'nextRetryAt': 0,
    });

    await _writeItems(currentItems);
    await _refreshNotifiers();

    if (!ConnectivityService.instance.isOffline.value) {
      unawaited(processPending());
    }
  }

  Future<List<Map<String, dynamic>>> _readItems() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;

    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _writeItems(List<Map<String, dynamic>> items) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    await prefs.setString(_storageKey, jsonEncode(items));
  }

  Future<void> _refreshNotifiers() async {
    final currentItems = await _readItems();
    pendingCount.value = currentItems.length;
    items.value = currentItems.map(OutboxItem.fromMap).toList(growable: false);
  }

  bool _isDue(Map<String, dynamic> item) {
    final attempts = ((item['attempts'] ?? 0) as num).toInt();
    if (attempts >= _maxAttempts) return false;

    final nextRetryAt = ((item['nextRetryAt'] ?? 0) as num).toInt();
    if (nextRetryAt <= 0) return true;
    return DateTime.now().millisecondsSinceEpoch >= nextRetryAt;
  }

  Map<String, dynamic> _withFailureMetadata(
    Map<String, dynamic> item,
    Object error,
  ) {
    final updated = Map<String, dynamic>.from(item);
    final attempts = (((updated['attempts'] ?? 0) as num).toInt()) + 1;
    updated['attempts'] = attempts;
    updated['lastError'] = error.toString();

    if (attempts >= _maxAttempts) {
      updated['nextRetryAt'] = 0;
      return updated;
    }

    final delaySeconds = min(300, 1 << min(attempts, 8));
    updated['nextRetryAt'] =
        DateTime.now().millisecondsSinceEpoch + (delaySeconds * 1000);
    return updated;
  }

  Future<void> dispose() async {
    if (_connectivityListener != null) {
      ConnectivityService.instance.isOffline
          .removeListener(_connectivityListener!);
      _connectivityListener = null;
    }
    _initialized = false;
  }
}
