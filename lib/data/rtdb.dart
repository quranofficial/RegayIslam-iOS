import 'dart:convert';
import 'package:http/http.dart' as http;

/// Firebase Realtime Database access via the REST API — no Firebase SDK
/// needed, so the project compiles without google-services.json.
/// Original project: regayislam-1 (see library.json in the backup).
class Rtdb {
  Rtdb._();
  static final Rtdb I = Rtdb._();

  static const String base = 'https://regayislam-1-default-rtdb.firebaseio.com';

  Future<dynamic> get(String path) async {
    try {
      final r = await http
          .get(Uri.parse('$base/$path.json'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (_) {}
    return null;
  }

  /// List from an RTDB node (handles both arrays and keyed maps).
  Future<List<Map<String, dynamic>>> list(String path) async {
    final v = await get(path);
    final out = <Map<String, dynamic>>[];
    if (v is List) {
      for (final e in v) {
        if (e is Map) out.add(Map<String, dynamic>.from(e));
      }
    } else if (v is Map) {
      v.forEach((_, e) {
        if (e is Map) out.add(Map<String, dynamic>.from(e));
      });
    }
    return out;
  }

  Future<void> push(String path, Map<String, dynamic> data) async {
    try {
      await http
          .post(Uri.parse('$base/$path.json'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data))
          .timeout(const Duration(seconds: 12));
    } catch (_) {}
  }

  // --- original RTDB paths used by the Sketchware events ---
  Future<List<Map<String, dynamic>>> quiz() => list('quiz');
  Future<List<Map<String, dynamic>>> videos() => list('videoNew');
  Future<List<Map<String, dynamic>>> videoAll() => list('videoall');
  Future<List<Map<String, dynamic>>> live() => list('Live');
  Future<List<Map<String, dynamic>>> liveMuslim() => list('livemuslim');
  Future<List<Map<String, dynamic>>> dialogg() => list('dialogg');
  Future<List<Map<String, dynamic>>> ramadan() => list('ramadan');
  Future<List<Map<String, dynamic>>> comments(String videoId) =>
      list('commentvideo/$videoId');

  Future<void> sendFeedback(Map<String, dynamic> data) =>
      push('feedback', data);
  Future<void> sendComment(String videoId, Map<String, dynamic> data) =>
      push('commentvideo/$videoId', data);
}
