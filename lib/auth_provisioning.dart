import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Provisioning {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Provisioning(this._auth, this._db);

  /// Crea /tenants/{tenantId}/users/{uid} si no existe.
  /// Evita lecturas previas para que funcione con reglas estrictas.
  /// Usa 'ganadero' como rol por defecto para mantener consistencia del dominio.
  Future<void> ensureUserProvisioned(String tenantId,
      {String? defaultRole}) async {
    final user = _auth.currentUser!;
    final uid = user.uid;
    final userRef = _db.doc('tenants/$tenantId/users/$uid');

    final payload = <String, dynamic>{
      'displayName': user.displayName ?? '',
      'email': user.email ?? '',
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (defaultRole != null) {
      payload['role'] = defaultRole;
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await userRef.set(payload, SetOptions(merge: true));
  }
}
