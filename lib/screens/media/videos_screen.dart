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
  Map<String, String> _tagName = {}; // folder id -> tag name (card chips)
  bool _loading = true;
  bool _failed = false; // list is empty because the request failed
  String? _error;
  String _q = '';
  final TextEditingController _searchC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh || _tags.isEmpty) _tags = await Rtdb.I.videoTags();
    _tagName = {
      for (final t in _tags)
        if ('${t['tag'] ?? ''}'.trim().isNotEmpty)
          '${t['tag']}': '${t['name'] ?? ''}',
    };
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

  /// Pull-to-refresh: re-fetch tags + videos, keep the current filters.
  Future<void> _refresh() => _load(refresh: true);

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
              commentId: Rtdb.commentIdFor(v),
              altCommentId: Rtdb.altCommentIdFor(v),
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

  /// Comments bind to the video's CANONICAL bucket (the legacy `date` node —
  /// see Rtdb.commentIdFor) so new comments MERGE with the old Sketchware
  /// ones; the push-key bucket used by earlier builds is still read too, so
  /// nothing the user wrote before disappears.
  Future<void> _comments(Map<String, dynamic> v) async {
    final folder = '${v['folder'] ?? ''}';
    final key = '${v['id'] ?? ''}';
    if (key.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPrefs.I.day ? Colors.white : AppColors.nightCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => CommentsSheet(
          videoId: Rtdb.commentIdFor(v),
          altId: Rtdb.altCommentIdFor(v),
          folder: folder,
          videoKey: key,
          onCounted: (n) {
            if (mounted) setState(() => v['comment'] = n);
          }),
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
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: TextField(
                        controller: _searchC,
                        onChanged: (v) => setState(() => _q = v),
                        decoration: InputDecoration(
                          hintText: 'گەڕان لە ڤیدیۆکان...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _q.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'سڕینەوەی گەڕان',
                                  onPressed: () {
                                    _searchC.clear();
                                    setState(() => _q = '');
                                  },
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18)),
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
                    // Count badge — the user always sees how many videos
                    // (or search hits) are in front of them.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: accent.withOpacity(.12),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('ڤیدیۆکان: ${_filtered.length}',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: accent)),
                        ),
                        if (_q.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('ئەنجامی گەڕان بۆ «$_q»',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11, color: txt.withOpacity(.6))),
                          ),
                        ],
                      ]),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refresh,
                        color: AppColors.primaryDark,
                        child: _filtered.isEmpty
                            ? ListView(children: [
                                Padding(
                                  padding: const EdgeInsets.all(36),
                                  child: Column(children: [
                                    Icon(Icons.search_off_rounded,
                                        size: 44, color: txt.withOpacity(.3)),
                                    const SizedBox(height: 12),
                                    Text(
                                        _q.isEmpty
                                            ? 'هیچ ڤیدیۆیەک بەردەست نییە'
                                            : 'هیچ ڤیدیۆیەک نەدۆزرایەوە بۆ «$_q»',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            height: 1.6,
                                            color: txt.withOpacity(.6))),
                                    if (_q.isNotEmpty)
                                      TextButton(
                                          onPressed: () {
                                            _searchC.clear();
                                            setState(() => _q = '');
                                          },
                                          child: const Text('سڕینەوەی گەڕان')),
                                  ]),
                                ),
                              ])
                            : GridView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 4, 12, 16),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 260,
                                        mainAxisSpacing: 10,
                                        crossAxisSpacing: 10,
                                        childAspectRatio: 0.78),
                                itemCount: _filtered.length,
                                itemBuilder: (context, i) =>
                                    _videoCard(_filtered[i], dark, txt, accent),
                              ),
                      ),
                    ),
                  ]),
      ),
    );
  }

  /// item 7 — the NEW video card: a 2-column grid of poster-style cards
  /// (thumbnail block with a big play bubble, duration chip, tag pill and a
  /// like/comment footer) replacing the old cramped list rows.
  Widget _videoCard(Map<String, dynamic> v, bool dark, Color txt,
      Color accent) {
    final title = '${v['name'] ?? v['title'] ?? 'ڤیدیۆ'}';
    final id = '${v['id'] ?? ''}';
    final likes = int.tryParse('${v['like']}') ?? 0;
    final comments = int.tryParse('${v['comment']}') ?? 0;
    final liked = AppPrefs.I.isVideoLiked(id);
    final time = '${v['timevideo'] ?? ''}';
    final tagName = _tagName['${v['folder'] ?? ''}'] ??
        (_selectedTag == null ? '' : '${_selectedTag!['name'] ?? ''}');
    return Container(
      decoration: BoxDecoration(
          color: dark ? AppColors.nightCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: dark ? Colors.white10 : Colors.black.withOpacity(.06))),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(v),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // poster block
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              Container(
                decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryDark,
                        AppColors.primaryDark.withOpacity(.45),
                        (dark ? AppColors.gold : AppColors.primaryDark)
                            .withOpacity(.75),
                      ],
                    )),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.14),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded,
                      size: 40, color: Colors.white),
                ),
              ),
              if (time.isNotEmpty)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.65),
                        borderRadius: BorderRadius.circular(7)),
                    child: Text(time,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              if (tagName.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.45),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(tagName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      height: 1.35,
                      color: txt)),
              const SizedBox(height: 6),
              Row(children: [
                InkWell(
                  onTap: () => _like(v),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 2, vertical: 2),
                    child: Row(children: [
                      Icon(
                          liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 15,
                          color: liked
                              ? const Color(0xFFE91E63)
                              : accent),
                      Text(' $likes',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: liked
                                  ? const Color(0xFFE91E63)
                                  : txt.withOpacity(.6))),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => _comments(v),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 2, vertical: 2),
                    child: Row(children: [
                      Icon(Icons.comment_rounded, size: 15, color: accent),
                      Text(' $comments',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: txt.withOpacity(.6))),
                    ]),
                  ),
                ),
                const Spacer(),
                FavoriteButton(
                    id: 'video::${v['id'] ?? title}',
                    title: title,
                    content: _link(v),
                    route: 'video::${v['id'] ?? title}'),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

}

