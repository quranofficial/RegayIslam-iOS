import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/rtdb.dart';
import '../../core/ui.dart' show sharePage;
import '../../data/favorites.dart';
import 'video_player_screen.dart';

/// Original: ListvideokanActivity — real Firebase shape:
///   videoNew/<folder>/<pushKey>/{name,url,comment,like,view,timevideo,date}
///   videoall  = JSON-string array of {image, name, tag} (the folders)
/// Videos are mp4 files on github.com/quranofficial/Videokan and play
/// in-app like PlayvideoActivity. Users submit videos to "feedbackvideo"
/// for review, and per-video comments live in "commentvideo/<id>".
class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});
  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _tags = [];
  Map<String, dynamic>? _selectedTag;
  bool _loading = true;
  bool _failed = false; // list is empty because the request failed
  String? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_tags.isEmpty) _tags = await Rtdb.I.videoTags();
    List<Map<String, dynamic>> v;
    final tagKey = _selectedTag == null ? '' : '${_selectedTag!['tag'] ?? ''}';
    v = tagKey.isEmpty
        ? await Rtdb.I.videosFlat()
        : await Rtdb.I.videosOfTag(tagKey);
    // newest first (date is millis in a string)
    v.sort((a, b) {
      final da = int.tryParse('${a['date'] ?? a['key'] ?? 0}') ?? 0;
      final db = int.tryParse('${b['date'] ?? b['key'] ?? 0}') ?? 0;
      return db.compareTo(da);
    });
    if (!mounted) return;
    setState(() {
      _videos = v;
      _loading = false;
      // Empty because the DB/network request failed -> offer a retry,
      // otherwise the plain "no videos" message.
      _failed = v.isEmpty && Rtdb.I.lastError != null;
      _error = v.isEmpty
          ? (_failed
              ? 'نەتوانرا ڤیدیۆکان بار بکرێن — ${Rtdb.I.lastError}'
              : 'هیچ ڤیدیۆیەک بەردەست نییە')
          : null;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_q.isEmpty) return _videos;
    return _videos
        .where((v) => '${v['name'] ?? v['title'] ?? ''}'
            .toLowerCase()
            .contains(_q.toLowerCase()))
        .toList();
  }

  String _link(Map<String, dynamic> v) =>
      '${v['url'] ?? v['link'] ?? v['video'] ?? ''}'.trim();

  void _open(Map<String, dynamic> v) {
    final link = _link(v);
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لینکی ڤیدیۆ لە Firebase نییە')));
      return;
    }
    final uri = Uri.tryParse(Uri.encodeFull(link));
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لینکی ڤیدیۆ دروست نییە')));
      return;
    }
    // YouTube links open externally, direct files play in-app.
    final yt = link.contains('youtube.com') || link.contains('youtu.be');
    if (yt) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
              title: '${v['name'] ?? v['title'] ?? 'ڤیدیۆ'}', url: link,
              folder: '${v['folder'] ?? ''}',
              videoKey: '${v['id'] ?? ''}',
              initialLike: int.tryParse('${v['like']}') ?? 0,
              initialComment: int.tryParse('${v['comment']}') ?? 0)));
    }
  }

  // Original: the FAB form posts {name, video, device_id, namemamosta} to
  // "feedbackvideo"; the admin reviews before the video is approved.
  Future<void> _postVideo() async {
    final nameC = TextEditingController();
    final linkC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ناردنی ڤیدیۆ'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: nameC,
              decoration: const InputDecoration(
                  hintText: 'ناوی ڤیدیۆکە', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(
              controller: linkC,
              decoration: const InputDecoration(
                  hintText: 'لینکی ڤیدیۆکە', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          const Text(
              'تێبینی: پێش ناردنی ڤیدیۆ ڕەچاوی یاساکانی ئەپەکە بکە، ڤیدیۆکەت پێداچوونەوەی بۆ ئەکرێ پاشان قبووڵ دەکرێت.',
              style: TextStyle(fontSize: 11)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('لابردن')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('باشە')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final name = nameC.text.trim();
    final link = linkC.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تکایە سەرەتا ناوی ڤیدیۆکە بنووسە')));
      return;
    }
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تکایە سەرەتا لینکی ڤیدیۆکە بنووسە')));
      return;
    }
    await Rtdb.I.push('feedbackvideo', {
      'name': name,
      'video': link,
      'device_id': 'flutter-${DateTime.now().millisecondsSinceEpoch}',
      'namemamosta':
          _selectedTag == null ? '' : '${_selectedTag!['name'] ?? ''}',
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'ناردن سەرکەوتوو بوو. چاوەروان بە بەزووترین کات پێداچوونەوە بۆ ڤیدیۆکە ئەکرێ و قبووڵ ئەکرێت.')));
  }

  /// Item 9: a real like — increments the counter in
  /// videoNew/<folder>/<key>/like, updates the row on screen immediately and
  /// keeps the per-device "already liked" guard in prefs.
  Future<void> _like(Map<String, dynamic> v) async {
    final id = '${v['id'] ?? ''}';
    final folder = '${v['folder'] ?? ''}';
    if (id.isEmpty) return;
    if (AppPrefs.I.isVideoLiked(id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('پێشتر لایکت کردووە'),
          duration: Duration(milliseconds: 800)));
      return;
    }
    final before = int.tryParse('${v['like']}') ?? 0;
    setState(() => v['like'] = before + 1); // optimistic
    final next = await Rtdb.I.likeVideo(folder, id, 'like');
    if (!mounted) return;
    if (next != null) {
      AppPrefs.I.setVideoLiked(id, true);
      setState(() => v['like'] = next);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('لایک کرا ❤️'),
          duration: Duration(milliseconds: 900)));
    } else {
      // rollback the optimistic value on failure
      setState(() => v['like'] = before);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'لایک سەرکەوتوو نەبوو — ${Rtdb.I.lastError ?? 'ئینتەرنێت بپشکنە'}')));
    }
  }

  /// Item 9: comments bind to the video's stable push key and refresh the
  /// visible counter as soon as the sheet closes.
  Future<void> _comments(Map<String, dynamic> v) async {
    final id = '${v['id'] ?? ''}'.trim().isNotEmpty
        ? '${v['id']}'
        : '${v['date'] ?? v['name'] ?? 'video'}';
    final folder = '${v['folder'] ?? ''}';
    final key = '${v['id'] ?? ''}';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPrefs.I.day ? Colors.white : AppColors.nightCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) =>
          CommentsSheet(videoId: id, folder: folder, videoKey: key,
              onCounted: (n) { if (mounted) setState(() => v['comment'] = n); }),
    );
    if (!mounted) return;
    // Re-read the row so like/comment counters reflect the database.
    final fresh = await Rtdb.I.get('videoNew/$folder/$key');
    if (fresh is Map && mounted) {
      setState(() {
        v['like'] = '${fresh['like'] ?? v['like'] ?? 0}';
        v['comment'] = '${fresh['comment'] ?? v['comment'] ?? 0}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final accent = dark ? AppColors.gold : AppColors.primaryDark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('ڤیدیۆی ئاینی',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              tooltip: 'ناردنی ڤیدیۆ',
              onPressed: _postVideo,
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: Colors.white),
            ),
            IconButton(
              tooltip: 'هاوبەشی',
              onPressed: () => sharePage('ڤیدیۆی ئاینی — خوێندن، بانگ و زیکر',
                  title: 'ڤیدیۆی ئاینی'),
              icon: const Icon(Icons.share_rounded, color: Colors.white),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: txt.withOpacity(.6), height: 1.6)),
                      ),
                      if (_failed) ...[
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _loading = true);
                            _load();
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              foregroundColor: Colors.white),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('دووبارە هەوڵبدەرەوە'),
                        ),
                      ],
                    ]),
                  )
                : Column(children: [
                    if (_tags.isNotEmpty)
                      SizedBox(
                        height: 46,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            ChoiceChip(
                                label: const Text('هەموو'),
                                selected: _selectedTag == null,
                                selectedColor: AppColors.primaryDark,
                                labelStyle: TextStyle(
                                    color: _selectedTag == null
                                        ? Colors.white
                                        : txt),
                                onSelected: (_) {
                                  setState(() { _selectedTag = null; _loading = true; });
                                  _load();
                                }),
                            const SizedBox(width: 6),
                            for (final t in _tags)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: ChoiceChip(
                                    label:
                                        Text('${t['name'] ?? t['tag'] ?? ''}'),
                                    selected: _selectedTag != null &&
                                        '${_selectedTag!['tag'] ?? ''}' ==
                                            '${t['tag'] ?? ''}',
                                    selectedColor: AppColors.primaryDark,
                                    labelStyle: TextStyle(
                                        color: (_selectedTag != null &&
                                                '${_selectedTag!['tag'] ?? ''}' ==
                                                    '${t['tag'] ?? ''}')
                                            ? Colors.white
                                            : txt),
                                    onSelected: (_) {
                                      setState(() { _selectedTag = t; _loading = true; });
                                      _load();
                                    }),
                              ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        onChanged: (v) => setState(() => _q = v),
                        decoration: InputDecoration(
                          hintText: 'گەڕان لە ڤیدیۆکان...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: dark ? AppColors.nightCard : Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final v = _filtered[i];
                          final title = '${v['name'] ?? 'ڤیدیۆ'}';
                          final id = '${v['id'] ?? ''}';
                          final likes = int.tryParse('${v['like']}') ?? 0;
                          final comments = int.tryParse('${v['comment']}') ?? 0;
                          final liked = AppPrefs.I.isVideoLiked(id);
                          final time = '${v['timevideo'] ?? ''}';
                          return Card(
                            color: dark ? AppColors.nightCard : Colors.white,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              onTap: () => _open(v),
                              leading: Container(
                                width: 54, height: 54,
                                decoration: BoxDecoration(
                                    color:
                                        AppColors.primaryDark.withOpacity(.1),
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.ondemand_video_rounded,
                                    color: AppColors.primaryDark)),
                              title: Text(title,
                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.bold,
                                      fontSize: 13.5, color: txt)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(children: [
                                  if (time.isNotEmpty)
                                    Text('$time   ',
                                        style: TextStyle(fontSize: 11,
                                            color: txt.withOpacity(.55))),
                                  InkWell(
                                    onTap: () => _like(v),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Row(children: [
                                        Icon(Icons.favorite_rounded,
                                            size: 13,
                                            color: liked
                                                ? const Color(0xFFE91E63)
                                                : accent),
                                        Text(' $likes   ',
                                            style: TextStyle(fontSize: 11,
                                                color: txt.withOpacity(.55))),
                                      ]),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _comments(v),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Row(children: [
                                        Icon(Icons.comment_rounded,
                                            size: 13, color: accent),
                                        Text(' $comments',
                                            style: TextStyle(fontSize: 11,
                                                color: txt.withOpacity(.55))),
                                      ]),
                                    ),
                                  ),
                                ]),
                              ),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                  tooltip: 'لایک',
                                  onPressed: () => _like(v),
                                  icon: Icon(
                                      liked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 22,
                                      color: liked
                                          ? const Color(0xFFE91E63)
                                          : accent)),
                                IconButton(
                                  tooltip: 'سەرنجەکان',
                                  onPressed: () => _comments(v),
                                  icon: Icon(Icons.comment_rounded,
                                      size: 22, color: accent)),
                                FavoriteButton(
                                    id: 'video::${v['id'] ?? title}',
                                    title: title,
                                    content: _link(v),
                                    route: 'video::${v['id'] ?? title}'),
                                const Icon(Icons.play_circle_rounded,
                                    size: 30, color: AppColors.primaryDark),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
                  ]),
      ),
    );
  }
}

