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
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    await cred.user!.updateDisplayName(displayName.trim());
    await _prov.ensureUserProvisioned(kTenantId, defaultRole: role);

    final uid = _auth.currentUser!.uid;
    await _db.doc('tenants/$kTenantId/users/$uid').set({
      'displayName': displayName.trim(),
      'email': email.trim(),
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
  }

  /// Login con Google + provisión (roleIfNew si es usuario nuevo)
  Future<void> signInWithGoogleAndProvision({required String roleIfNew}) async {
    await signInWithGoogle(); // maneja web / android
    await _prov.ensureUserProvisioned(kTenantId, defaultRole: roleIfNew);

    final uid = _auth.currentUser!.uid;
    await _db.doc('tenants/$kTenantId/users/$uid').set({
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
