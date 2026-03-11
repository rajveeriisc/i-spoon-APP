import 'package:flutter/material.dart';
import 'package:smartspoon/core/services/scheduled_sync_service.dart';
import 'package:smartspoon/core/services/sync_service.dart';
import 'package:smartspoon/features/devices/domain/services/ble_service.dart';
import 'package:smartspoon/features/devices/domain/services/smart_spoon_ble_service.dart';
import 'package:smartspoon/features/notifications/domain/services/notification_service.dart';

/// AppSetupService — initializes background services at app startup and
/// coordinates BLE foreground/background transitions via [WidgetsBindingObserver].
///
/// Call [initializeBackgroundServices] once in main() before runApp().
/// The [AppLifecycleObserver] is registered automatically and lives for the
/// lifetime of the app.
class AppSetupService {
  /// Non-blocking startup. All work is done in a microtask so main() / runApp()
  /// are not delayed.
  static void initializeBackgroundServices() {
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
    Future.microtask(() async {
      try {
        await SmartSpoonBleService().startBackgroundMonitoring();
        debugPrint('[Setup] SmartSpoonBleService started');
      } catch (e) {
        debugPrint('[Setup] SmartSpoonBleService.startBackgroundMonitoring() failed: $e');
      }

      try {
        // Just let BleService auto connect natively.
        await BleService().autoConnectToLastDevice();
        debugPrint('[Setup] BleService auto-connect started');
      } catch (e) {
        debugPrint('[Setup] BleService.autoConnectToLastDevice() failed: $e');
      }

      try {
        await NotificationService().initialize();
        debugPrint('[Setup] NotificationService initialized');
      } catch (e) {
        debugPrint('[Setup] NotificationService.initialize() failed: $e');
      }

      try {
        await ScheduledSyncService.initializeScheduledSync();
        debugPrint('[Setup] ScheduledSyncService initialized');
      } catch (e) {
        debugPrint('[Setup] ScheduledSyncService.initializeScheduledSync() failed: $e');
      }
    });
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  DateTime? _lastSyncAttempt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SmartSpoonBleService().onAppForegrounded();
      _triggerSyncOnResume();
    } else if (state == AppLifecycleState.paused) {
      SmartSpoonBleService().onAppBackgrounded();
    }
  }

  /// Trigger sync when app comes to foreground, throttled to once per 5 minutes.
  void _triggerSyncOnResume() {
    final now = DateTime.now();
    if (_lastSyncAttempt != null &&
        now.difference(_lastSyncAttempt!).inMinutes < 5) return;
    _lastSyncAttempt = now;
    SyncService().syncIfNeeded();
  }
}