/// Original: the comment dialog over "commentvideo" — {userrr, commenttt,
/// date, comment_key, uid, verify}; stored per video id.
/// Public + reusable so VideoPlayerScreen can open it too.
class CommentsSheet extends StatefulWidget {
  final String videoId;
  final String folder;
  final String videoKey;
  final ValueChanged<int>? onCounted;
  const CommentsSheet(
      {super.key, required this.videoId, this.folder = '', this.videoKey = '',
      this.onCounted});
  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _sending = false;
  final TextEditingController _nameC = TextEditingController();
  final TextEditingController _textC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameC.text = AppPrefs.I.commentName;
    _load();
  }

  Future<void> _load() async {
    final v = await Rtdb.I.comments(widget.videoId);
    if (!mounted) return;
    setState(() { _items = v.reversed.toList(); _loading = false; });
    widget.onCounted?.call(_items.length);
  }

  /// "ئێستا / ٥ خولەک لەمەوبەر / ٢ کاتژمێر لەمەوبەر / ٣ ڕۆژ لەمەوبەر"
  String _when(Map<String, dynamic> m) {
    final ms = int.tryParse('${m['date'] ?? ''}') ?? 0;
    if (ms <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'ئێستا';
    if (diff.inMinutes < 60) return '${diff.inMinutes} خولەک لەمەوبەر';
    if (diff.inHours < 24) return '${diff.inHours} کاتژمێر لەمەوبەر';
    if (diff.inDays < 30) return '${diff.inDays} ڕۆژ لەمەوبەر';
    return '${d.year}/${d.month}/${d.day}';
  }

  /// Sends the comment and STAYS OPEN: on failure the sheet is kept with an
  /// error snack; on success the list reloads and the video's comment
  /// counter is incremented in the DB and pushed to the caller.
  Future<void> _send() async {
    final text = _textC.text.trim();
    final name = _nameC.text.trim();
    if (text.isEmpty || _sending) {
      if (text.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تکایە سەرنجەکەت بنووسە'),
            duration: Duration(milliseconds: 800)));
      }
      return;
    }
    setState(() => _sending = true);
    AppPrefs.I.commentName = name;
    final key = 'c-${DateTime.now().millisecondsSinceEpoch}';
    final ok = await Rtdb.I.sendComment(widget.videoId, {
      'userrr': name,
      'commenttt': text,
      'date': DateTime.now().millisecondsSinceEpoch.toString(),
      'comment_key': key,
      'uid': 'flutter',
      'verify': 'true',
      'video_id': widget.videoId,
    });
    if (!ok) {
      // Keep the sheet open and tell the user why nothing was sent.
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'سەرنجەکەت نەنێردرا — ${Rtdb.I.lastError ?? 'دووبارە هەوڵبدە'}')));
      return;
    }
    _textC.clear();
    await _load();
    // Item 9: keep the comment counter on the video row in sync.
    var counted = _items.length;
    if (widget.folder.isNotEmpty && widget.videoKey.isNotEmpty) {
      final n = await Rtdb.I.likeVideo(widget.folder, widget.videoKey, 'comment');
      if (n != null) counted = n;
    }
    widget.onCounted?.call(counted);
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('سەرنجەکەت نێردرا ✅'),
        duration: Duration(milliseconds: 900)));
    // The sheet stays open so the user can keep commenting.
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .72,
          child: Column(children: [
            const SizedBox(height: 10),
            Container(width: 42, height: 4,
                decoration: BoxDecoration(color: Colors.grey,
                    borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('سەرنجەکان', style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: txt)),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? Center(child: Text('هێشتا هیچ سەرنجێک نییە',
                          style: TextStyle(color: txt.withOpacity(.5))))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final m = _items[i];
                            final user = '${m['userrr'] ?? ''}'.trim();
                            final when = _when(m);
                            return ListTile(
                              leading: CircleAvatar(
                                  backgroundColor:
                                      AppColors.primaryDark.withOpacity(.12),
                                  child: Text(
                                      user.isEmpty ? '?' : user.characters.first,
                                      style: const TextStyle(
                                          color: AppColors.primaryDark))),
                              title: Text(user,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13, color: txt)),
                              subtitle: Text('${m['commenttt'] ?? ''}',
                                  style: TextStyle(fontSize: 13, color: txt)),
                              trailing: when.isEmpty
                                  ? null
                                  : Text(when,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: txt.withOpacity(.45))),
                            );
                          },
                        ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _textC,
                    decoration: InputDecoration(
                      hintText: 'سەرنجەکەت بنووسە...',
                      filled: true,
                      fillColor: dark ? AppColors.nightBg : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(
                        onPressed: _send,
                        icon: const Icon(Icons.send_rounded,
                            color: AppColors.primaryDark)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: TextField(
                controller: _nameC,
                decoration: const InputDecoration(
                  hintText: 'ناوی خۆت (بۆ سەرنجەکان)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
