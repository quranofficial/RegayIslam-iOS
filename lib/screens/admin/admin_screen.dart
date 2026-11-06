import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/rtdb.dart';

/// Item 22 + feedback 15: the in-app admin panel ("پانێلی بەڕێوەبەر"),
/// rebuilt as a clean two-level design:
///   • Main page — a live dashboard (videos / video sections / books /
///     live channels / comments awaiting review / last notification)
///     plus a grid of tool cards.
///   • One sub-page per tool: notification, start dialog, videos
///     (add video / add tag / manage & delete), books, GitHub upload,
///     Firebase node editor, comment moderation and the operation log.
/// Every write checks the returned bool/key from Rtdb and reports it
/// (✅ or 'سەرکەوتوو نەبوو — lastError'), and every action is appended
/// to a shared log kept in the main screen state (badge on the لۆگ card).
///
/// Opened from ڕێکخستن → پانێلی بەڕێوەبەر (password: kAdminPassword).

/// Kurdish/Arabic-Indic numerals for the dashboard numbers, following the
/// app-wide "useKurdishDigits" preference.
String _kn(int n) {
  if (!AppPrefs.I.useKurdishDigits) return '$n';
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return '$n'.split('').map((c) => d[int.parse(c)]).join();
}

/// ---------------------------------------------------------------------------
/// Shared base state for every admin sub-page: theming + small UI helpers so
/// all pages look and behave exactly the same.
/// ---------------------------------------------------------------------------
abstract class _AdminPageState<T extends StatefulWidget> extends State<T> {
  bool busy = false;

  bool get dark => !AppPrefs.I.day;
  Color get bg => dark ? AppColors.nightBg : const Color(0xFFF4F5F7);
  Color get card => dark ? AppColors.nightCard : Colors.white;
  Color get accent => dark ? AppColors.gold : AppColors.primaryDark;
  Color get txt => dark ? Colors.white : Colors.black87;
  List<BoxShadow> get shadow => dark
      ? const <BoxShadow>[]
      : <BoxShadow>[
          BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ];

  void toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  /// Standard failure message for every failed write (Rtdb sets lastError).
  void failToast() =>
      toast('سەرکەوتوو نەبوو — ${Rtdb.I.lastError ?? 'پەیوەندی نەکرا'}');

  Future<bool> confirm(String title, String msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('نەخێر')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('بەڵێ'),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }

  Widget field(TextEditingController c, String hint,
          {int maxLines = 1, bool obscure = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          obscureText: obscure,
          style: TextStyle(fontSize: 13.5, color: txt),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12.5, color: txt.withOpacity(.45)),
            isDense: true,
            filled: true,
            fillColor:
                dark ? Colors.white.withOpacity(.05) : Colors.black.withOpacity(.03),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: txt.withOpacity(.15))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accent)),
          ),
        ),
      );

  Widget button(String label, VoidCallback? onTap,
          {IconData? icon, Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: color ?? AppColors.primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: busy ? null : onTap,
            icon: Icon(icon ?? Icons.send_rounded, size: 18),
            label: Text(label,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ),
      );

  Widget section(String t) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Row(children: [
          Container(
              width: 4,
              height: 15,
              decoration: BoxDecoration(
                  color: accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(t,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: txt)),
        ]),
      );

  Widget note(String t) => Text(t,
      style: TextStyle(
          fontSize: 11.5, color: txt.withOpacity(.55), height: 1.6));

  Widget get spinner => const Center(
        child: Padding(
          padding: EdgeInsets.all(10),
          child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );

  Widget list(List<Widget> children) => ListView(
        padding: const EdgeInsets.all(14),
        children: children,
      );

  Widget pageScaffold(String title, Widget body,
          {List<Widget> actions = const []}) =>
      Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor:
                dark ? AppColors.nightCard : AppColors.primaryDark,
            elevation: 0,
            title: Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
            actions: actions,
          ),
          body: body,
        ),
      );
}

