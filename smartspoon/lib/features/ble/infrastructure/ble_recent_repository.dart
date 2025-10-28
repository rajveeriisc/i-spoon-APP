import 'package:shared_preferences/shared_preferences.dart';

class RecentDevice {
  final String id;
  final String name;
  const RecentDevice({required this.id, required this.name});

  @override
  String toString() => '$id|$name';

  static RecentDevice? fromString(String s) {
    final i = s.indexOf('|');
    if (i <= 0) return null;
    final id = s.substring(0, i);
    final name = s.substring(i + 1);
    if (id.isEmpty) return null;
    return RecentDevice(id: id, name: name.isEmpty ? 'Unknown Device' : name);
  }
}

class BleRecentRepository {
  static const _key = 'ble_recent';

  Future<List<RecentDevice>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const <String>[];
    return list
        .map((s) => RecentDevice.fromString(s))
        .whereType<RecentDevice>()
        .toList();
  }

  Future<void> upsert(RecentDevice device, {int keep = 5}) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? const <String>[];
    final filtered = current
        .map((s) => RecentDevice.fromString(s))
        .whereType<RecentDevice>()
        .where((d) => d.id != device.id)
        .map((d) => d.toString())
        .toList();
    filtered.insert(0, device.toString());
    if (filtered.length > keep) filtered.removeRange(keep, filtered.length);
    await prefs.setStringList(_key, filtered);
  }
}
