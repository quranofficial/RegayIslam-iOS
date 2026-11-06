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
    if (v == null) return [];
    final u = _unwrap(v);
    final out = <Map<String, dynamic>>[];
    if (u is List) {
      for (var i = 0; i < u.length; i++) {
        final item = u[i];
        if (item is Map) {
          out.add({'id': i.toString(), ...Map<String, dynamic>.from(item)});
        } else if (item is String && item.trim().isNotEmpty) {
          out.add({'id': i.toString(), 'url': item.trim()});
        }
      }
    } else if (u is Map) {
      final entries = u.entries.toList();
      // A single object with scalar fields (dialogg/dialog, ramadan) is one
      // row, not a list of "day" -> 3 garbage rows.
      final allScalar = entries.isNotEmpty &&
          entries.every((e) => e.value is! Map && e.value is! List);
      if (allScalar) {
        out.add({'id': path.split('/').last, ...Map<String, dynamic>.from(u)});
      } else {
        for (final e in entries) {
          final item = e.value;
          if (item is Map) {
            out.add({'id': e.key.toString(), ...Map<String, dynamic>.from(item)});
          } else if (item is String && item.trim().isNotEmpty) {
            out.add({'id': e.key.toString(), 'url': item.trim()});
          }
        }
      }
    } else if (u is String && u.trim().isNotEmpty) {
      out.add({'id': path.split('/').last, 'url': u.trim()});
    }
    return out;
  }

  /// Remove a whole node (Firebase REST DELETE) — used by the admin panel.
  Future<bool> delete(String path) async {
    try {
      final r = await http.delete(Uri.parse('$base/$path.json'))
          .timeout(const Duration(seconds: 12));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
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
  /// ("videoall" -> {videoall: '[{image,name,tag},...]'}, "Live" likewise)
  /// or as single nested objects ("dialogg" -> {dialog: {...}},
  /// "ramadan" -> {ramadan: {day, month, state}}). Unwrap all of that.
  dynamic _unwrap(dynamic v) {
    if (v is String && v.trim().startsWith('[')) {
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
  /// The real node in the DB is "CommentVideo" (capital C and V).
  Future<List<Map<String, dynamic>>> comments(String videoId) =>
      list('CommentVideo/$videoId');

  Future<void> sendFeedback(Map<String, dynamic> data) =>
      push('feedback', data);
  Future<void> sendComment(String videoId, Map<String, dynamic> data) =>
      push('CommentVideo/$videoId', data);

  /// Item 17: the like counter lives on the video row (field "like");
  /// increment it in the DB and return the new value, keeping the
  /// per-device "already liked" guard in prefs.
  Future<int?> likeVideo(String folder, String videoKey, String field) async {
    try {
      final v = await get('videoNew/$folder/$videoKey/$field');
      final cur = int.tryParse('$v') ?? 0;
      final next = cur + 1;
      await patch('videoNew/$folder/$videoKey', {field: '$next'});
      return next;
    } catch (_) {
      return null;
    }
  }
}
