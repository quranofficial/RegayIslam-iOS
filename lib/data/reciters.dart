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

  /// Every reciter from the original Sketchware list. Some entries have
  /// full-surah audio but no per-ayah timing database; they must remain
  /// selectable in the reciter screen instead of disappearing.
  static Future<List<Map<String, dynamic>>> allList() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/data/dangakan.json');
    final list = (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _cache = list;
    return list;
  }

  /// Reciters with a matching per-reciter timing database. Use this list
  /// only for ayah-synchronized features such as the Quran Studio.
  static Future<List<Map<String, dynamic>>> supportedList() async =>
      (await allList()).where(supported).toList();

  /// A reciter by id from the supported list (null when unknown).
  static Future<Map<String, dynamic>?> byId(String id) async {
    final all = await supportedList();
    for (final r in all) {
      if ('${r['id']}' == id.trim()) return r;
    }
    return null;
  }
}
