import 'dart:convert';
import 'package:http/http.dart' as http;

/// Firebase Realtime Database access via the REST API — no Firebase SDK
/// needed, so the project compiles without google-services.json.
/// Original project: regayislam-1 (see library.json in the backup).
class Rtdb {
  Rtdb._();
  static final Rtdb I = Rtdb._();

  static const String base = 'https://regayislam-1-default-rtdb.firebaseio.com';

  String? _lastError;
  String? get lastError => _lastError;

  Uri _uri(String path) {
    final safePath = path.split('/').where((part) => part.isNotEmpty)
        .map(Uri.encodeComponent).join('/');
    return Uri.parse('$base/$safePath.json');
  }

  Future<dynamic> get(String path) async {
    _lastError = null;
    try {
      final r = await http.get(_uri(path),
          headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) {
        _lastError = 'Firebase HTTP ' + r.statusCode.toString() + ': ' + r.body;
        return null;
      }
      final value = jsonDecode(r.body);
      if (value is Map && value['error'] != null) {
        _lastError = 'Firebase: ' + value['error'].toString();
        return null;
      }
      return value;
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  /// Convert Firebase arrays, keyed collections and single records to rows.
  Future<List<Map<String, dynamic>>> list(String path) async {
    final v = await get(path);
    final out = <Map<String, dynamic>>[];
    const fields = {'name', 'title', 'desc', 'text', 'link', 'url',
      'video', 'videourl', 'stream', 'youtube', 'image', 'thumbnail'};
    if (v is List) {
      for (var i = 0; i < v.length; i++) {
        final item = v[i];
        if (item is Map) {
          out.add(Map<String, dynamic>.from(item));
        } else if (item is String && item.trim().isNotEmpty) {
          out.add({'id': i.toString(), 'url': item.trim()});
        }
      }
    } else if (v is Map) {
      final oneRecord = v.keys.any((k) => fields.contains(k.toString().toLowerCase()));
      if (oneRecord) {
        out.add(Map<String, dynamic>.from(v));
      } else {
        v.forEach((key, item) {
          if (item is Map) {
            out.add({'id': key.toString(), ...Map<String, dynamic>.from(item)});
          } else if (item is String && item.trim().isNotEmpty) {
            out.add({'id': key.toString(), 'url': item.trim()});
          }
        });
      }
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

  /// Merge fields into an existing node (Firebase PATCH via REST).
  Future<void> patch(String path, Map<String, dynamic> data) async {
    try {
      await http
          .patch(Uri.parse('$base/$path.json'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data))
          .timeout(const Duration(seconds: 12));
    } catch (_) {}
  }

  /// Sketchware saved some nodes as whole JSON arrays inside a string
  /// ("videoall" -> {videoall: '[{image,name,tag},...]'}, "Live" likewise).
  dynamic _unwrap(dynamic v) {
    if (v is String && v.trim().startsWith('[{')) {
      try {
        return jsonDecode(v);
      } catch (_) {
        return v;
      }
    }
    if (v is Map && v.length == 1) {
      return _unwrap(v.values.first);
    }
    return v;
  }

  /// videoNew/<folder>/<pushKey>/{name,url,...} — folders are tag ids from
  /// "videoall". Flatten to one row per video (136+ videos live there).
  Future<List<Map<String, dynamic>>> videosFlat() async {
    final v = await get('videoNew');
    final out = <Map<String, dynamic>>[];
    if (v is Map) {
      v.forEach((folder, items) {
        if (items is Map) {
          items.forEach((key, video) {
            if (video is Map) {
              out.add({
                'id': '${video['key'] ?? key}',
                'folder': '$folder',
                ...Map<String, dynamic>.from(video),
              });
            }
          });
        }
      });
    }
    return out;
  }

  /// Per-tag videos: videoNew/<tag> is one folder.
  Future<List<Map<String, dynamic>>> videosOfTag(String tag) async {
    final v = await get('videoNew/$tag');
    final out = <Map<String, dynamic>>[];
    if (v is Map) {
      v.forEach((key, video) {
        if (video is Map) {
          out.add({
            'id': '${video['key'] ?? key}',
            'folder': tag,
            ...Map<String, dynamic>.from(video),
          });
        }
      });
    }
    return out;
  }

  /// videoall = the tag list [{image, name, tag}, ...].
  Future<List<Map<String, dynamic>>> videoTags() async {
    final v = await get('videoall');
    final arr = _unwrap(v);
    if (arr is List) {
      return arr
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  /// Live = the HLS channel list [{image, name, url}, ...].
  Future<List<Map<String, dynamic>>> liveChannels() async {
    final v = await get('Live');
    final arr = _unwrap(v);
    if (arr is List) {
      return arr
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
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
