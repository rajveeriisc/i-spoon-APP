import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'sync_service.dart';

/// Background task callback - MUST be top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (kDebugMode) print('Background sync task started: $task');
    
    try {
      final syncService = SyncService();
      final synced = await syncService.syncIfNeeded();
      
      if (kDebugMode) { print(synced
          ? 'Background sync completed successfully' 
          : 'Background sync skipped (no data or no internet)');
      }
      
      return Future.value(true);
    } catch (e) {
      if (kDebugMode) print('Background sync failed: $e');
      return Future.value(false);
    }
  });
}

class ScheduledSyncService {
  static const String _uniqueName = 'daily-sync-11pm';
  static const String _taskName = 'syncTask';

  /// Initialize scheduled sync - call this once on app startup
  static Future<void> initializeScheduledSync() async {
    if (kDebugMode) print('Initializing scheduled sync service...');
    
    try {
      // Initialize Workmanager
      await Workmanager().initialize(
        callbackDispatcher,
      );

      // Calculate delay until 11 PM today (or tomorrow if past 11 PM)
      final now = DateTime.now();
      var targetTime = DateTime(now.year, now.month, now.day, 23, 0); // 11 PM
      
      if (now.isAfter(targetTime)) {
        // If it's already past 11 PM, schedule for tomorrow
        targetTime = targetTime.add(const Duration(days: 1));
      }
      
      final initialDelay = targetTime.difference(now);
      
      if (kDebugMode) {
        print('Scheduling daily sync at 11 PM');
        print('Initial delay: ${initialDelay.inHours}h ${initialDelay.inMinutes % 60}m');
      }

      // Register periodic task (runs every 24 hours)
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        _taskName,
        frequency: const Duration(hours: 24),
        initialDelay: initialDelay,
        constraints: Constraints(
          networkType: NetworkType.connected, // Only run when connected
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 15),
      );

      if (kDebugMode) print('Scheduled sync registered successfully');
    } catch (e) {
      if (kDebugMode) print('Failed to initialize scheduled sync: $e');
    }
  }

  /// Cancel scheduled sync
  static Future<void> cancelScheduledSync() async {
    await Workmanager().cancelByUniqueName(_uniqueName);
    if (kDebugMode) print('Scheduled sync cancelled');
  }

  /// Manually trigger sync (for testing)
  static Future<void> triggerManualSync() async {
    if (kDebugMode) print('Triggering manual sync...');
    final syncService = SyncService();
    await syncService.syncIfNeeded();
  }
}
