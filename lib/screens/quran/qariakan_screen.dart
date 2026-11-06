import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart';
import '../../data/db.dart';
import '../../data/downloader.dart';
import '../../data/favorites.dart';

/// Original: QariakanActivity — reciters list from dangakan.json; selecting a
/// reciter plays surah audio (dangakan "url" base + surah number mp3).
class QariakanScreen extends StatefulWidget {
  const QariakanScreen({super.key});
  @override
  State<QariakanScreen> createState() => _QariakanScreenState();
}

class _QariakanScreenState extends State<QariakanScreen> {
  List<Map<String, dynamic>> _reciters = [];
  List<Map<String, Object?>> _surahs = [];
  Map<String, Object?>? _surah;
  int? _selected = int.tryParse(AppPrefs.I.qariId);
  final AudioPlayer _player = AudioPlayer();
  bool _loading = true;
  bool _playing = false;
  String? _error;
  String? _downloadingId;
  bool _cancelAll = false;
  bool _advancing = false; // guard against double advance

  @override
  void initState() {
    super.initState();
    AudioSetup.prepare(_player); // item 2: steady full volume everywhere
    _load();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    // Item 4: when a surah finishes, the NEXT surah starts automatically
    // with the same reciter (١١٤ سوورەت بەدوای یەک) — no more silence after
    // every surah.
    _player.onPlayerComplete.listen((_) async {
      if (!mounted || _advancing) return;
      if (!AppPrefs.I.autoNextSurah) {
        setState(() => _playing = false);
        return;
      }
      _advancing = true;
      try {
        final cur = (_surah?['soraid'] as num?)?.toInt() ?? 1;
        final next = cur >= 114 ? 1 : cur + 1;
        final s = _surahs.where((e) =>
            (e['soraid'] as num?)?.toInt() == next).toList();
        if (s.isEmpty || _selected == null) return;
        final rec = _reciters.where((r) =>
            (r['id'] is int ? r['id'] : int.tryParse('${r['id']}')) ==
                _selected).toList();
        if (rec.isEmpty) return;
        if (mounted) {
          setState(() => _surah = s.first);
          await _play(rec.first);
        }
      } catch (_) {
      } finally {
        _advancing = false;
      }
    });
  }

  Future<void> _load() async {
    try {
      final raw = await rootAssetString('assets/data/dangakan.json');
      final list = jsonDecode(raw) as List;
      final surahs = await Db.I.surahs();
      setState(() {
        _reciters = list.map((e) => Map<String, dynamic>.from(e)).toList();
        _surahs = surahs;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = 'هەڵە لە خوێندنەوەی لیست'; });
    }
  }

  Future<String> rootAssetString(String path) async {
    return DefaultAssetBundle.of(context).loadString(path);
  }

  String _url(Map<String, dynamic> r) {
    final suraNum = (_surah?['soraid'] ?? 1).toString().padLeft(3, '0');
    final base = '${r['url'] ?? ''}'.replaceFirst(RegExp(r'^http://', caseSensitive: false), 'https://');
    return base.endsWith('/') ? '$base$suraNum.mp3' : '$base/$suraNum.mp3';
  }