/// ---------------------------------------------------------------------------
/// MAIN PAGE — dashboard + tools grid
/// ---------------------------------------------------------------------------
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends _AdminPageState<AdminScreen> {
  bool _loading = true;
  int _videos = 0, _tags = 0, _books = 0, _live = 0, _commentsTotal = 0;
  String _lastNotif = '—';
  final List<String> _logs = <String>[];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// Shared logger handed to every sub-page: prepends a timestamp and
  /// keeps the newest entry on top.
  void _log(String m) {
    if (!mounted) return;
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() => _logs.insert(0, '$stamp — $m'));
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() => _loading = true);
    final futVideos = Rtdb.I.videosFlat();
    final futTags = Rtdb.I.videoTags();
    final futBooks = Rtdb.I.list('ktebakan');
    final futLive = Rtdb.I.liveChannels();
    final futNotif = Rtdb.I.get('notification');
    final futComments = Rtdb.I.get('CommentVideo');

    final videos = await futVideos;
    final tags = await futTags;
    final books = await futBooks;
    final live = await futLive;
    final notif = await futNotif;

    // CommentVideo/<videoId>/<commentId> — count every comment row.
    int comments = 0;
    final cv = await futComments;
    if (cv is Map) {
      cv.forEach((videoKey, perVideo) {
        if (perVideo is Map) {
          perVideo.forEach((cKey, c) {
            if (c is Map) comments++;
          });
        }
      });
    }

    String notifTitle = '—';
    if (notif is Map) {
      final t = '${notif['title'] ?? ''}'.trim();
      if (t.isNotEmpty) notifTitle = t;
    }

    if (!mounted) return;
    setState(() {
      _videos = videos.length;
      _tags = tags.length;
      _books = books.length;
      _live = live.length;
      _commentsTotal = comments;
      _lastNotif = notifTitle;
      _loading = false;
    });
  }

  Future<void> _open(Widget page) async {
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _loadStats(); // refresh the dashboard after every tool visit
  }

  Future<void> _openLog() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AdminLogPage(
          logs: List<String>.from(_logs),
          onClear: () {
            if (!mounted) return;
            setState(() => _logs.clear());
          },
        ),
      ),
    );
  }

  List<Widget> _tools() => [
        _toolCard(Icons.notifications_active_rounded, 'ئاگادارکردنەوەی نوێ',
            () => _open(_AdminNotificationPage(_log))),
        _toolCard(Icons.campaign_rounded, 'دیالۆگی دەستپێک',
            () => _open(_AdminDialogPage(_log))),
        _toolCard(Icons.ondemand_video_rounded, 'بەڕێوەبردنی ڤیدیۆکان',
            () => _open(_AdminVideosPage(_log))),
        _toolCard(Icons.local_library_rounded, 'کتێبەکان',
            () => _open(_AdminBooksPage(_log))),
        _toolCard(Icons.upload_rounded, 'بارکردنی فایل بۆ GitHub',
            () => _open(_AdminGithubPage(_log))),
        _toolCard(Icons.storage_rounded, 'داتابەیسی Firebase',
            () => _open(_AdminDataPage(_log))),
        _toolCard(Icons.comment_rounded, 'سەرنجەکان',
            () => _open(_AdminCommentsPage(_log))),
        _toolCard(Icons.receipt_long_rounded, 'لۆگی کردارەکان', _openLog,
            badge: _logs.isEmpty ? null : _kn(_logs.length)),
      ];

  Widget _statTile(IconData icon, String label, String value,
      {bool wide = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: txt.withOpacity(.6))),
            ),
          ]),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              _loading ? '…' : value,
              maxLines: 1,
              style: TextStyle(
                  fontSize: wide ? 14 : 18,
                  fontWeight: FontWeight.bold,
                  color: accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolCard(IconData icon, String title, VoidCallback onTap,
      {String? badge}) {
    final Widget iconWidget = badge == null
        ? Icon(icon, size: 26, color: accent)
        : Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 26, color: accent),
              Positioned(
                top: -7,
                left: -10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: card, width: 1.5)),
                  child: Text(badge,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          boxShadow: shadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: txt,
                    height: 1.3)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return pageScaffold(
      'پانێلی بەڕێوەبەر',
      RefreshIndicator(
        color: AppColors.primaryDark,
        backgroundColor: dark ? AppColors.nightCard : Colors.white,
        onRefresh: _loadStats,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14),
          children: [
            section('داشبۆرد'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              padding: EdgeInsets.zero,
              children: [
                _statTile(
                    Icons.ondemand_video_rounded, 'ڤیدیۆکان', _kn(_videos)),
                _statTile(Icons.folder_special_rounded, 'بەشەکانی ڤیدیۆ',
                    _kn(_tags)),
                _statTile(Icons.local_library_rounded, 'کتێبەکان', _kn(_books)),
                _statTile(Icons.live_tv_rounded, 'کەناڵە زیندووەکان',
                    _kn(_live)),
                _statTile(Icons.comment_rounded, 'سەرنجەکان بۆ پێداچوونەوە',
                    _kn(_commentsTotal)),
                _statTile(Icons.notifications_active_rounded,
                    'ئاگادارکردنەوەی کۆتا', _lastNotif,
                    wide: true),
              ],
            ),
            const SizedBox(height: 16),
            section('ئامرازەکان'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              padding: EdgeInsets.zero,
              children: _tools(),
            ),
            const SizedBox(height: 8),
            note('گۆڕانکارییەکان ڕاستەوخۆ لەسەر داتابەیسی Firebase جێبەجێ دەکرێن.'),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)),
                )
              : IconButton(
                  tooltip: 'نوێکردنەوەی زانیارییەکان',
                  onPressed: _loadStats,
                  icon:
                      const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// (1) ئاگادارکردنەوەی نوێ — patch 'notification'
/// ---------------------------------------------------------------------------
class _AdminNotificationPage extends StatefulWidget {
  const _AdminNotificationPage(this.log);
  final void Function(String) log;
  @override
  State<_AdminNotificationPage> createState() => _AdminNotificationPageState();
}

class _AdminNotificationPageState
    extends _AdminPageState<_AdminNotificationPage> {
  final _title = TextEditingController();
  final _text = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty && _text.text.trim().isEmpty) {
      toast('ناونیشان یان دەق بنووسە');
      return;
    }
    setState(() => busy = true);
    final ok = await Rtdb.I.patch('notification', {
      'title': _title.text.trim(),
      'text': _text.text.trim(),
      'date': DateTime.now().millisecondsSinceEpoch.toString(),
      'open': 'true',
    });
    if (mounted) setState(() => busy = false);
    if (ok) {
      widget.log('ئاگادارکردنەوە نێردرا: "${_title.text.trim()}"');
      toast('ئاگادارکردنەوە نێردرا ✅');
      if (mounted) Navigator.pop(context);
    } else {
      widget.log('ناردنی ئاگادارکردنەوە سەرکەوتوو نەبوو');
      failToast();
    }
  }

  @override
  Widget build(BuildContext context) {
    return pageScaffold(
      'ئاگادارکردنەوەی نوێ',
      list([
        field(_title, 'ناونیشانی ئاگادارکردنەوە'),
        field(_text, 'دەقی ئاگادارکردنەوە', maxLines: 4),
        button('ناردنی ئاگادارکردنەوە بۆ هەموو بەکارهێنەران', _send,
            icon: Icons.notifications_active_rounded),
        note(
            'تێبینی: لە کاتی کردنەوەی ئەپەکە بەکارهێنەران ئاگادارکردنەوەکە وەک نامەی سیستەم وەردەگرن.'),
      ]),
    );
  }
}

