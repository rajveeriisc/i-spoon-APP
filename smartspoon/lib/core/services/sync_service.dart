import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/database_service.dart';
import '../../features/auth/domain/services/auth_service.dart';
import '../config/app_config.dart';

class SyncService {
  final DatabaseService _db = DatabaseService();
  // AuthService is static, no instance needed
  
  // Use centralized AppConfig for base URL
  final String _baseUrl = AppConfig.apiBaseUrl;

  Future<void> syncAll() async {
    if (kDebugMode) print('Starting sync...');
    
    try {
      await syncMeals();
      // Bites and temps are synced per meal usually, but we can do a sweep
      // For now, simpler to sync meals first, then their details
    } catch (e) {
      if (kDebugMode) print('Sync failed: $e');
    }
  }

  Future<void> syncMeals() async {
    final unsyncedMeals = await _db.getUnsyncedMeals();
    if (unsyncedMeals.isEmpty) return;

    final token = await AuthService.getValidToken(); // Use static method
    if (token == null) return;

    for (var meal in unsyncedMeals) {
      try {
        // 1. Sync the meal
        // Note: The backend should support idempotency using the UUID
        final response = await http.post(
          Uri.parse('$_baseUrl/api/meals'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            ...meal.toMap(),
            'uuid': meal.uuid, // Ensure backend uses this UUID
          }),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          final serverId = responseData['meal']['id'];
          
          await _db.markMealSynced(meal.uuid, serverId);
          await syncBitesForMeal(meal.uuid, serverId, token);
          await syncTemperaturesForMeal(meal.uuid, serverId, token);
          
          if (kDebugMode) print('Synced meal ${meal.uuid}');
        } else {
           if (kDebugMode) print('Failed to sync meal ${meal.uuid}: ${response.body}');
        }
      } catch (e) {
        if (kDebugMode) print('Error syncing meal ${meal.uuid}: $e');
      }
    }
  }

  Future<void> syncBitesForMeal(String mealUuid, int serverMealId, String token) async {
    final bites = await _db.getUnsyncedBites(limit: 100); // Get batch
    // Filter for this meal (inefficient query-wise but safe)
    final mealBites = bites.where((b) => b.mealUuid == mealUuid).toList();
    
    if (mealBites.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/meals/$serverMealId/bites'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'bites': mealBites.map((b) => b.toMap()).toList(),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final ids = mealBites.map((b) => b.id!).toList();
        await _db.markBitesSynced(ids);
        if (kDebugMode) print('Synced ${ids.length} bites for meal $serverMealId');
      }
    } catch (e) {
      if (kDebugMode) print('Error syncing bites: $e');
    }
  }
  
  // Temperature logs table removed, syncing is now part of Meal object (avgFoodTemp)
  Future<void> syncTemperaturesForMeal(String mealUuid, int serverMealId, String token) async {
    // Deprecated
  }

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
      // Check if connected via mobile, wifi, or ethernet
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
