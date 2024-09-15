// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDWNjgj68jJQ6AR25MgEE0MoKboWHg6NbE',
    appId: '1:167936159847:web:ed76be77751d10a16864c2',
    messagingSenderId: '167936159847',
    projectId: 'bovi-control',
    authDomain: 'bovi-control.firebaseapp.com',
    storageBucket: 'bovi-control.appspot.com',
    measurementId: 'G-RV2WWGENFP',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAZjLxNfYpJmxHqxb1NOFK4MB1d2xKLzso',
    appId: '1:167936159847:android:bbabc69e541393c16864c2',
    messagingSenderId: '167936159847',
    projectId: 'bovi-control',
    storageBucket: 'bovi-control.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDxvkRqb03JpBSL0Y__ARkZ3vwV5MF3Pi0',
    appId: '1:167936159847:ios:52a67be7207292a26864c2',
    messagingSenderId: '167936159847',
    projectId: 'bovi-control',
    storageBucket: 'bovi-control.appspot.com',
    iosBundleId: 'com.example.flutterApplication1',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDxvkRqb03JpBSL0Y__ARkZ3vwV5MF3Pi0',
    appId: '1:167936159847:ios:52a67be7207292a26864c2',
    messagingSenderId: '167936159847',
    projectId: 'bovi-control',
    storageBucket: 'bovi-control.appspot.com',
    iosBundleId: 'com.example.flutterApplication1',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDWNjgj68jJQ6AR25MgEE0MoKboWHg6NbE',
    appId: '1:167936159847:web:8bf535b755c033a46864c2',
    messagingSenderId: '167936159847',
    projectId: 'bovi-control',
    authDomain: 'bovi-control.firebaseapp.com',
    storageBucket: 'bovi-control.appspot.com',
    measurementId: 'G-71WJ1BJC8R',
  );
}
