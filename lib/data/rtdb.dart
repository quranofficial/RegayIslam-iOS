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
  /// Returns true only when Firebase really accepted the change.
  Future<bool> delete(String path) async {
    try {
      final r = await http.delete(Uri.parse('$base/$path.json'))
          .timeout(const Duration(seconds: 12));
      _lastError = r.statusCode == 200 ? null : 'HTTP ${r.statusCode}';
      return r.statusCode == 200;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  /// Push a child node. Returns the new key on success, null on failure —
  /// so callers (like/comment) can tell the user when a write failed
  /// instead of failing silently.
  Future<String?> push(String path, Map<String, dynamic> data) async {
    _lastError = null;
    try {
      final r = await http
          .post(Uri.parse('$base/$path.json'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final v = jsonDecode(r.body);
        return v is Map ? '${v['name'] ?? ''}' : null;
      }
      _lastError = 'HTTP ${r.statusCode}: ${r.body}';
      return null;
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  /// Merge fields into an existing node (Firebase PATCH via REST).
  /// Returns true only when the DB really accepted the change.
  Future<bool> patch(String path, Map<String, dynamic> data) async {
    _lastError = null;
    try {
      final r = await http
          .patch(Uri.parse('$base/$path.json'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) return true;
      _lastError = 'HTTP ${r.statusCode}: ${r.body}';
      return false;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
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
  ///
  /// Item 9 CRITICAL FIX: the row id MUST be the real Firebase push key of
  /// videoNew/<folder>/<key> — the old code used video['key'] when present,
  /// which often differs from the actual path, so every like/comment PATCH
  /// created a ghost node instead of updating the visible video. Likes and
  /// comments now always hit the exact row the user is looking at.
  Future<List<Map<String, dynamic>>> videosFlat() async {
    final v = await get('videoNew');
    final out = <Map<String, dynamic>>[];
    if (v is Map) {
      v.forEach((folder, items) {
        if (items is Map) {
          items.forEach((key, video) {
            if (video is Map) {
              out.add({
                'id': '$key',
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

  /// Per-tag videos: videoNew/<tag> is one folder (same push-key rule).
  Future<List<Map<String, dynamic>>> videosOfTag(String tag) async {
    final v = await get('videoNew/$tag');
    final out = <Map<String, dynamic>>[];
    if (v is Map) {
      v.forEach((key, video) {
        if (video is Map) {
          out.add({
            'id': '$key',
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
      commentsIn(videoId);

  // ---------------------------------------------------------------------
  // Video comments — CANONICAL BUCKET FIX (the 4th report of "comment bashi
  // video ayne nabetawa"). Verified against the LIVE database:
  //   • every videoNew row carries a `date` field (millis string);
  //   • the original Sketchware app keyed comments by that date:
  //     CommentVideo/<date>/<pushKey>/{userrr,commenttt,date,...} — 66 of
  //     136 videos have their real comments there;
  //   • earlier Flutter builds wrote CommentVideo/<videoNew pushKey> instead
  //     — an EMPTY node, so reads always showed "هیچ سەرنجێک نییە" and new
  //     comments landed in ghost buckets the original app/admin never saw.
  // Writes now go to ONE canonical bucket (the legacy `date` one) and reads
  // merge both shapes so nothing is lost.
  // ---------------------------------------------------------------------

  /// Canonical comment bucket id for a video row: the legacy `date` field,
  /// falling back to the row `key`, then the flattened row id.
  static String commentIdFor(Map<String, dynamic> v) {
    final date = '${v['date'] ?? ''}'.trim();
    if (date.isNotEmpty && date != 'null' && int.tryParse(date) != null) {
      return date;
    }
    final key = '${v['key'] ?? v['id'] ?? ''}'.trim();
    return key == 'null' ? '' : key;
  }

  /// Secondary bucket earlier Flutter builds wrote to (the videoNew push
  /// key). Read-only — used only to still show those old comments.
  static String altCommentIdFor(Map<String, dynamic> v) {
    final id = '${v['id'] ?? ''}'.trim();
    return id == commentIdFor(v) || id == 'null' ? '' : id;
  }

  /// Merged comments for a video row: canonical bucket + legacy Flutter-era
  /// bucket, deduped (comment_key first, content as fallback), newest first.
  /// Each row carries a hidden `_bucket` field so the admin deletes the
  /// exact node it came from.
  Future<List<Map<String, dynamic>>> commentsForVideo(
      Map<String, dynamic> v) async {
    return commentsForIds(commentIdFor(v), altCommentIdFor(v));
  }

  Future<List<Map<String, dynamic>>> commentsForIds(
      String mainId, String altId) async {
    final buckets = <String>[
      if (mainId.trim().isNotEmpty) mainId.trim(),
      if (altId.trim().isNotEmpty) altId.trim()
    ];
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final b in buckets) {
      for (final c in await commentsIn(b)) {
        final ck = '${c['comment_key'] ?? ''}'.trim();
        final sig = ck.isNotEmpty
            ? ck
            : '${c['userrr'] ?? ''}|${c['commenttt'] ?? ''}|${c['date'] ?? ''}';
        if (!seen.add(sig)) continue;
        out.add({...c, '_bucket': b});
      }
    }
    out.sort((a, b) {
      final da = int.tryParse('${a['date'] ?? ''}') ?? 0;
      final db = int.tryParse('${b['date'] ?? ''}') ?? 0;
      return db.compareTo(da);
    });
    return out;
  }

  /// Read ONE CommentVideo/<bucket> WITHOUT the generic list() unwrapping:
  /// list() strips the outer map when a bucket holds exactly one comment,
  /// which replaced the comment's push key with the video id — that broke
  /// single-comment display AND made the admin delete the wrong node.
  /// Handles the legacy shapes too: {pushKey: {...}}, a JSON string array
  /// (Sketchware) and indexed keys 0,1,2.
  Future<List<Map<String, dynamic>>> commentsIn(String bucket) async {
    final b = bucket.trim();
    if (b.isEmpty || b == 'null') return [];
    final v = await get('CommentVideo/$b');
    final out = <Map<String, dynamic>>[];
    if (v is Map) {
      v.forEach((key, c) {
        if (c is Map) {
          out.add({'id': '$key', ...Map<String, dynamic>.from(c)});
        }
      });
    } else if (v is List) {
      for (var i = 0; i < v.length; i++) {
        final c = v[i];
        if (c is Map) out.add({'id': '$i', ...Map<String, dynamic>.from(c)});
      }
    } else if (v is String && v.trim().startsWith('[')) {
      try {
        final arr = jsonDecode(v);
        if (arr is List) {
          for (var i = 0; i < arr.length; i++) {
            final c = arr[i];
            if (c is Map) out.add({'id': '$i', ...Map<String, dynamic>.from(c)});
          }
        }
      } catch (_) {
        // keep whatever we have
      }
    }
    return out;
  }

  Future<void> sendFeedback(Map<String, dynamic> data) =>
      push('feedback', data).then<void>((_) {});

  /// Write to the CANONICAL bucket (CommentVideo/<date>) so new comments
  /// merge with the legacy ones and stay visible to the original app/admin.
  Future<bool> sendCommentForVideo(
          Map<String, dynamic> v, Map<String, dynamic> data) =>
      sendComment(commentIdFor(v), data);
  Future<bool> sendComment(String videoId, Map<String, dynamic> data) =>
      push('CommentVideo/$videoId', data).then<bool>((k) => k != null);

  /// Item 9: the like counter lives on the video row (field "like" or
  /// "comment"); increment it in the DB and return the new value, keeping
  /// the per-device "already liked" guard in prefs. Returns null (with
  /// lastError set) when the write failed so the UI can warn the user.
  ///
  /// Data-loss guard: if the READ of the current value fails (timeout, HTTP
  /// error) we must NOT patch — the old code patched cur+1 with cur=0,
  /// silently RESETTING a counter like 56 -> 1 on a network hiccup.
  Future<int?> likeVideo(String folder, String videoKey, String field) async {
    try {
      final v = await get('videoNew/$folder/$videoKey/$field');
      if (v == null && _lastError != null) return null; // read failed — abort
      final cur = int.tryParse('$v') ?? 0;
      final next = cur + 1;
      final ok = await patch('videoNew/$folder/$videoKey', {field: '$next'});
      if (!ok) return null;
      return next;
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }
}