/// ---------------------------------------------------------------------------
/// (2) دیالۆگی دەستپێک — patch 'dialogg' {dialog:{open,title,text,url,close,ver}}
/// ---------------------------------------------------------------------------
class _AdminDialogPage extends StatefulWidget {
  const _AdminDialogPage(this.log);
  final void Function(String) log;
  @override
  State<_AdminDialogPage> createState() => _AdminDialogPageState();
}

class _AdminDialogPageState extends _AdminPageState<_AdminDialogPage> {
  final _title = TextEditingController();
  final _text = TextEditingController();
  final _url = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => busy = true);
    final ok = await Rtdb.I.patch('dialogg', {
      'dialog': {
        'open': 'true',
        'title': _title.text.trim(),
        'text': _text.text.trim(),
        'url': _url.text.trim(),
        'close': 'داخستن',
        'ver': 'v-${DateTime.now().millisecondsSinceEpoch}',
      }
    });
    if (mounted) setState(() => busy = false);
    if (ok) {
      widget.log('دیالۆگی دەستپێک نوێکرایەوە: "${_title.text.trim()}"');
      toast('دیالۆگەکە پاشەکەوت کرا ✅');
      if (mounted) Navigator.pop(context);
    } else {
      widget.log('پاشەکەوتی دیالۆگ سەرکەوتوو نەبوو');
      failToast();
    }
  }

  @override
  Widget build(BuildContext context) {
    return pageScaffold(
      'دیالۆگی دەستپێک',
      list([
        field(_title, 'ناونیشانی دیالۆگ'),
        field(_text, 'دەقی دیالۆگ', maxLines: 6),
        field(_url, 'لینک (ئارەزوومەندانە)'),
        button('پاشەکەوتی دیالۆگی دەستپێک', _send, icon: Icons.campaign_rounded),
        note(
            'ئەم دیالۆگە لە دەستپێکی ئەپ بۆ هەموو بەکارهێنەران دەردەکەوێت (وشەی "داخستن" خۆکارییە).'),
      ]),
    );
  }
}

/// ---------------------------------------------------------------------------
/// (3) بەڕێوەبردنی ڤیدیۆکان — add video / add tag / manage tag videos
/// ---------------------------------------------------------------------------
class _AdminVideosPage extends StatefulWidget {
  const _AdminVideosPage(this.log);
  final void Function(String) log;
  @override
  State<_AdminVideosPage> createState() => _AdminVideosPageState();
}

class _AdminVideosPageState extends _AdminPageState<_AdminVideosPage> {
  final _tag = TextEditingController();
  final _name = TextEditingController();
  final _url = TextEditingController();
  List<Map<String, dynamic>> _tags = const [];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _tag.dispose();
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    final t = await Rtdb.I.videoTags();
    if (!mounted) return;
    setState(() => _tags = t);
  }

  Future<void> _addVideo() async {
    final tag = _tag.text.trim();
    final name = _name.text.trim();
    final url = _url.text.trim();
    if (tag.isEmpty || name.isEmpty || url.isEmpty) {
      toast('تاگ، ناو و لینک پڕ بکەرەوە');
      return;
    }
    setState(() => busy = true);
    final key = await Rtdb.I.push('videoNew/$tag', {
      'name': name,
      'url': url,
      'like': '0',
      'comment': '0',
      'view': '0',
      'date': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    if (mounted) setState(() => busy = false);
    if (key != null) {
      widget.log('videoNew/$tag + ڤیدیۆ "$name"');
      toast('ڤیدیۆ زیادکرا ✅');
      if (mounted) {
        setState(() {
          _name.clear();
          _url.clear();
        });
      }
    } else {
      widget.log('زیادکردنی ڤیدیۆ سەرکەوتوو نەبوو (videoNew/$tag)');
      failToast();
    }
  }

  Future<void> _addTag() async {
    final tag = _tag.text.trim();
    final name = _name.text.trim();
    if (tag.isEmpty || name.isEmpty) {
      toast('تاگ و ناو پڕ بکەرەوە');
      return;
    }
    setState(() => busy = true);
    final key = await Rtdb.I
        .push('videoall', {'name': name, 'tag': tag, 'image': ''});
    if (mounted) setState(() => busy = false);
    if (key != null) {
      widget.log('videoall + تاگ "$name" ($tag)');
      toast('تاگ زیادکرا ✅');
      _loadTags();
    } else {
      widget.log('زیادکردنی تاگ سەرکەوتوو نەبوو');
      failToast();
    }
  }

  Future<void> _manageTag() async {
    final tag = _tag.text.trim();
    if (tag.isEmpty) {
      toast('ناوی تاگ/فۆڵدەر بنووسە');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: _TagVideosSheet(tag: tag, onLog: widget.log),
      ),
    );
    _loadTags();
  }

  @override
  Widget build(BuildContext context) {
    return pageScaffold(
      'بەڕێوەبردنی ڤیدیۆکان',
      list([
        section('بەشەکانی ئێستا (کرتە بۆ پڕکردنەوەی تاگ)'),
        if (_tags.isEmpty)
          note('هێشتا هیچ بەشێک نییە — لە خوارەوە زیاد بکە')
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in _tags)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: Text('${t['name'] ?? t['tag'] ?? ''}',
                      style: const TextStyle(fontSize: 11)),
                  onPressed: () =>
                      setState(() => _tag.text = '${t['tag'] ?? ''}'),
                ),
            ],
          ),
        const SizedBox(height: 8),
        section('زیادکردنی نوێ'),
        field(_tag, 'تاگ/فۆڵدەری ڤیدیۆ (نموونە: quran)'),
        field(_name, 'ناوی ڤیدیۆ (یان ناوی بەش بۆ تاگ)'),
        field(_url, 'لینکی ڤیدیۆ (mp4)', maxLines: 2),
        button('زیادکردنی ڤیدیۆ بۆ بەشەکە', _addVideo,
            icon: Icons.ondemand_video_rounded),
        button('زیادکردنی تاگ/بەشی نوێ', _addTag,
            icon: Icons.new_label_rounded),
        button('بەڕێوەبردن و سڕینەوەی ڤیدیۆکانی تاگ', _manageTag,
            icon: Icons.manage_search_rounded,
            color: const Color(0xFF455A64)),
        note('ڤیدیۆکان دەچنە ناو نۆدی "videoNew/<تاگ>" و تاگەکان بۆ "videoall".'),
      ]),
    );
  }
}

