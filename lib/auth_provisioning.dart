import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Provisioning {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Provisioning(this._auth, this._db);

  /// Crea /tenants/{tenantId}/users/{uid} si no existe.
  /// No consulta otros usuarios (evita permission-denied con reglas actuales).
  /// Usa 'admin' como rol por defecto para el dueño (ajústalo si deseas 'worker').
  Future<void> ensureUserProvisioned(String tenantId,
      {String defaultRole = 'admin'}) async {
    final user = _auth.currentUser!;
    final uid = user.uid;
    final userRef = _db.doc('tenants/$tenantId/users/$uid');

    await _db.runTransaction((tx) async {
      final me = await tx.get(userRef);
      if (me.exists) return;

      tx.set(userRef, {
        'displayName': user.displayName ?? '',
        'email': user.email ?? '',
        'role': defaultRole, // <— para ti pon 'admin'
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