  Future<File> _audioFile(Map<String, dynamic> r) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/quran_audio');
    await folder.create(recursive: true);
    final reciter = '${r['id'] ?? r['name_ar'] ?? 'reciter'}'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final surah = (_surah?['soraid'] ?? 1).toString().padLeft(3, '0');
    return File('${folder.path}/${reciter}_${surah}.mp3');
  }

  /// Silent download into the offline cache.
  Future<void> _fetchToFile(Map<String, dynamic> r) async {
    final url = Downloader.httpsify(_url(r));
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) throw const FormatException('Invalid audio URL');
    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      final response = await client.send(request).timeout(const Duration(minutes: 6));
      if (response.statusCode != 200) {
        throw Exception('Audio download failed: HTTP ${response.statusCode}');
      }
      final file = await _audioFile(r);
      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
      }
      await sink.close();
      if (await file.length() == 0) throw Exception('Downloaded audio is empty');
    } finally {
      client.close();
    }
  }

  Future<void> _download(Map<String, dynamic> r) async {
    if (kIsWeb) return; // Browser playback streams audio; native file downloads are mobile-only.
    final id = '${r['id'] ?? r['name_ar'] ?? ''}';
    if (_downloadingId != null) return;
    setState(() => _downloadingId = id);
    try {
      await _fetchToFile(r);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('دەنگەکە بۆ بەکارهێنانی ئۆفلاین داگیرا ✅')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('داگرتنی دەنگ سەرکەوتوو نەبوو')));
      }
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _play(Map<String, dynamic> r) async {
    final rid = r['id'] is int ? r['id'] as int : int.tryParse('${r['id']}');
    final url = _url(r);
    if (_playing && _selected == rid) {
      await _player.pause();
      return;
    }
    try {
      final uri = Uri.tryParse(Downloader.httpsify(url));
      if (uri == null || uri.host.isEmpty) {
        throw const FormatException('Invalid audio URL');
      }
      // Original: QariakanActivity saves the chosen reciter into pref "url"
      // so the whole app (mushaf included) uses it.
      AppPrefs.I.qariId = '${r['id'] ?? ''}';
      AppPrefs.I.qariName = '${r['name_ar'] ?? 'قاری'}'.trim();
      AppPrefs.I.qariUrl = '${r['url'] ?? ''}'
          .replaceFirst(RegExp(r'^http://', caseSensitive: false), 'https://');
      await _player.stop();
      if (kIsWeb) {
        // Browser cannot use path_provider / DeviceFileSource; stream directly.
        await _player.play(UrlSource(Downloader.httpsify(url)));
      } else {
        final local = await _audioFile(r);
        if (await local.exists() && await local.length() > 0) {
          await _player.play(DeviceFileSource(local.path));
        } else {
          try {
            await _player.play(UrlSource(Downloader.httpsify(url)));
          } catch (_) {
            // Native fallback: download then play from the offline cache.
            setState(() => _downloadingId = '${r['id'] ?? ''}');
            await _fetchToFile(r);
            await _player.play(DeviceFileSource(local.path));
          }
        }
      }
      setState(() => _selected = rid);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('داگرتن ئەنجام نەدرا — دواتر دووبارە هەوڵبدەرەوە')));
      }
    } finally {
      if (mounted && _downloadingId == '${r['id'] ?? ''}') {
        setState(() => _downloadingId = null);
      }
    }
  }

  /// Item 18: "داگرتنی هەموو سوورەتەکان" — batch-download all surahs of one
  /// reciter into the offline cache with progress + cancel.
  Future<void> _downloadAll(Map<String, dynamic> r) async {
    if (kIsWeb || _downloadingId != null) return;
    final name = '${r['name_ar'] ?? 'قاری'}'.trim();
    final done = ValueNotifier<int>(0);
    final failed = ValueNotifier<int>(0);
    final total = ValueNotifier<int>(114);
    _cancelAll = false;
    _downloadingId = 'all';
    final ctx = context;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => _DownloadAllDialog(
          name: name, done: done, failed: failed, total: total,
          onCancel: () { _cancelAll = true; Navigator.pop(c); }),
    );
    try {
      final surahs = await Db.I.surahs();
      total.value = surahs.length;
      final old = _surah;
      for (final surah in surahs) {
        if (_cancelAll) break;
        _surah = surah;
        try {
          final file = await _audioFile(r);
          if (!file.existsSync() || file.lengthSync() == 0) {
            await _fetchToFile(r);
          }
          done.value++;
        } catch (_) {
          failed.value++;
        }
        if (mounted) setState(() {});
      }
      _surah = old;
    } catch (_) {}
    _downloadingId = null;
    if (mounted) setState(() {});
    if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_cancelAll
            ? 'داگرتن هەڵوەشێندرا — ${done.value} سوورەت داگیرا'
            : 'تەواو بوو ✅ ${done.value} سوورەت داگیرا'
              '${failed.value > 0 ? '، ${failed.value} سەرکەوتوو نەبوو' : ''}'),
        duration: const Duration(seconds: 3)));
    }
  }

  /// Item 10: avatar image of a reciter bundled under assets/images/qari
  /// (1..81). The files are WebP with a .png name — Flutter decodes by
  /// content, so they load fine; anything missing falls back to the mic
  /// icon instead of an empty grey circle.
  String? _qariAsset(int? id) {
    if (id == null || id < 1 || id > 81) return null;
    return 'assets/images/qari/$id.png';
  }

  /// The round reciter avatar used in the list — ring highlight when this
  /// reciter is playing, dark-mode friendly (no bright grey plate behind
  /// the transparent photos).
  Widget _reciterAvatar(Map<String, dynamic> r, bool dark) {
    final id = int.tryParse('${r['id'] ?? 0}');
    final rid = r['id'] is int ? r['id'] as int : int.tryParse('${r['id']}');
    final selected = _selected != null && _selected == rid;
    final asset = _qariAsset(id);
    return Container(
      width: 50,
      height: 50,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dark ? AppColors.nightCard : Colors.white,
        border: Border.all(
            color: selected
                ? AppColors.gold
                : (dark ? Colors.white24 : Colors.black12),
            width: selected ? 2.4 : 1),
      ),
      child: ClipOval(
        child: asset != null
            ? Image.asset(asset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.mic_rounded,
                    size: 22,
                    color: selected
                        ? AppColors.gold
                        : (dark ? Colors.white54 : Colors.black45)))
            : Icon(Icons.mic_rounded,
                size: 22,
                color: selected
                    ? AppColors.gold
                    : (dark ? Colors.white54 : Colors.black45)),
      ),
    );
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('دەنگی قورئان',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              tooltip: AppPrefs.I.autoNextSurah
                  ? 'بەردەوامی دوای هەر سوورەتێک: کارا — بۆ کژکردن دەستی لێبدا'
                  : 'بەردەوامی دوای هەر سوورەتێک: کژە — بۆ کردنەوەی دەستی لێبدا',
              icon: Icon(
                AppPrefs.I.autoNextSurah
                    ? Icons.playlist_play_rounded
                    : Icons.playlist_remove_rounded,
                color: AppPrefs.I.autoNextSurah
                    ? AppColors.gold
                    : Colors.white54),
              onPressed: () => setState(() =>
                  AppPrefs.I.autoNextSurah = !AppPrefs.I.autoNextSurah),
            ),
            IconButton(
                tooltip: 'هاوبەشی',
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                onPressed: () => sharePage('دەنگی قورئان بە دەنگی قارئەکان',
                    title: 'دەنگی قورئان')),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: txt)))
                : Column(children: [
                Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
                    _surahPicker(dark, txt),
                    const SizedBox(height: 10),
                    for (final r in _reciters)
                      Card(
                        color: dark ? AppColors.nightCard : Colors.white,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          onTap: () => _play(r),
                          leading: _reciterAvatar(r, dark),
                          title: Text('${r['name_ar'] ?? ''}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: txt)),
                          subtitle: r['doxx'] == 'true'
                              ? const Text('داگرتن بەردەستە',
                                  style: TextStyle(fontSize: 11))
                              : const SizedBox(),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            FavoriteButton(id: 'reciter::${r['id']}',
                              title: '${r['name_ar'] ?? 'قاری'}',
                              content: 'دەنگی قورئان — ${r['name_ar'] ?? ''}',
                              route: 'reciter::${r['id']}'),
                            if (!kIsWeb) FutureBuilder<File>(
                              future: _audioFile(r),
                              builder: (context, fileSnap) {
                                final downloaded = fileSnap.hasData && fileSnap.data!.existsSync();
                                final busy = _downloadingId == '${r['id'] ?? r['name_ar']}';
                                return IconButton(
                                  tooltip: downloaded ? 'داگیراوە — دووبارە داگرتن' : 'داگرتنی دەنگ بۆ ئۆفلاین',
                                  onPressed: busy ? null : () => _download(r),
                                  icon: Icon(
                                    busy ? Icons.downloading_rounded
                                      : downloaded ? Icons.download_done_rounded : Icons.download_rounded,
                                    color: AppColors.primaryDark));
                              },
                            ),
                            if (!kIsWeb) IconButton(
                              tooltip: 'داگرتنی هەموو سوورەتەکانی ئەم قارییە',
                              onPressed: _downloadingId != null
                                  ? null
                                  : () => _downloadAll(r),
                              icon: Icon(_downloadingId == 'all'
                                  ? Icons.downloading_rounded
                                  : Icons.download_for_offline_rounded,
                                  size: 22, color: AppColors.primaryDark)),
                            Icon(_playing && (_selected == (r['id'] is int ? r['id'] : int.tryParse('${r['id']}')))
                                ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                              size: 32, color: AppColors.primaryDark),
                          ]),
                        ),
                      ),
                ]),
                ),
                if (_selected != null)
                  Builder(builder: (context) {
                    final rec = _reciters
                        .where((r) => '${r['id']}' == '$_selected')
                        .toList();
                    final name = rec.isNotEmpty
                        ? '${rec.first['name_ar'] ?? ''}'.trim()
                        : '';
                    return AudioPlayerBar(
                      player: _player,
                      dark: dark,
                      title: 'دەنگی سوورەت — $name'
                          '${_surah == null ? '' : ' • ${_surah!['name'] ?? ''}'}',
                      onPlayPause: () {
                        if (rec.isNotEmpty) _play(rec.first);
                      },
                      playing: _playing,
                    );
                  }),
                ]),
      ),
    );
  }

  Widget _surahPicker(bool dark, Color txt) => FutureBuilder<List<Map<String, Object?>>>(
        future: Db.I.surahs(),
        builder: (context, snap) {
          final list = snap.data ?? [];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: dark ? AppColors.nightCard : Colors.white,
                borderRadius: BorderRadius.circular(14)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, Object?>>(
                value: _surah,
                hint: Text('سوورەت هەڵبژێرە', style: TextStyle(color: txt)),
                isExpanded: true,
                items: [
                  for (final s in list)
                    DropdownMenuItem(
                        value: s,
                        child: Text('${s['soraid']}. ${s['name']}',
                            style: TextStyle(fontSize: 13, color: txt))),
                ],
                onChanged: (v) => setState(() => _surah = v),
              ),
            ),
          );
        });
}

