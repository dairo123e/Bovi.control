import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/connectivity_service.dart';
import '../../services/offline_outbox_service.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _visible = false;
  String _messageKey = '';
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.isOffline.addListener(_onStatusChanged);
    OfflineOutboxService.instance.pendingCount.addListener(_onStatusChanged);
    _onStatusChanged();
  }

  @override
  void dispose() {
    ConnectivityService.instance.isOffline.removeListener(_onStatusChanged);
    OfflineOutboxService.instance.pendingCount.removeListener(_onStatusChanged);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onStatusChanged() {
    final offline = ConnectivityService.instance.isOffline.value;
    final pending = OfflineOutboxService.instance.pendingCount.value;
    final shouldShow = offline || pending > 0;

    if (!shouldShow) {
      _hideTimer?.cancel();
      if (mounted) {
        setState(() {
          _visible = false;
          _messageKey = '';
        });
      }
      return;
    }

    final nextKey = offline ? 'offline' : 'pending_$pending';
    if (_messageKey == nextKey && !_visible) return;

    _hideTimer?.cancel();
    if (mounted) {
      setState(() {
        _visible = true;
        _messageKey = nextKey;
      });
    }

    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOffline,
      builder: (context, offline, _) {
        return ValueListenableBuilder<int>(
          valueListenable: OfflineOutboxService.instance.pendingCount,
          builder: (context, pending, __) {
            final visible = offline || pending > 0;
            final color =
                offline ? Colors.orange.shade800 : Colors.blue.shade800;
            final icon = offline ? Icons.wifi_off : Icons.sync;
            final text = offline
                ? 'Sin internet. Tus cambios se guardaran y se sincronizaran al reconectar.'
                : 'Sincronizando $pending cambio(s) pendiente(s).';

            return IgnorePointer(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                offset:
                    (_visible && visible) ? Offset.zero : const Offset(0, -1),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: (_visible && visible) ? 1 : 0,
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(icon, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
