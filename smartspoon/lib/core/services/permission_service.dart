import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles first-launch permission requests for Android and iOS.
///
/// Call [PermissionService.requestIfNeeded] once from the first authenticated
/// screen (HomePage). The dialog is shown only on the very first launch;
/// every subsequent app open is a no-op.
class PermissionService {
  static const String _prefKey = 'permissions_requested_v1';

  /// Show the explanation dialog and request all required permissions.
  /// Safe to call on every app open — silently returns if already done.
  static Future<void> requestIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey) ?? false) return; // Already asked — skip

    if (!context.mounted) return;

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Enable Smart Spoon Monitoring',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          'To keep your Smart Spoon connected and sending data continuously — '
          'even when the screen is off — we need a few permissions:\n\n'
          '${Platform.isAndroid ? '• Bluetooth (connect to your spoon)\n'
              '• Notifications (background status alerts)\n'
              '• Ignore Battery Optimization (true background running)\n' : ''}'
          '${Platform.isIOS ? '• Bluetooth (connect to your spoon)\n'
              '• Location (required by iOS for BLE scanning)\n' : ''}'
          '\nWe ask only once. You can change this anytime in Settings.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    );

    // Mark as done regardless of choice — don't nag the user
    await prefs.setBool(_prefKey, true);

    if (proceed != true) return;

    if (Platform.isAndroid) {
      await _requestAndroid();
    } else if (Platform.isIOS) {
      await _requestIos();
    }
  }

  // ── Android ──────────────────────────────────────────────────────────────

  static Future<void> _requestAndroid() async {
    // 1. Bluetooth (Android 12+ = API 31+)
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    // 2. Notifications (Android 13+ = API 33+)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // 3. Battery optimization exemption — critical for true background BLE.
    //    Only request if not already exempted (avoids redundant system dialog).
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    // 4. If permanently denied, guide user to Settings
    final btConnect = await Permission.bluetoothConnect.status;
    if (btConnect.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  // ── iOS ──────────────────────────────────────────────────────────────────

  static Future<void> _requestIos() async {
    // iOS Bluetooth prompt is triggered automatically by flutter_reactive_ble
    // on first BLE operation. We still request Location (required for BLE scan
    // on iOS) and set up the always-on location for background wakes.

    // 1. Location when in use (prerequisite for locationAlways on iOS)
    var locStatus = await Permission.locationWhenInUse.status;
    if (locStatus.isDenied) {
      locStatus = await Permission.locationWhenInUse.request();
    }

    // 2. Location always — allows OS to wake app for BLE characteristic data
    if (locStatus.isGranted) {
      final alwaysStatus = await Permission.locationAlways.status;
      if (alwaysStatus.isDenied) {
        await Permission.locationAlways.request();
      }
    }

    // Note: NSBluetoothAlwaysUsageDescription in Info.plist triggers the
    // native iOS Bluetooth dialog automatically — no code needed here.
  }
}