/// Progress dialog for the batch surah download.
class _DownloadAllDialog extends StatefulWidget {
  const _DownloadAllDialog({
    required this.name,
    required this.done,
    required this.failed,
    required this.total,
    required this.onCancel,
  });
  final String name;
  final ValueNotifier<int> done;
  final ValueNotifier<int> failed;
  final ValueNotifier<int> total;
  final VoidCallback onCancel;

  @override
  State<_DownloadAllDialog> createState() => _DownloadAllDialogState();
}

class _DownloadAllDialogState extends State<_DownloadAllDialog> {
  @override
  void initState() {
    super.initState();
    for (final n in [widget.done, widget.failed, widget.total]) {
      n.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final n in [widget.done, widget.failed, widget.total]) {
      n.removeListener(_changed);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('داگرتنی هەموو سوورەتەکان'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          LinearProgressIndicator(
              value: widget.total.value > 0
                  ? widget.done.value / widget.total.value
                  : null),
          const SizedBox(height: 10),
          Text(
              '${widget.done.value} لە ${widget.total.value} سوورەت داگیرا'
              '${widget.failed.value > 0 ? ' • ${widget.failed.value} سەرکەوتوو نەبوو' : ''}',
              style: const TextStyle(fontSize: 12.5)),
        ]),
        actions: [
          TextButton(onPressed: widget.onCancel,
              child: const Text('هەڵوەشاندنەوە')),
        ],
      ),
    );
  }
}
