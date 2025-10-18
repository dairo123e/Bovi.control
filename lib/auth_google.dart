import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<UserCredential> signInWithGoogle({String? webClientId}) async {
  final auth = FirebaseAuth.instance;

  if (kIsWeb) {
    final provider = GoogleAuthProvider();
    return await auth.signInWithPopup(provider);
  } else {
    final googleSignIn = GoogleSignIn(
      clientId: (kIsWeb ? webClientId : null),
    );
    final account = await googleSignIn.signIn();
    if (account == null) {
      throw FirebaseAuthException(
        code: 'ERROR_ABORTED_BY_USER',
        message: 'Inicio con Google cancelado',
      );
    }
    final authData = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: authData.accessToken,
      idToken: authData.idToken,
    );
    return await auth.signInWithCredential(credential);
  }
}
