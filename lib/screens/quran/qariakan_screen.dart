import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/prefs.dart';
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
  Map<String, Object?>? _surah;
  int? _selected = int.tryParse(AppPrefs.I.qariId);
  final AudioPlayer _player = AudioPlayer();
  bool _loading = true;
  bool _playing = false;
  String? _error;
  String? _downloadingId;

  @override
  void initState() {
    super.initState();
    _load();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  Future<void> _load() async {
    try {
      final raw = await rootAssetString('assets/data/dangakan.json');
      final list = jsonDecode(raw) as List;
      setState(() {
        _reciters = list.map((e) => Map<String, dynamic>.from(e)).toList();
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
      final local = await _audioFile(r);
      if (await local.exists() && await local.length() > 0) {
        await _player.play(DeviceFileSource(local.path));
      } else {
        try {
          await _player.play(UrlSource(Downloader.httpsify(url)));
        } catch (_) {
          // streaming refused — download then play, like PRDownloader
          setState(() => _downloadingId = '${r['id'] ?? ''}');
          await _fetchToFile(r);
          await _player.play(DeviceFileSource(local.path));
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
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: txt)))
                : ListView(padding: const EdgeInsets.all(12), children: [
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
                          leading: CircleAvatar(
                              backgroundColor: (_selected == (r['id'] is int ? r['id'] : int.tryParse('${r['id']}')))
                                  ? AppColors.primaryDark
                                  : Colors.grey.shade300,
                              child: Icon(Icons.mic_rounded,
                                  color: (_selected == (r['id'] is int ? r['id'] : int.tryParse('${r['id']}')))
                                      ? Colors.white : Colors.black45)),
                          title: Text('${r['name_ar'] ?? ''}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: txt)),
                          subtitle: r['doxx'] == 'true'
                              ? const Text('داگرتن بەردەستە',
                                  style: TextStyle(fontSize: 11))
                              : const SizedBox(),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            FavoriteButton(id: 'reciter::${r['id']}',
                              title: '${r['name_ar'] ?? 'قاری'}',
                              content: 'دەنگی قورئان — ${r['name_ar'] ?? ''}'),
                            FutureBuilder<File>(
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
                            Icon(_playing && (_selected == (r['id'] is int ? r['id'] : int.tryParse('${r['id']}')))
                                ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                              size: 32, color: AppColors.primaryDark),
                          ]),
                        ),
                      ),
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
