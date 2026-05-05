// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth_provisioning.dart'; // existe en lib/
import '../auth_google.dart'; // existe en lib/
import '../config/app_config.dart'; // kTenantId

/// Servicio de autenticación (sin UI)
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  late final Provisioning _prov;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance {
    _prov = Provisioning(_auth, _db);
  }

  /// Registro con email + provisión y metadatos
  Future<void> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
    required String role,
  }) async {
    final roleValue = role.trim().toLowerCase();
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    await cred.user!.updateDisplayName(displayName.trim());
    await _prov.ensureUserProvisioned(kTenantId, defaultRole: roleValue);

    final uid = _auth.currentUser!.uid;
    await _db.doc('tenants/$kTenantId/users/$uid').set({
      'displayName': displayName.trim(),
      'email': email.trim(),
      'role': roleValue,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Login con email + provisión si hace falta
  Future<void> signInWithEmailAndProvision({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    await _prov.ensureUserProvisioned(kTenantId);
    await ensureRoleNormalizedForCurrentUser(setDefaultIfMissing: false);
  }

  /// Login con Google + provisión (roleIfNew si es usuario nuevo)
  Future<void> signInWithGoogleAndProvision({required String roleIfNew}) async {
    await signInWithGoogle(); // maneja web / android
    final roleValue = roleIfNew.trim().toLowerCase();
    await _prov.ensureUserProvisioned(kTenantId, defaultRole: roleValue);
    await _ensureDefaultRoleIfMissing(fallbackRole: roleValue);

    final uid = _auth.currentUser!.uid;
    await _db.doc('tenants/$kTenantId/users/$uid').set({
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> ensureRoleNormalizedForCurrentUser({
    bool setDefaultIfMissing = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _db.doc('tenants/$kTenantId/users/${user.uid}');
    final snap = await ref.get();
    final data = snap.data() ?? const <String, dynamic>{};

    final roleRaw = (data['role'] ?? data['rol'] ?? '').toString();
    final normalized = roleRaw.trim().toLowerCase();

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (normalized.isEmpty) {
      if (setDefaultIfMissing) {
        updates['role'] = 'ganadero';
        updates['status'] = 'active';
      }
    } else {
      if ((data['role'] ?? '').toString().trim().toLowerCase() != normalized) {
        updates['role'] = normalized;
      }
      if ((data['rol'] ?? '').toString().isNotEmpty) {
        updates['rol'] = FieldValue.delete();
      }
    }

    if (updates.length == 1) return;

    await ref.set(updates, SetOptions(merge: true));
  }

  Future<void> _ensureDefaultRoleIfMissing({String? fallbackRole}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _db.doc('tenants/$kTenantId/users/${user.uid}');
    final snap = await ref.get();
    final data = snap.data() ?? const <String, dynamic>{};
    final role =
        (data['role'] ?? data['rol'] ?? '').toString().trim().toLowerCase();
    if (role.isNotEmpty) return;

    final roleValue = (fallbackRole ?? 'ganadero').trim().toLowerCase();

    await ref.set({
      'role': roleValue,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await ensureRoleNormalizedForCurrentUser(setDefaultIfMissing: true);
  }
}
