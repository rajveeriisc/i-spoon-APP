import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartspoon/core/config/app_config.dart';
import 'package:smartspoon/features/auth/domain/services/auth_service.dart';
import 'package:smartspoon/features/devices/domain/models/device_model.dart';
import 'package:flutter/foundation.dart';

class DeviceApiService {
  final String _baseUrl = AppConfig.apiBaseUrl;

  Future<List<DeviceModel>> getUserDevices() async {
    final token = await AuthService.getValidToken();
    if (token == null) {
      if (kDebugMode) print('No auth token available for getUserDevices');
       return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/devices/user-devices'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('devices')) {
             return (data['devices'] as List).map((json) => DeviceModel.fromJson(json)).toList();
        } else if (data is List) {
             return data.map((json) => DeviceModel.fromJson(json)).toList();
        }
        return [];
      } else {
        if (kDebugMode) print('Failed to fetch devices: ${response.statusCode} ${response.body}');
        return []; // Return empty instead of throwing to avoid crashing UI
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching devices: $e');
       return [];
    }
  }

  Future<DeviceModel?> updateSettings(String userDeviceId, Map<String, dynamic> settings) async {
    final token = await AuthService.getValidToken();
    if (token == null) throw Exception('Authentication required');

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/devices/user-devices/$userDeviceId/settings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(settings),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('settings')) {
            return DeviceModel.fromJson(data['settings']);
        }
        return null;
      } else {
        throw Exception('Failed to update settings: ${response.body}');
      }
    } catch (e) {
        if (kDebugMode) print('Error updating settings: $e');
        rethrow;
    }
  }
}
