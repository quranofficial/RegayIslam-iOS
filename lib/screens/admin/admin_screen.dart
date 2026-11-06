import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/rtdb.dart';

/// Item 22 + feedback 15: the in-app admin panel, rebuilt to be complete
/// and stable — system notification, start dialog, video sections (add,
/// list, delete), books (add via Firebase + optional GitHub PDF upload),
/// file upload to GitHub with a saved token, and a quick Firebase editor.
///
/// Opened from ڕێکخستن → پانێلی بەڕێوەبەر (password: kAdminPassword).
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _nodeC = TextEditingController();
  final _valueC = TextEditingController();

  // notification / dialog fields
  final _notifTitle = TextEditingController();
  final _notifText = TextEditingController();
  final _dlgTitle = TextEditingController();
  final _dlgText = TextEditingController();
  final _dlgUrl = TextEditingController();

  // video fields
  final _videoName = TextEditingController();
  final _videoUrl = TextEditingController();
  final _videoTag = TextEditingController();

  // book fields
  final _bookName = TextEditingController();
  final _bookAdmin = TextEditingController();
  final _bookAbout = TextEditingController();
  final _bookUrl = TextEditingController();
  final _bookImage = TextEditingController();

  // github upload
  final _ghToken = TextEditingController();
  final _ghRepo = TextEditingController(text: 'quranofficial/Videokan');
  final _ghPath = TextEditingController();
  bool _saveToken = true;
  String _ghResult = '';
  bool _busy = false;
  String _log = '';

  @override
  void initState() {
    super.initState();
    _ghToken.text = AppPrefs.I.adminGhToken;
  }

  @override
  void dispose() {
    for (final c in [
      _nodeC, _valueC, _notifTitle, _notifText, _dlgTitle, _dlgText,
      _dlgUrl, _videoName, _videoUrl, _videoTag, _ghToken, _ghRepo, _ghPath,
      _bookName, _bookAdmin, _bookAbout, _bookUrl, _bookImage,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  void _appendLog(String m) {
    setState(() => _log = m.isEmpty
        ? ''
        : '${DateTime.now().toIso8601String().substring(11, 19)} — $m\n$_log');
  }

  // ---- actions -----------------------------------------------------------
  Future<void> _sendNotification() async {
    if (_notifTitle.text.trim().isEmpty && _notifText.text.trim().isEmpty) {
      _toast('ناونیشان یان دەق بنووسە');
      return;
    }
    setState(() => _busy = true);
    await Rtdb.I.patch('notification', {
      'title': _notifTitle.text.trim(),
      'text': _notifText.text.trim(),
      'date': DateTime.now().millisecondsSinceEpoch.toString(),
      'open': 'true',
    });
    setState(() => _busy = false);
    _appendLog('notification نێردرا');
    _toast('ئاگادارکردنەوە نێردرا ✅');
  }

  Future<void> _sendDialog() async {
    setState(() => _busy = true);
    await Rtdb.I.patch('dialogg', {
      'dialog': {
        'open': 'true',
        'title': _dlgTitle.text.trim(),
        'text': _dlgText.text.trim(),
        'url': _dlgUrl.text.trim(),
        'close': 'داخستن',
        'ver': 'v-${DateTime.now().millisecondsSinceEpoch}',
      }
    });
    setState(() => _busy = false);
    _appendLog('dialogg نوێکرایەوە');
    _toast('دیالۆگەکە پاشەکەوت کرا ✅');
  }

  Future<void> _addVideo() async {
    final tag = _videoTag.text.trim();
    final name = _videoName.text.trim();
    final url = _videoUrl.text.trim();
    if (tag.isEmpty || name.isEmpty || url.isEmpty) {
      _toast('تاگ، ناو و لینک پڕ بکەرەوە');
      return;
    }
    setState(() => _busy = true);
    await Rtdb.I.push('videoNew/$tag', {
      'name': name,
      'url': url,
      'like': '0',
      'comment': '0',
      'view': '0',
      'date': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    setState(() => _busy = false);
    _appendLog('videoNew/$tag + ڤیدیۆ');
    _toast('ڤیدیۆ زیادکرا ✅');
  }

  Future<void> _addTag() async {
    final tag = _videoTag.text.trim();
    final name = _videoName.text.trim();
    if (tag.isEmpty || name.isEmpty) {
      _toast('تاگ و ناو پڕ بکەرەوە');
      return;
    }
    await Rtdb.I.push('videoall', {'name': name, 'tag': tag, 'image': ''});
    _appendLog('videoall + تاگ $tag');
    _toast('تاگ زیادکرا ✅');
  }

  /// Item 15: manage a tag — list its videos with one-tap delete.
  Future<void> _manageTag() async {
    final tag = _videoTag.text.trim();
    if (tag.isEmpty) {
      _toast('ناوی تاگ/فۆڵدەر بنووسە');
      return;
    }
    setState(() => _busy = true);
    final videos = await Rtdb.I.videosOfTag(tag);
    setState(() => _busy = false);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPrefs.I.day ? Colors.white : AppColors.nightCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .7,
          builder: (c, scroll) => Column(children: [
            const SizedBox(height: 10),
            Text('ڤیدیۆکانی "$tag" (${videos.length})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Expanded(
              child: videos.isEmpty
                  ? const Center(child: Text('هیچ ڤیدیۆیێک لەم تاگەدا نییە'))
                  : ListView.builder(
                      controller: scroll,
                      itemCount: videos.length,
                      itemBuilder: (c, i) {
                        final v = videos[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.ondemand_video_rounded,
                              color: AppColors.primaryDark),
                          title: Text('${v['name'] ?? v['key'] ?? ''}',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('id: ${v['id']}',
                              style: const TextStyle(fontSize: 10)),
                          trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.red),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: c,
                                  builder: (d) => Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: AlertDialog(
                                      title: const Text('سڕینەوە'),
                                      content: Text(
                                          'دڵنیایت لە سڕینەوەی "${v['name'] ?? ''}"؟'),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(d, false),
                                            child: const Text('نەخێر')),
                                        ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white),
                                            onPressed: () => Navigator.pop(d, true),
                                            child: const Text('سڕینەوە')),
                                      ],
                                    ),
                                  ),
                                );
                                if (ok == true) {
                                  final del = await Rtdb.I.delete(
                                      'videoNew/$tag/${v['id']}');
                                  _appendLog(del
                                      ? 'videoNew/$tag/${v['id']} سڕدرایەوە'
                                      : 'سڕینەوە سەرکەوتوو نەبوو');
                                  Navigator.pop(c);
                                }
                              }),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Item 15: add a book — stored in the "ktebakan" Firebase node; the
  /// library screen merges it with the GitHub list automatically.
  Future<void> _addBook() async {
    final name = _bookName.text.trim();
    final url = _bookUrl.text.trim();
    if (name.isEmpty || url.isEmpty) {
      _toast('ناو و لینکی PDF پڕ بکەرەوە');
      return;
    }
    setState(() => _busy = true);
    await Rtdb.I.push('ktebakan', {
      'name': name,
      'url': url,
      'admin': _bookAdmin.text.trim(),
      'about': _bookAbout.text.trim(),
      'image': _bookImage.text.trim(),
      'date': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    setState(() => _busy = false);
    _appendLog('ktebakan + $name');
    _toast('کتێب زیادکرا ✅');
  }

  /// Upload an image / file / video from the phone straight into the
  /// GitHub repo (PUT /contents) and get back the raw link for the app.
  Future<void> _uploadToGithub({File? file, String? textContent}) async {
    final token = _ghToken.text.trim();
    final repo = _ghRepo.text.trim();
    var path = _ghPath.text.trim().replaceAll(RegExp(r'^/+'), '');
    if (token.isEmpty || repo.isEmpty || path.isEmpty) {
      _toast('تۆکن، ریپۆ و ڕێڕەو پڕ بکەرەوە');
      return;
    }
    if (_saveToken) AppPrefs.I.adminGhToken = token;
    String contentB64;
    if (file != null) {
      contentB64 = base64Encode(await file.readAsBytes());
    } else {
      contentB64 = base64Encode(utf8.encode(textContent ?? ''));
    }
    setState(() => _busy = true);
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
        final dl = '${body['content']?['download_url'] ?? ''}';
        setState(() => _ghResult = dl);
        _appendLog('GitHub: $path بارکرا');
        _toast('بارکرا بۆ GitHub ✅');
      } else {
        _appendLog('GitHub هەڵە ${r.statusCode}: ${body['message'] ?? ''}');
        _toast('هەڵە: ${body['message'] ?? r.statusCode}');
      }
    } catch (e) {
      _appendLog('GitHub هەڵە: $e');
      _toast('پەیوەندی نەکرا');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndUpload() async {
    final picked = await ImagePicker().pickMedia();
    if (picked == null) return;
    final f = File(picked.path);
    if (_ghPath.text.trim().isEmpty) {
      _ghPath.text = picked.name;
    }
    await _uploadToGithub(file: f);
  }

  Future<void> _saveNode() async {
    final path = _nodeC.text.trim();
    if (path.isEmpty) {
      _toast('ڕێڕەوی نۆد بنووسە (نموونە: ramadan)');
      return;
    }
    dynamic value;
    try {
      value = jsonDecode(_valueC.text);
    } catch (_) {
      value = _valueC.text.trim();
    }
    await Rtdb.I.patch(path,
        value is Map<String, dynamic> ? value : {'value': value});
    _appendLog('$path پاشەکەوت کرا');
    _toast('نۆد پاشەکەوت کرا ✅');
  }

  Future<void> _loadNode() async {
    final path = _nodeC.text.trim();
    if (path.isEmpty) return;
    setState(() => _busy = true);
    final v = await Rtdb.I.get(path);
    setState(() {
      _busy = false;
      _valueC.text = const JsonEncoder.withIndent('  ').convert(v);
    });
    _appendLog('$path خوێندرایەوە');
  }

  // ---- UI ----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final card = dark ? AppColors.nightCard : Colors.white;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 6,
        child: Scaffold(
          backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
          appBar: AppBar(
            backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
            title: const Text('پانێلی بەڕێوەبەر',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            bottom: const TabBar(
                isScrollable: true,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(icon: Icon(Icons.notifications_active_rounded, size: 17), text: 'ئاگادار'),
                  Tab(icon: Icon(Icons.campaign_rounded, size: 17), text: 'دیالۆگ'),
                  Tab(icon: Icon(Icons.ondemand_video_rounded, size: 17), text: 'ڤیدیۆ'),
                  Tab(icon: Icon(Icons.local_library_rounded, size: 17), text: 'کتێب'),
                  Tab(icon: Icon(Icons.upload_rounded, size: 17), text: 'GitHub'),
                  Tab(icon: Icon(Icons.storage_rounded, size: 17), text: 'داتابەیس'),
                ]),
          ),
          body: Column(children: [
            Expanded(
              child: TabBarView(children: [
                _notifTab(card, txt),
                _dialogTab(card, txt),
                _videoTab(card, txt),
                _bookTab(card, txt),
                _githubTab(card, txt),
                _dataTab(card, txt),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint,
          {int maxLines = 1, bool obscure = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            filled: true,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );

  Widget _btn(String label, VoidCallback onTap, {IconData? icon, Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: color ?? AppColors.primaryDark,
                foregroundColor: Colors.white),
            onPressed: _busy ? null : onTap,
            icon: Icon(icon ?? Icons.send_rounded, size: 18),
            label: Text(label),
          ),
        ),
      );

  Widget _notifTab(Color card, Color txt) => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _field(_notifTitle, 'ناونیشانی ئاگادارکردنەوە'),
          _field(_notifText, 'دەقی ئاگادارکردنەوە', maxLines: 4),
          _btn('ناردنی ئاگادارکردنەوە بۆ هەموو بەکارهێنەران', _sendNotification,
              icon: Icons.notifications_active_rounded),
          const SizedBox(height: 8),
          Text(
              'تێبینی: لە کاتی کردنەوەی ئەپەکە بەکارهێنەران ئاگادارکردنەوەکە وەک نامەی سیستەم وەردەگرن.',
              style: TextStyle(fontSize: 11.5, color: txt.withOpacity(.55))),
        ],
      );

  Widget _dialogTab(Color card, Color txt) => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _field(_dlgTitle, 'ناونیشانی دیالۆگ'),
          _field(_dlgText, 'دەقی دیالۆگ', maxLines: 6),
          _field(_dlgUrl, 'لینک (ئارەزوومەندانە)'),
          _btn('پاشەکەوتی دیالۆگی دەستپێک', _sendDialog,
              icon: Icons.campaign_rounded),
        ],
      );

  Widget _videoTab(Color card, Color txt) => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _field(_videoTag, 'تاگ/فۆڵدەری ڤیدیۆ (نموونە: quran)'),
          _field(_videoName, 'ناوی ڤیدیۆ یان تاگ'),
          _field(_videoUrl, 'لینکی ڤیدیۆ (mp4)', maxLines: 2),
          _btn('زیادکردنی ڤیدیۆ بۆ بەشەکە', _addVideo,
              icon: Icons.ondemand_video_rounded),
          _btn('زیادکردنی تاگ/بەشی نوێ', _addTag,
              icon: Icons.new_label_rounded),
          _btn('بەڕێوەبردن و سڕینەوەی ڤیدیۆکانی تاگ', _manageTag,
              icon: Icons.manage_search_rounded, color: const Color(0xFF455A64)),
        ],
      );

  Widget _bookTab(Color card, Color txt) => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _field(_bookName, 'ناوی کتێب'),
          _field(_bookAdmin, 'نوسەر'),
          _field(_bookAbout, 'کورتە', maxLines: 3),
          _field(_bookUrl, 'لینکی PDF (دەتوانیت لە تابی GitHub باربکەیت و لینکەکە لێرە دابنێیت)', maxLines: 2),
          _field(_bookImage, 'لینکی وێنەی چاپەمەری (ئارەزوومەندانە)'),
          _btn('زیادکردنی کتێب بۆ کتێبخانە', _addBook,
              icon: Icons.local_library_rounded),
          Text(
              'کتێبەکان دەچنە ناو نۆدی "ktebakan"ی Firebase و بە خۆکاری لە کتێبخانەی ئەپ دەردەکەون.',
              style: TextStyle(fontSize: 11.5, color: txt.withOpacity(.55))),
        ],
      );

  Widget _githubTab(Color card, Color txt) => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _field(_ghToken, 'GitHub Token (بۆ ئەم دانیشتنە تەنها)',
              obscure: true),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('پاشەکەوتکردنی تۆکن لەم مۆبایلە',
                style: TextStyle(fontSize: 12.5, color: txt)),
            value: _saveToken,
            onChanged: (v) => setState(() => _saveToken = v ?? true),
          ),
          _field(_ghRepo, 'owner/repo (نموونە: quranofficial/Videokan)'),
          _field(_ghPath, 'ڕێڕەوی فایل لە ریپۆکە (نموونە: 012.mp3)'),
          _btn('هەڵبژاردنی وێنە/ڤیدیۆ/فایل و بارکردن', _pickAndUpload,
              icon: Icons.upload_file_rounded),
          _btn('بارکردنی وەک دەق (JSON…)',
              () => _uploadToGithub(textContent: _valueC.text),
              icon: Icons.upload_rounded),
          if (_ghResult.isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText('لینکی ڕاستەوخۆ:\n$_ghResult',
                style: TextStyle(fontSize: 12, color: AppColors.green)),
          ],
        ],
      );

  /// Generic Firebase node editor with quick-pick chips.
  Widget _dataTab(Color card, Color txt) => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final n in ['notification', 'dialogg', 'videoall', 'videoNew',
              'Live', 'ramadan', 'ktebakan', 'quiz', 'feedback',
              'feedbackvideo', 'CommentVideo'])
              ActionChip(
                label: Text(n, style: const TextStyle(fontSize: 11)),
                onPressed: () => setState(() => _nodeC.text = n),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _field(_nodeC, 'ڕێڕەوی نۆد (نموونە: videoNew)')),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IconButton(
                  tooltip: 'خوێندنەوە',
                  onPressed: _busy ? null : _loadNode,
                  icon: const Icon(Icons.refresh_rounded,
                      color: AppColors.primaryDark)),
            ),
          ]),
          SizedBox(
            height: 180,
            child: TextField(
              controller: _valueC,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                  fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                  hintText: 'ناوەڕۆکی JSON…',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _saveNode,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('پاشەکەوتکردنی نۆد'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
                tooltip: 'سڕینەوەی لۆگ',
                onPressed: () => _appendLog(''),
                icon: Icon(Icons.clear_all_rounded,
                    color: txt.withOpacity(.5))),
          ]),
          if (_log.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxHeight: 90),
              child: SingleChildScrollView(
                  child: Text(_log,
                      style: TextStyle(
                          fontSize: 11, color: txt.withOpacity(.6)))),
            ),
        ],
      );
}