/// Bottom sheet: videos of one tag with reload + one-tap delete.
class _TagVideosSheet extends StatefulWidget {
  const _TagVideosSheet({required this.tag, required this.onLog});
  final String tag;
  final void Function(String) onLog;
  @override
  State<_TagVideosSheet> createState() => _TagVideosSheetState();
}

class _TagVideosSheetState extends State<_TagVideosSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _videos = const [];

  bool get _dark => !AppPrefs.I.day;

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (mounted) setState(() => _loading = true);
    final v = await Rtdb.I.videosOfTag(widget.tag);
    if (!mounted) return;
    setState(() {
      _videos = v;
      _loading = false;
    });
  }

  Future<void> _delete(Map<String, dynamic> v) async {
    final id = '${v['id'] ?? ''}';
    final name = '${v['name'] ?? id}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('سڕینەوە'),
          content: Text('دڵنیایت لە سڕینەوەی "$name"؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('نەخێر')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('سڕینەوە'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final done = await Rtdb.I.delete('videoNew/${widget.tag}/$id');
    widget.onLog(done
        ? 'videoNew/${widget.tag}/$id سڕدرایەوە'
        : 'سڕینەوەی videoNew/${widget.tag}/$id سەرکەوتوو نەبوو');
    if (!mounted) return;
    if (done) {
      _toast('سڕدرایەوە ✅');
      _reload();
    } else {
      _toast('سەرکەوتوو نەبوو — ${Rtdb.I.lastError ?? 'پەیوەندی نەکرا'}');
    }
  }

  /// Item 20: EDIT an existing video (name and/or URL) in place — the
  /// admin no longer has to delete + re-add a video to fix a typo.
  Future<void> _edit(Map<String, dynamic> v) async {
    final id = '${v['id'] ?? ''}';
    final nameC = TextEditingController(text: '${v['name'] ?? ''}');
    final urlC = TextEditingController(text: '${v['url'] ?? v['video'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('دەستکاری ڤیدیۆ'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: nameC,
                decoration: const InputDecoration(
                    labelText: 'ناوی ڤیدیۆ', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
                controller: urlC,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'لینکی ڤیدیۆ (mp4)',
                    border: OutlineInputBorder())),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('لابردن')),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(d, true),
                child: const Text('پاشەکەوت')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final name = nameC.text.trim();
    final url = urlC.text.trim();
    if (name.isEmpty && url.isEmpty) return;
    final patch = <String, dynamic>{
      if (name.isNotEmpty) 'name': name,
      if (url.isNotEmpty) 'url': url,
    };
    final done = await Rtdb.I.patch('videoNew/${widget.tag}/$id', patch);
    widget.onLog(done
        ? 'videoNew/${widget.tag}/$id نوێکرایەوە (دەستکاری)'
        : 'نوێکردنەوەی videoNew/${widget.tag}/$id سەرکەوتوو نەبوو');
    if (!mounted) return;
    if (done) {
      _toast('نوێکرایەوە ✅');
      _reload();
    } else {
      _toast('سەرکەوتوو نەبوو — ${Rtdb.I.lastError ?? 'پەیوەندی نەکرا'}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = _dark ? Colors.white : Colors.black87;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .75,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: txt.withOpacity(.25),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Expanded(
                child: Text(
                    'ڤیدیۆکانی "${widget.tag}"'
                    '${_loading ? '' : ' (${_videos.length})'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              IconButton(
                  tooltip: 'نوێکردنەوە',
                  onPressed: _reload,
                  icon:
                      const Icon(Icons.refresh_rounded, size: 20)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _videos.isEmpty
                    ? const Center(
                        child: Text('هیچ ڤیدیۆیێک لەم تاگەدا نییە'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _videos.length,
                        itemBuilder: (_, i) {
                          final v = _videos[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.ondemand_video_rounded,
                                color: AppColors.primaryDark),
                            title: Text('${v['name'] ?? v['id'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text('id: ${v['id']}',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: txt.withOpacity(.5))),
                            trailing: Row(mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Item 20: edit-in-place (PATCH)
                                  IconButton(
                                    tooltip: 'دەستکاری',
                                    icon: const Icon(Icons.edit_rounded,
                                        color: AppColors.primaryDark),
                                    onPressed: () => _edit(v),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded,
                                        color: AppColors.red),
                                    onPressed: () => _delete(v),
                                  ),
                                ]),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// (4) کتێبەکان — push 'ktebakan' {name,url,admin,about,image,date}
/// ---------------------------------------------------------------------------
class _AdminBooksPage extends StatefulWidget {
  const _AdminBooksPage(this.log);
  final void Function(String) log;
  @override
  State<_AdminBooksPage> createState() => _AdminBooksPageState();
}

class _AdminBooksPageState extends _AdminPageState<_AdminBooksPage> {
  final _name = TextEditingController();
  final _admin = TextEditingController();
  final _about = TextEditingController();
  final _url = TextEditingController();
  final _image = TextEditingController();
  List<Map<String, dynamic>> _books = const [];
  bool _loadingBooks = false;

  /// Item 20: load the existing books so they can be edited or deleted.
  Future<void> _loadBooks() async {
    setState(() => _loadingBooks = true);
    final rows = await Rtdb.I.list('ktebakan');
    if (!mounted) return;
    setState(() { _books = rows; _loadingBooks = false; });
  }

  Future<void> _editBook(Map<String, dynamic> b) async {
    final id = '${b['id'] ?? ''}';
    final nameC = TextEditingController(text: '${b['name'] ?? ''}');
    final urlC = TextEditingController(text: '${b['url'] ?? ''}');
    final aboutC = TextEditingController(text: '${b['about'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('دەستکاری کتێب'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: nameC,
                decoration: const InputDecoration(
                    labelText: 'ناوی کتێب', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
                controller: urlC,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'لینکی PDF', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
                controller: aboutC,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'کورتە', border: OutlineInputBorder())),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('لابردن')),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(d, true),
                child: const Text('پاشەکەوت')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final name = nameC.text.trim();
    final url = urlC.text.trim();
    if (name.isEmpty && url.isEmpty) return;
    final done = await Rtdb.I.patch('ktebakan/$id', {
      if (name.isNotEmpty) 'name': name,
      if (url.isNotEmpty) 'url': url,
      'about': aboutC.text.trim(),
    });
    widget.log(done
        ? 'ktebakan/$id نوێکرایەوە (دەستکاری)'
        : 'نوێکردنەوەی کتێب سەرکەوتوو نەبوو');
    if (!mounted) return;
    toast(done ? 'کتێب نوێکرایەوە ✅' : 'سەرکەوتوو نەبوو — ${Rtdb.I.lastError ?? ''}');
    if (done) _loadBooks();
  }

  Future<void> _deleteBook(Map<String, dynamic> b) async {
    final id = '${b['id'] ?? ''}';
    final name = '${b['name'] ?? id}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('سڕینەوەی کتێب'),
          content: Text('دڵنیایت لە سڕینەوەی "$name"؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('نەخێر')),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(d, true),
                child: const Text('سڕینەوە')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final done = await Rtdb.I.delete('ktebakan/$id');
    widget.log(done ? 'ktebakan/$id سڕدرایەوە' : 'سڕینەوەی کتێب سەرکەوتوو نەبوو');
    if (!mounted) return;
    toast(done ? 'سڕدرایەوە ✅' : 'سەرکەوتوو نەبوو — ${Rtdb.I.lastError ?? ''}');
    if (done) _loadBooks();
  }

  @override
  void dispose() {
    for (final c in [_name, _admin, _about, _url, _image]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    final url = _url.text.trim();
    if (name.isEmpty || url.isEmpty) {
      toast('ناو و لینکی PDF پڕ بکەرەوە');
      return;
    }
    setState(() => busy = true);
    final key = await Rtdb.I.push('ktebakan', {
      'name': name,
      'url': url,
      'admin': _admin.text.trim(),
      'about': _about.text.trim(),
      'image': _image.text.trim(),
      'date': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    if (mounted) setState(() => busy = false);
    if (key != null) {
      widget.log('ktebakan + کتێب "$name"');
      toast('کتێب زیادکرا ✅');
      if (mounted) {
        setState(() {
          _name.clear();
          _url.clear();
          _about.clear();
        });
      }
    } else {
      widget.log('زیادکردنی کتێب سەرکەوتوو نەبوو');
      failToast();
    }
  }

  @override
  Widget build(BuildContext context) {
    return pageScaffold(
      'کتێبەکان',
      list([
        section('زیادکردنی نوێ'),
        field(_name, 'ناوی کتێب'),
        field(_admin, 'نوسەر'),
        field(_about, 'کورتە', maxLines: 3),
        field(_url, 'لینکی PDF (دەتوانیت لە تابی GitHub باربکەیت و لینکەکە لێرە دابنێیت)',
            maxLines: 2),
        field(_image, 'لینکی وێنەی چاپەمەری (ئارەزوومەندانە)'),
        button('زیادکردنی کتێب بۆ کتێبخانە', _add,
            icon: Icons.local_library_rounded),
        note(
            'کتێبەکان دەچنە ناو نۆدی "ktebakan"ی Firebase و بە خۆکاری لە کتێبخانەی ئەپ دەردەکەون.'),
        // Item 20: manage the existing books — edit + delete.
        section('کتێبەکانی ئێستا (دەستکاری / سڕینەوە)'),
        button('هێنانی لیستی کتێبەکان', _loadBooks,
            icon: Icons.refresh_rounded),
        if (_loadingBooks)
          const Center(child: Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator()))
        else if (_books.isNotEmpty)
          for (final b in _books)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.local_library_rounded,
                    color: AppColors.primaryDark),
                title: Text('${b['name'] ?? ''}', maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      tooltip: 'دەستکاری',
                      icon: const Icon(Icons.edit_rounded,
                          color: AppColors.primaryDark),
                      onPressed: () => _editBook(b)),
                  IconButton(
                      tooltip: 'سڕینەوە',
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.red),
                      onPressed: () => _deleteBook(b)),
                ]),
              ),
            ),
      ]),
    );
  }
}

/// ---------------------------------------------------------------------------
/// (5) بارکردنی فایل بۆ GitHub — PUT /repos/<repo>/contents/<path> (+ sha)
/// ---------------------------------------------------------------------------
class _AdminGithubPage extends StatefulWidget {
  const _AdminGithubPage(this.log);
  final void Function(String) log;
  @override
  State<_AdminGithubPage> createState() => _AdminGithubPageState();
}

class _AdminGithubPageState extends _AdminPageState<_AdminGithubPage> {
  final _token = TextEditingController();
  final _repo = TextEditingController(text: 'quranofficial/Videokan');
  final _path = TextEditingController();
  final _text = TextEditingController();
  bool _saveToken = true;
  String _result = '';

  @override
  void initState() {
    super.initState();
    _token.text = AppPrefs.I.adminGhToken;
  }

  @override
  void dispose() {
    for (final c in [_token, _repo, _path, _text]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Upload an image / file / video / text straight into the GitHub repo
  /// (PUT /contents) and get back the raw link for the app.
  Future<void> _upload({File? file, String? textContent}) async {
    final token = _token.text.trim();
    final repo = _repo.text.trim();
    final path = _path.text.trim().replaceAll(RegExp(r'^/+'), '');
    if (token.isEmpty || repo.isEmpty || path.isEmpty) {
      toast('تۆکن، ریپۆ و ڕێڕەو پڕ بکەرەوە');
      return;
    }
    if (_saveToken) AppPrefs.I.adminGhToken = token;
    String contentB64;
    if (file != null) {
      contentB64 = base64Encode(await file.readAsBytes());
    } else {
      contentB64 = base64Encode(utf8.encode(textContent ?? ''));
    }
    setState(() => busy = true);
    String? link;
    String error = '';
    try {
      // Existing file? then we need its sha to overwrite.
      String? sha;
      final head = await http.get(
          Uri.parse('https://api.github.com/repos/$repo/contents/$path'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/vnd.github+json',
          });
      if (head.statusCode == 200) {
        sha = (jsonDecode(head.body) as Map)['sha']?.toString();
      }
      final r = await http.put(
          Uri.parse('https://api.github.com/repos/$repo/contents/$path'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/vnd.github+json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'message': 'RegayIslam admin upload: $path',
            'content': contentB64,
            if (sha != null) 'sha': sha,
          }));
      final body = jsonDecode(r.body);
      if (r.statusCode == 200 || r.statusCode == 201) {
        link = '${body['content']?['download_url'] ?? ''}';
      } else {
        error = '${body['message'] ?? r.statusCode}';
      }
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      if (link != null && link.isNotEmpty) _result = link;
    });
    if (link != null && link.isNotEmpty) {
      widget.log('GitHub: $path بارکرا');
      toast('بارکرا بۆ GitHub ✅');
    } else {
      widget.log('GitHub هەڵە: ${error.isEmpty ? 'پەیوەندی نەکرا' : error}');
      toast('هەڵە: ${error.isEmpty ? 'پەیوەندی نەکرا' : error}');
    }
  }

  Future<void> _pickAndUpload() async {
    final picked = await ImagePicker().pickMedia();
    if (picked == null) return;
    final f = File(picked.path);
    if (_path.text.trim().isEmpty) {
      setState(() => _path.text = picked.name);
    }
    await _upload(file: f);
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _result));
    toast('لینک کۆپی کرا ✅');
  }

  @override
  Widget build(BuildContext context) {
    return pageScaffold(
      'بارکردنی فایل بۆ GitHub',
      list([
        section('GitHub'),
        field(_token, 'GitHub Token (بۆ ئەم دانیشتنە تەنها)', obscure: true),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: AppColors.primaryDark,
          title: Text('پاشەکەوتکردنی تۆکن لەم مۆبایلە',
              style: TextStyle(fontSize: 12.5, color: txt)),
          value: _saveToken,
          onChanged: (v) => setState(() => _saveToken = v ?? true),
        ),
        field(_repo, 'owner/repo (نموونە: quranofficial/Videokan)'),
        field(_path, 'ڕێڕەوی فایل لە ریپۆکە (نموونە: 012.mp3)'),
        button('هەڵبژاردنی وێنە/ڤیدیۆ/فایل و بارکردن', _pickAndUpload,
            icon: Icons.upload_file_rounded),
        const SizedBox(height: 8),
        section('بارکردنی وەک دەق'),
        field(_text, 'ناوەڕۆکی دەق (JSON…)', maxLines: 6),
        button('بارکردنی دەقەکە بۆ ریپۆ', () => _upload(textContent: _text.text),
            icon: Icons.upload_rounded),
        if (_result.isNotEmpty) ...[
          const SizedBox(height: 8),
          section('لینکی ڕاستەوخۆ'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.green.withOpacity(.4))),
            child: Row(children: [
              Expanded(
                child: SelectableText(_result,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.green)),
              ),
              IconButton(
                tooltip: 'کۆپیکردنی لینک',
                onPressed: _copy,
                icon: const Icon(Icons.copy_rounded,
                    size: 18, color: AppColors.green),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// ---------------------------------------------------------------------------
/// (6) داتابەیسی Firebase — node editor (load / JSON edit / patch / delete)
/// ---------------------------------------------------------------------------
class _AdminDataPage extends StatefulWidget {
  const _AdminDataPage(this.log);
  final void Function(String) log;
  @override
  State<_AdminDataPage> createState() => _AdminDataPageState();
}

class _AdminDataPageState extends _AdminPageState<_AdminDataPage> {
  static const List<String> _quickNodes = [
    'notification',
    'dialogg',
    'videoall',
    'videoNew',
    'Live',
    'ramadan',
    'ktebakan',
    'quiz',
    'feedback',
    'feedbackvideo',
    'CommentVideo',
  ];

  final _node = TextEditingController();
  final _value = TextEditingController();

  @override
  void dispose() {
    _node.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final path = _node.text.trim();
    if (path.isEmpty) {
      toast('ڕێڕەوی نۆد بنووسە (نموونە: ramadan)');
      return;
    }
    setState(() => busy = true);
    final v = await Rtdb.I.get(path);
    if (!mounted) return;
    setState(() => busy = false);
    if (v == null && Rtdb.I.lastError != null) {
      widget.log('خوێندنەوەی "$path" سەرکەوتوو نەبوو');
      toast('سەرکەوتوو نەبوو — ${Rtdb.I.lastError}');
      return;
    }
    setState(() {
      _value.text = const JsonEncoder.withIndent('  ').convert(v);
    });
    widget.log('نۆدی "$path" خوێندرایەوە');
  }

  Future<void> _save() async {
    final path = _node.text.trim();
    if (path.isEmpty) {
      toast('ڕێڕەوی نۆد بنووسە (نموونە: ramadan)');
      return;
    }
    dynamic value;
    try {
      value = jsonDecode(_value.text);
    } catch (_) {
      value = _value.text.trim();
    }
    setState(() => busy = true);
    final ok = await Rtdb.I
        .patch(path, value is Map<String, dynamic> ? value : {'value': value});
    if (mounted) setState(() => busy = false);
    if (ok) {
      widget.log('نۆدی "$path" پاشەکەوت کرا');
      toast('نۆد پاشەکەوت کرا ✅');
    } else {
      widget.log('پاشەکەوتی "$path" سەرکەوتوو نەبوو');
      failToast();
    }
  }

  Future<void> _deleteNode() async {
    final path = _node.text.trim();
    if (path.isEmpty) {
      toast('ڕێڕەوی نۆد بنووسە');
      return;
    }
    final ok = await confirm(
        'سڕینەوەی نۆد', 'دڵنیایت لە سڕینەوەی نۆدی "$path"؟ ئەم کردارە گەڕانەوەی نییە!');
    if (!ok) return;
    setState(() => busy = true);
    final done = await Rtdb.I.delete(path);
    if (mounted) setState(() => busy = false);
    if (done) {
      widget.log('نۆدی "$path" سڕدرایەوە');
      toast('نۆد سڕدرایەوە ✅');
      if (mounted) setState(() => _value.clear());
    } else {
      widget.log('سڕینەوەی "$path" سەرکەوتوو نەبوو');
      failToast();
    }
  }

  @override
  Widget build(BuildContext context) {
    return pageScaffold(
      'داتابەیسی Firebase',
      list([
        section('نۆدە بەناوبانگەکان'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final n in _quickNodes)
              ActionChip(
                label: Text(n, style: const TextStyle(fontSize: 11)),
                onPressed: () => setState(() => _node.text = n),
              ),
          ],
        ),
        const SizedBox(height: 8),
        section('خوێندنەوە و دەستکاری'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: field(_node, 'ڕێڕەوی نۆد (نموونە: videoNew)')),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IconButton(
                  tooltip: 'خوێندنەوەی نۆد',
                  onPressed: busy ? null : _load,
                  icon: Icon(Icons.refresh_rounded, color: accent)),
            ),
          ],
        ),
        SizedBox(
          height: 200,
          child: TextField(
            controller: _value,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
                hintText: 'ناوەڕۆکی JSON…',
                hintStyle: TextStyle(
                    fontSize: 12, color: txt.withOpacity(.4)),
                filled: true,
                fillColor: dark
                    ? Colors.white.withOpacity(.05)
                    : Colors.black.withOpacity(.03),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10))),
          ),
        ),
        const SizedBox(height: 8),
        button('پاشەکەوتکردنی نۆد (PATCH)', _save, icon: Icons.save_rounded),
        button('سڕینەوەی نۆد (DELETE)', _deleteNode,
            icon: Icons.delete_outline_rounded, color: AppColors.red),
        note('پاشەکەوتکردن داتای نۆد نوێ دەکاتەوە (PATCH) — سڕینەوە تەواو نۆد دەسات!'),
      ]),
    );
  }
}

