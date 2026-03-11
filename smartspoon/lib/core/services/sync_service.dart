import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/database_service.dart';
import '../../features/auth/domain/services/auth_service.dart';
import '../../features/notifications/domain/services/notification_service.dart';
import '../config/app_config.dart';

class SyncService {
  final DatabaseService _db = DatabaseService();
  final String _baseUrl = AppConfig.apiBaseUrl;

  /// Build standard auth headers for API calls.
  /// ngrok bypass headers are only added in debug mode when the URL is a tunnel.
  Map<String, String> _authHeaders(String token) {
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    if (kDebugMode && _baseUrl.contains('ngrok')) {
      headers['ngrok-skip-browser-warning'] = 'true';
    }
    return headers;
  }

  Future<void> syncAll() async {
    if (kDebugMode) print('Starting sync...');

    try {
      await syncMeals();
    } catch (e) {
      if (kDebugMode) print('Sync failed: $e');
    }
  }

  Future<void> syncMeals() async {
    // Skip entirely if backend URL is not configured
    if (!AppConfig.isBackendConfigured) return;

    final unsyncedMeals = await _db.getUnsyncedMeals();
    if (unsyncedMeals.isEmpty) return;

    final token = await AuthService.getValidToken();
    if (token == null) return;

    for (var meal in unsyncedMeals) {
      try {
        // Send only the fields the backend expects — exclude SQLite-specific columns
        final response = await http.post(
          Uri.parse('$_baseUrl/meals'),
          headers: _authHeaders(token),
          body: jsonEncode({
            'uuid':             meal.uuid,
            'started_at':       meal.startedAt.toIso8601String(),
            'ended_at':         meal.endedAt?.toIso8601String(),
            'meal_type':        meal.mealType,
            'total_bites':      meal.totalBites,
            'avg_pace_bpm':     meal.avgPaceBpm,
            'tremor_index':     meal.tremorIndex,
            'duration_minutes': meal.durationMinutes,
            'avg_food_temp_c':  meal.avgFoodTemp,
          }),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          final serverId = responseData['meal']['id'];

          await _db.markMealSynced(meal.uuid, serverId);

          if (kDebugMode) print('Synced meal ${meal.uuid}');

          // Sync bites for this meal now that the meal exists on the server
          await syncBitesForMeal(meal.uuid, token);

          NotificationService().showLocalAlert(
            title: 'Data Synced',
            body: 'Your eating analysis has been securely synced to the cloud.',
            type: 'system_alerts',
          );
        } else {
          if (kDebugMode) print('Failed to sync meal ${meal.uuid}: ${response.body}');
        }
      } catch (e) {
        if (kDebugMode) print('Error syncing meal ${meal.uuid}: $e');
      }
    }
  }

  Future<void> syncBitesForMeal(String mealUuid, String token) async {
    // Fetch all unsynced bites for this specific meal (no global limit)
    final mealBites = await _db.getUnsyncedBitesForMeal(mealUuid);

    if (mealBites.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/meals/$mealUuid/bites'),
        headers: _authHeaders(token),
        body: jsonEncode({
          'bites': mealBites.map((b) => {
            'sequence_number':   b.sequenceNumber,
            'timestamp':         b.timestamp.toIso8601String(),
            'tremor_magnitude':  b.tremorMagnitude,
            'tremor_frequency':  b.tremorFrequency,
            'food_temp_c':       b.foodTempC,
          }).toList(),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final ids = mealBites.where((b) => b.id != null).map((b) => b.id!).toList();
        await _db.markBitesSynced(ids);
        if (kDebugMode) print('Synced ${ids.length} bites for meal $mealUuid');
      } else {
        if (kDebugMode) print('Failed to sync bites for meal $mealUuid: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) print('Error syncing bites: $e');
    }
  }

  // Temperature logs deprecated — stats stored in meal object (avgFoodTemp)
  Future<void> syncTemperaturesForMeal(String mealUuid, int serverMealId, String token) async {}

  /// Check if there's any unsynced data in the local database
  Future<bool> hasUnsyncedData() async {
    final unsyncedMeals = await _db.getUnsyncedMeals();
    final unsyncedBites = await _db.getUnsyncedBites(limit: 1);
    return unsyncedMeals.isNotEmpty || unsyncedBites.isNotEmpty;
  }

  /// Check if device has internet connectivity
  Future<bool> isConnected() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult == ConnectivityResult.mobile ||
          connectivityResult == ConnectivityResult.wifi ||
          connectivityResult == ConnectivityResult.ethernet;
    } catch (e) {
      if (kDebugMode) print('Connectivity check failed: $e');
      return false;
    }
  }

  /// Sync only if there's unsynced data and internet is available
  Future<bool> syncIfNeeded() async {
    if (kDebugMode) print('Checking if sync is needed...');

    final hasData = await hasUnsyncedData();
    if (!hasData) {
      if (kDebugMode) print('No unsynced data, skipping sync');
      return false;
    }

    final connected = await isConnected();
    if (!connected) {
      if (kDebugMode) print('No internet connection, skipping sync');
      return false;
    }

    if (kDebugMode) print('Conditions met, starting sync...');
    await syncAll();
    return true;
  }
}