/// Original: the comment dialog over "CommentVideo" — {userrr, commenttt,
/// date, comment_key, uid, verify}; stored per video.
/// Public + reusable so VideoPlayerScreen can open it too.
///
/// CANONICAL BUCKET FIX: videoId is the video's legacy bucket id (the row's
/// `date` millis — see Rtdb.commentIdFor); altId is the secondary push-key
/// bucket earlier builds wrote to and is READ-ONLY. Reads merge both so old
/// comments always show; writes go to the canonical bucket only.
class CommentsSheet extends StatefulWidget {
  final String videoId;
  final String altId;
  final String folder;
  final String videoKey;
  final ValueChanged<int>? onCounted;
  const CommentsSheet(
      {super.key,
      required this.videoId,
      this.altId = '',
      this.folder = '',
      this.videoKey = '',
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
    // Merged read: canonical bucket + legacy Flutter-era bucket, deduped,
    // newest first (see Rtdb.commentsForIds).
    final v = await Rtdb.I.commentsForIds(widget.videoId, widget.altId);
    if (!mounted) return;
    setState(() { _items = v; _loading = false; });
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

  /// Sends the comment and STAYS OPEN: on failure the sheet is kept with a
  /// clear error snack (no fake success); on success the list reloads and
  /// the video's comment counter is incremented in the DB and pushed to the
  /// caller.
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
    if (widget.videoId.trim().isEmpty) {
      // No valid bucket id -> a write would go to a ghost node. Say so.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('نەتوانرا کۆمێنت بنێرێت — ئینتەرنێت بپشکنە')));
      return;
    }
    setState(() => _sending = true);
    AppPrefs.I.commentName = name;
    final key = 'c-${DateTime.now().millisecondsSinceEpoch}';
    // Write to the CANONICAL bucket so the comment merges with the legacy
    // ones and is visible to the original app + admin moderation.
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
      final err = Rtdb.I.lastError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err == null || err.isEmpty
              ? 'نەتوانرا کۆمێنت بنێرێت — ئینتەرنێت بپشکنە'
              : 'نەتوانرا کۆمێنت بنێرێت — ئینتەرنێت بپشکنە\n($err)')));
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