/// ---------------------------------------------------------------------------
/// (7) سەرنجەکان — comment moderation: tag → video → CommentVideo/<id> list
/// ---------------------------------------------------------------------------
class _AdminCommentsPage extends StatefulWidget {
  const _AdminCommentsPage(this.log);
  final void Function(String) log;
  @override
  State<_AdminCommentsPage> createState() => _AdminCommentsPageState();
}

class _AdminCommentsPageState extends _AdminPageState<_AdminCommentsPage> {
  List<Map<String, dynamic>> _tags = const [];
  List<Map<String, dynamic>> _videos = const [];
  List<Map<String, dynamic>> _comments = const [];
  int? _tagIndex;
  int? _videoIndex;
  String _videoId = '';
  String _videoName = '';
  bool _loadingTags = true;
  bool _loadingVideos = false;
  bool _loadingComments = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final t = await Rtdb.I.videoTags();
    if (!mounted) return;
    setState(() {
      _tags = t;
      _loadingTags = false;
    });
  }

  Future<void> _onTagPicked(int? i) async {
    if (i == null || i >= _tags.length) return;
    final tag = '${_tags[i]['tag'] ?? ''}';
    if (tag.isEmpty) {
      toast('ئەم بەشە تاگی دروست نییە');
      return;
    }
    setState(() {
      _tagIndex = i;
      _videos = const [];
      _videoIndex = null;
      _videoId = '';
      _videoName = '';
      _comments = const [];
      _loadingVideos = true;
    });
    final v = await Rtdb.I.videosOfTag(tag);
    if (!mounted) return;
    setState(() {
      _videos = v;
      _loadingVideos = false;
    });
  }

  Future<void> _onVideoPicked(int? i) async {
    if (i == null || i >= _videos.length) return;
    final v = _videos[i];
    final videoId = '${v['id'] ?? ''}';
    if (videoId.isEmpty) return;
    setState(() {
      _videoIndex = i;
      _videoId = videoId;
      _videoName = '${v['name'] ?? videoId}';
      _comments = const [];
      _loadingComments = true;
    });
    final c = await Rtdb.I.comments(videoId);
    if (!mounted) return;
    setState(() {
      _comments = c;
      _loadingComments = false;
    });
  }

  Future<void> _deleteComment(Map<String, dynamic> c) async {
    if (_videoId.isEmpty) return;
    final ok = await confirm(
        'سڕینەوەی سەرنج', 'دڵنیایت لە سڕینەوەی سەرنجی "${c['userrr'] ?? c['name'] ?? ''}"؟');
    if (!ok) return;
    setState(() => busy = true);
    final done = await Rtdb.I.delete('CommentVideo/$_videoId/${c['id']}');
    if (mounted) setState(() => busy = false);
    if (done) {
      widget.log('سەرنج سڕدرایەوە (video: $_videoId/${c['id']})');
      toast('سەرنج سڕدرایەوە ✅');
      if (mounted) {
        setState(() => _comments.removeWhere((x) => x['id'] == c['id']));
      }
    } else {
      widget.log('سڕینەوەی سەرنج سەرکەوتوو نەبوو (video: $_videoId/${c['id']})');
      failToast();
    }
  }

  String _fmtDate(dynamic d) {
    final ms = int.tryParse('$d');
    if (ms == null) return '$d';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${p(dt.month)}-${p(dt.day)}  ${p(dt.hour)}:${p(dt.minute)}';
  }

  Widget _commentCard(Map<String, dynamic> c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: txt.withOpacity(.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: accent.withOpacity(.15),
            child: Icon(Icons.person_rounded, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text('${c['userrr'] ?? c['name'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: txt)),
                  ),
                  Text(_fmtDate(c['date']),
                      style: TextStyle(fontSize: 10, color: txt.withOpacity(.5))),
                ]),
                const SizedBox(height: 4),
                SelectableText('${c['commenttt'] ?? c['text'] ?? ''}',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: txt.withOpacity(.85),
                        height: 1.5)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'سڕینەوەی سەرنج',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.red, size: 20),
            onPressed: busy ? null : () => _deleteComment(c),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return pageScaffold(
      'سەرنجەکان (پێداچوونەوە)',
      list([
        section('١ — هەڵبژاردنی بەش'),
        if (_loadingTags)
          spinner
        else if (_tags.isEmpty)
          note('هیچ بەشێک لە "videoall" نەدۆزرایەوە')
        else
          DropdownButtonFormField<int>(
            value: _tagIndex,
            hint: const Text('بەشێک هەڵبژێرە',
                style: TextStyle(fontSize: 13)),
            isExpanded: true,
            isDense: true,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: dark
                  ? Colors.white.withOpacity(.05)
                  : Colors.black.withOpacity(.03),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: txt.withOpacity(.15))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accent)),
            ),
            items: [
              for (var i = 0; i < _tags.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text('${_tags[i]['name'] ?? _tags[i]['tag'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                ),
            ],
            onChanged: _onTagPicked,
          ),
        if (_tagIndex != null) ...[
          const SizedBox(height: 10),
          section('٢ — هەڵبژاردنی ڤیدیۆ'),
          if (_loadingVideos)
            spinner
          else if (_videos.isEmpty)
            note('هیچ ڤیدیۆیێک لەم بەشەدا نییە')
          else
            DropdownButtonFormField<int>(
              value: _videoIndex,
              hint: const Text('ڤیدیۆیێک هەڵبژێرە',
                  style: TextStyle(fontSize: 13)),
              isExpanded: true,
              isDense: true,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: dark
                    ? Colors.white.withOpacity(.05)
                    : Colors.black.withOpacity(.03),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: txt.withOpacity(.15))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: accent)),
              ),
              items: [
                for (var i = 0; i < _videos.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text('${_videos[i]['name'] ?? _videos[i]['id'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  ),
              ],
              onChanged: _onVideoPicked,
            ),
        ],
        if (_videoId.isNotEmpty) ...[
          const SizedBox(height: 10),
          section('٣ — سەرنجەکانی "$_videoName"'),
          if (_loadingComments)
            spinner
          else if (_comments.isEmpty)
            note('هیچ سەرنجێک بۆ ئەم ڤیدیۆیە نییە')
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _comments.length,
              itemBuilder: (_, i) => _commentCard(_comments[i]),
            ),
        ],
      ]),
    );
  }
}

