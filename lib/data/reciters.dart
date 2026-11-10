import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Reciters are read ONLY from assets/data/dangakan.json. An entry supports
/// recitation (audio + ayah highlighting) when its "doxx" field is "true":
/// then the per-reciter timings db (assets/db/<id>.db) exists for it and the
/// surah audio url is complete. doxx=false reciters never appear in the app.
class Reciters {
  static List<Map<String, dynamic>>? _cache;

  /// true → this reciter supports audio + ayah timings (db assets/db/<id>.db).
  static bool supported(Map<String, dynamic> r) =>
      '${r['doxx'] ?? ''}'.trim().toLowerCase() == 'true';

  /// The supported reciters only — every caller of dangakan.json goes
  /// through this so the list is consistent app-wide.
  static Future<List<Map<String, dynamic>>> supportedList() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/data/dangakan.json');
    final list = (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .where(supported)
        .toList();
    _cache = list;
    return list;
  }

  /// A reciter by id from the supported list (null when unknown).
  static Future<Map<String, dynamic>?> byId(String id) async {
    final all = await supportedList();
    for (final r in all) {
      if ('${r['id']}' == id.trim()) return r;
    }
    return null;
  }
}
