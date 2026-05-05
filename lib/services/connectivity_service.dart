import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);

  StreamSubscription<dynamic>? _subscription;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final initial = await _connectivity.checkConnectivity();
    _applyConnectivityValue(initial);

    _subscription = _connectivity.onConnectivityChanged.listen(
      _applyConnectivityValue,
    );
  }

  void _applyConnectivityValue(dynamic value) {
    bool nextOffline = false;

    if (value is ConnectivityResult) {
      nextOffline = value == ConnectivityResult.none;
    } else if (value is List<ConnectivityResult>) {
      nextOffline = value.isEmpty ||
          value.every((result) => result == ConnectivityResult.none);
    }

    if (isOffline.value != nextOffline) {
      isOffline.value = nextOffline;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}