/// ---------------------------------------------------------------------------
/// (8) لۆگ — full screen list of everything the admin did
/// ---------------------------------------------------------------------------
class _AdminLogPage extends StatelessWidget {
  const _AdminLogPage({required this.logs, required this.onClear});
  final List<String> logs;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          elevation: 0,
          title: Text(
              'لۆگی کردارەکان${logs.isEmpty ? '' : ' (${logs.length})'}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
          actions: [
            if (logs.isNotEmpty)
              IconButton(
                tooltip: 'سڕینەوەی لۆگ',
                icon: const Icon(Icons.delete_sweep_rounded,
                    color: Colors.white),
                onPressed: () {
                  onClear();
                  Navigator.pop(context);
                },
              ),
          ],
        ),
        body: logs.isEmpty
            ? Center(
                child: Text('هێشتا هیچ کردارێک تۆمار نەکراوە',
                    style: TextStyle(
                        fontSize: 13,
                        color: dark ? Colors.white54 : Colors.black45)))
            : ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                        color: dark ? AppColors.nightCard : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: dark
                            ? null
                            : [
                                BoxShadow(
                                    color: Colors.black.withOpacity(.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1)),
                              ]),
                    child: Text(logs[i],
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color:
                                dark ? Colors.white70 : Colors.black87)),
                  );
                },
              ),
      ),
    );
  }
}
