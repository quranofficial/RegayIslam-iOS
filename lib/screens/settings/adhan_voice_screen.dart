import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/downloader.dart';
import '../../core/ui.dart' show AudioSetup;

/// Original: KtebActivity — adhan reciter voice selection
/// (هەڵبژاردنی دەنگی بانگبێژ). The voice list comes from the bundled
/// dangebangbezh.json and every voice streams from
/// https://github.com/quranofficial/DangeBangBezh (main branch),
/// exactly like PRDownloader in the Android original.
class AdhanVoiceScreen extends StatefulWidget {
  const AdhanVoiceScreen({super.key});
  @override
  State<AdhanVoiceScreen> createState() => _AdhanVoiceScreenState();
}

class _AdhanVoiceScreenState extends State<AdhanVoiceScreen> {
  List<Map<String, dynamic>> _voices = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _busyFile;
  final AudioPlayer _player = AudioPlayer();
  String? _playingFile;
  PlayerState _state = PlayerState.stopped;

  @override
  void initState() {
    super.initState();
    AudioSetup.prepare(_player); // item 2: steady full volume everywhere
    _load();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingFile = null);
    });
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/dangebangbezh.json');
      final list = jsonDecode(raw) as List;
      setState(() {
        _voices = list.map((e) => Map<String, dynamic>.from(e)).toList();
        _filtered = _voices;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _filter(String q) {
    q = q.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _voices
          : _voices
              .where((m) => '${m['title'] ?? ''}'.toLowerCase().contains(q))
              .toList();
    });
  }

  String _url(String file) => AppPrefs.I.adhanVoiceUrl(file);

  /// Download-first playback (like PRDownloader in the original): cached
  /// files replay offline, and a local source avoids any streaming quirks.
  Future<File?> _localFile(String file) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/bang/$file.mp3');
      return f.existsSync() ? f : null;
    } catch (_) {
      return null;
    }
  }

  bool _allBusy = false;

  /// Item 12: داگرتنی هەموو دەنگەکانی بانگبێژ — every voice lands in the
  /// offline cache so the adhan works with no internet at all.
  Future<void> _downloadAll() async {
    if (_allBusy || _voices.isEmpty) return;
    _allBusy = true;
    final done = ValueNotifier<int>(0);
    final failed = ValueNotifier<int>(0);
    final total = ValueNotifier<int>(_voices.length);
    final ctx = context;
    unawaited(showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('داگرتنی هەموو دەنگەکان'),
          content: AnimatedBuilder(
              animation: Listenable.merge([done, failed, total]),
              builder: (context, _) => Column(mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                        value: total.value > 0
                            ? (done.value + failed.value) / total.value
                            : null),
                    const SizedBox(height: 10),
                    Text(
                        '${done.value + failed.value} لە ${total.value} دەنگ داگیرا'
                        '${failed.value > 0 ? ' • ${failed.value} سەرکەوتوو نەبوو' : ''}',
                        style: const TextStyle(fontSize: 12.5)),
                  ])),
        ),
      ),
    ));
    for (final v in _voices) {
      final file = '${v['text'] ?? ''}'.replaceAll('.mp3', '');
      if (file.isEmpty) continue;
      try {
        final local = await _localFile(file);
        if (local == null) {
          await Downloader.download(_url(file), 'bang/$file.mp3');
        }
        done.value++;
      } catch (_) {
        failed.value++;
      }
    }
    _allBusy = false;
    if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
    if (mounted) setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(done.value > 0
              ? 'تەواو بوو ✅ ${done.value} دەنگ بەردەستە بۆ ئۆفلاین'
              : 'داگرتن سەرکەوتوو نەبوو — ئینتەرنێت بپشکنە'),
          duration: const Duration(seconds: 3)));
    }
  }

  Future<void> _select(Map<String, dynamic> v) async {
    final file = '${v['text'] ?? ''}'.replaceAll('.mp3', '');
    final name = '${v['title'] ?? ''}'.trim();
    if (file.isEmpty || name.isEmpty) return;
    AppPrefs.I.adhanVoiceName = name;
    AppPrefs.I.adhanVoiceFile = file;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('دەنگی بانگبێژ گۆردرا بۆ $name')));
    setState(() {});
    await _play(file);
  }

  Future<void> _play(String file) async {
    if (_playingFile == file && _state == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (_playingFile == file && _state == PlayerState.paused) {
      await _player.resume();
      return;
    }
    setState(() => _busyFile = file);
    try {
      var local = await _localFile(file);
      local ??= await Downloader.download(_url(file), 'bang/$file.mp3');
      await _player.stop();
      await _player.play(DeviceFileSource(local.path));
      setState(() => _playingFile = file);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('کێشە لە داگرتنی دەنگ، تکایە ئینتەرنێت بپشکنە')));
      }
    } finally {
      if (mounted) setState(() => _busyFile = null);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final card = dark ? AppColors.nightCard : Colors.white;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('هەڵبژاردنی دەنگی بانگبێژ',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.bold)),
          actions: [
            // Item 12: batch-download every adhan voice for offline use.
            IconButton(
              tooltip: 'داگرتنی هەموو دەنگەکان بۆ ئۆفلاین',
              onPressed: _allBusy ? null : _downloadAll,
              icon: const Icon(Icons.download_for_offline_rounded,
                  color: Colors.white),
            ),
            // Original: "تاقیکردنەوەی بانگدان" button.
            TextButton.icon(
              onPressed: () => _play(AppPrefs.I.adhanVoiceFile),
              icon: Icon(_playingFile == AppPrefs.I.adhanVoiceFile &&
                      _state == PlayerState.playing
                  ? Icons.stop_rounded
                  : Icons.play_arrow_rounded,
                  color: Colors.white),
              label: const Text('تاقیکردنەوەی بانگدان',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: TextField(
                    onChanged: _filter,
                    decoration: InputDecoration(
                      hintText: 'گەڕان...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: card,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Icon(Icons.record_voice_over_rounded,
                        size: 18, color: AppColors.primaryDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          'دەنگی هەڵبژێردراو : ${AppPrefs.I.adhanVoiceName}',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold,
                              color: txt)),
                    ),
                  ]),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(child: Text('هیچ نەدۆزرایەوە',
                          style: TextStyle(color: txt.withOpacity(.5))))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) {
                            final v = _filtered[i];
                            final file =
                                '${v['text'] ?? ''}'.replaceAll('.mp3', '');
                            final name = '${v['title'] ?? ''}'.trim();
                            final selected =
                                AppPrefs.I.adhanVoiceFile == file;
                            final playingThis =
                                _playingFile == file && _state == PlayerState.playing;
                            final busy = _busyFile == file;
                            return Card(
                              color: selected
                                  ? AppColors.primaryDark.withOpacity(dark ? .25 : .12)
                                  : card,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: selected
                                      ? BorderSide(color: AppColors.primaryDark)
                                      : BorderSide.none),
                              child: ListTile(
                                onTap: () => _select(v),
                                leading: CircleAvatar(
                                    backgroundColor: selected
                                        ? AppColors.primaryDark
                                        : Colors.grey.shade300,
                                    child: Icon(selected
                                        ? Icons.check_rounded
                                        : Icons.music_note_rounded,
                                        color: selected
                                            ? Colors.white
                                            : Colors.black45)),
                                title: Text(name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14, color: txt)),
                                subtitle: selected
                                    ? const Text('هەڵبژێردراو',
                                        style: TextStyle(fontSize: 11))
                                    : FutureBuilder<File?>(
                                        future: _localFile(file),
                                        builder: (context, snap) => Text(
                                            (snap.data != null)
                                                ? 'دابگیراوە — بە ئۆفلاین بەردەستە'
                                                : 'دەنگی بانگی نوێژ',
                                            style:
                                                const TextStyle(fontSize: 11))),
                                trailing: busy
                                    ? const SizedBox(
                                        width: 22, height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : Row(mainAxisSize: MainAxisSize.min,
                                        children: [
                                          FutureBuilder<File?>(
                                            future: _localFile(file),
                                            builder: (context, snap) {
                                              final got = snap.data != null;
                                              return IconButton(
                                                tooltip: got
                                                    ? 'داگیراوە بۆ ئۆفلاین — دووبارە داگرتن'
                                                    : 'داگرتنی دەنگ بۆ بەکارهێنانی بێ ئینتەرنێت',
                                                onPressed: () async {
                                                  await Downloader.download(
                                                      _url(file), 'bang/$file.mp3');
                                                  if (!context.mounted) return;
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: Text(got
                                                              ? 'دووبارە داگیرا ✅'
                                                              : 'داگیرا ✅ — ئێستا بێ ئینتەرنێت کاردەکات')));
                                                  setState(() {});
                                                },
                                                icon: Icon(
                                                    got
                                                        ? Icons.download_done_rounded
                                                        : Icons.download_rounded,
                                                    size: 22,
                                                    color: AppColors.primaryDark));
                                            },
                                          ),
                                          IconButton(
                                              tooltip: playingThis
                                                  ? 'وەستان'
                                                  : 'بیستنی دەنگ',
                                              onPressed: () => _play(file),
                                              icon: Icon(
                                                  playingThis
                                                      ? Icons.pause_circle_rounded
                                                      : Icons.play_circle_rounded,
                                                  size: 30,
                                                  color: AppColors.primaryDark)),
                                        ]),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Text(
                      'تێبینی: ئاگەدارکردنەوەی بانگی نوێژ بە دەنگی هەڵبژێردراو لەناو ئەپەکە دەبیستیت؛ ئاگەدارکردنەوەی سیستەم (لە دەرەوەی ئەپ) دەنگی بنەڕەتی بەکاردەهێنێت.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: txt.withOpacity(.5))),
                ),
              ]),
      ),
    );
  }
}
