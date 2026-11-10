import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart' show AudioSetup, bottomInset;
import '../../data/favorites.dart';
import 'ruqya_screen.dart';

/// Original: RuqyayActivity + RockActivity — the ruqyah audio list read
/// from taybat.json (17 mp3 items with title/link/namefile) with a player
/// (stream, offline download, seek bar) and favorites.
class RuqyaAudioScreen extends StatefulWidget {
  const RuqyaAudioScreen({super.key});
  @override
  State<RuqyaAudioScreen> createState() => _RuqyaAudioScreenState();
}

class _RuqyaAudioScreenState extends State<RuqyaAudioScreen> {
  final AudioPlayer _player = AudioPlayer();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  int? _selected;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  String? _downloadingId;

  @override
  void initState() {
    super.initState();
    AudioSetup.prepare(_player); // item 2: steady full volume everywhere
    _load();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playing = false; _pos = _dur; });
    });
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/taybat.json');
      final list = jsonDecode(raw) as List;
      setState(() {
        _items = list.map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _url(Map<String, dynamic> r) =>
      '${r['link'] ?? ''}'.replaceFirst(
          RegExp(r'^http://', caseSensitive: false), 'https://');

  Future<File> _audioFile(Map<String, dynamic> r) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/ruqya_audio');
    await folder.create(recursive: true);
    final name = '${r['namefile'] ?? 'ruqya.mp3'}'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    return File('${folder.path}/$name');
  }

  Future<void> _download(Map<String, dynamic> r) async {
    final id = '${r['namefile'] ?? r['title']}';
    if (_downloadingId != null) return;
    setState(() => _downloadingId = id);
    try {
      final url = _url(r);
      final uri = Uri.tryParse(url);
      if (uri == null || uri.host.isEmpty) {
        throw const FormatException('Invalid audio URL');
      }
      final client = http.Client();
      try {
        final response =
            await client.send(http.Request('GET', uri))
                .timeout(const Duration(minutes: 4));
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('دەنگەکە بۆ بەکارهێنانی ئۆفلاین داگیرا ✅')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('داگرتنی دەنگ سەرکەوتوو نەبوو')));
      }
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _play(int i) async {
    try {
      if (_selected == i && _playing) {
        await _player.pause();
        return;
      }
      if (_selected == i && !_playing && _pos > Duration.zero) {
        await _player.resume();
        return;
      }
      await _player.stop();
      final r = _items[i];
      final local = await _audioFile(r);
      if (await local.exists() && await local.length() > 0) {
        await _player.play(DeviceFileSource(local.path));
      } else {
        final url = _url(r);
        final uri = Uri.tryParse(url);
        if (uri == null || uri.host.isEmpty) {
          throw const FormatException('Invalid audio URL');
        }
        await _player.play(UrlSource(url));
      }
      setState(() => _selected = i);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('دەنگەکە ئەنجام نەدرا — دواتر دووبارە هەوڵبدەرەوە')));
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
          title: const Text('ڕوقیەی شەرعی',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
                tooltip: 'ئایەتەکانی ڕوقیە',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RuqyaScreen())),
                icon: const Icon(Icons.auto_stories_rounded, color: Colors.white)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Stack(children: [
                ListView(padding: const EdgeInsets.all(12), children: [
                  Card(
                    color: dark ? AppColors.nightCard : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'ڕوقیە بە دەنگی دەنگبێژەکان — بۆ چارەسەری چاو، سیحر، شێواوی و نەخۆشی بە ئیزنی خوا. کلیک لە دەنگەکە بکە بۆ بیستن.',
                        style: TextStyle(height: 1.7, color: txt)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _items.length; i++)
                    Card(
                      color: _selected == i
                          ? AppColors.primaryDark.withOpacity(dark ? .25 : .08)
                          : (dark ? AppColors.nightCard : Colors.white),
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        onTap: () => _play(i),
                        leading: CircleAvatar(
                            backgroundColor: _selected == i
                                ? AppColors.primaryDark
                                : Colors.grey.shade300,
                            child: Icon(Icons.healing_rounded,
                                color: _selected == i
                                    ? Colors.white
                                    : Colors.black45)),
                        title: Text('${_items[i]['title'] ?? ''}',
                            style: TextStyle(fontWeight: FontWeight.bold,
                                fontSize: 13.5, color: txt)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          FavoriteButton(
                              id: 'ruqyaaudio::${_items[i]['namefile'] ?? i}',
                              title: '${_items[i]['title'] ?? 'ڕوقیە'}',
                              content: 'ڕوقیەی شەرعی — دەنگی ${_items[i]['namefile'] ?? ''}'),
                          FutureBuilder<File>(
                            future: _audioFile(_items[i]),
                            builder: (context, fileSnap) {
                              final downloaded =
                                  fileSnap.hasData && fileSnap.data!.existsSync();
                              final busy = _downloadingId ==
                                  '${_items[i]['namefile'] ?? _items[i]['title']}';
                              return IconButton(
                                tooltip: downloaded
                                    ? 'داگیراوە — دووبارە داگرتن'
                                    : 'داگرتنی دەنگ بۆ ئۆفلاین',
                                onPressed: busy ? null : () => _download(_items[i]),
                                icon: Icon(
                                  busy ? Icons.downloading_rounded
                                    : downloaded
                                      ? Icons.download_done_rounded
                                      : Icons.download_rounded,
                                  color: AppColors.primaryDark));
                            },
                          ),
                          Icon(_selected == i && _playing
                              ? Icons.pause_circle_rounded
                              : Icons.play_circle_rounded,
                              size: 32, color: AppColors.primaryDark),
                        ]),
                      ),
                    ),
                ]),
                if (_selected != null) _playerBar(dark, txt),
              ]),
      ),
    );
  }

  /// Item 11: the floating bar used to sit flush with the screen bottom —
  /// behind the system navigation bar, so the seekbar and the play button
  /// were barely visible/pressable. It now rides above the nav bar
  /// (SafeArea + viewPadding) and gained ±10 seconds buttons.
  Widget _playerBar(bool dark, Color txt) => Positioned(
        left: 12, right: 12,
        bottom: bottomInset(context, extra: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: BoxDecoration(
              color: dark ? AppColors.nightCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10),
              ]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${_items[_selected!]['title'] ?? ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                    color: txt)),
            Row(children: [
              IconButton(
                  tooltip: '١٠ چرکە بەرەو دواوە',
                  onPressed: () async {
                    final t = _pos - const Duration(seconds: 10);
                    await _player.seek(t < Duration.zero
                        ? Duration.zero : t);
                  },
                  icon: const Icon(Icons.replay_10_rounded,
                      size: 24, color: AppColors.primaryDark)),
              IconButton(
                  onPressed: () => _play(_selected!),
                  icon: Icon(_playing
                      ? Icons.pause_circle_rounded
                      : Icons.play_circle_rounded,
                      size: 34, color: AppColors.primaryDark)),
              IconButton(
                  tooltip: '١٠ چرکە بەرەو پێشەوە',
                  onPressed: () async {
                    final t = _pos + const Duration(seconds: 10);
                    final max = _dur > Duration.zero ? _dur : t;
                    await _player.seek(t > max ? max : t);
                  },
                  icon: const Icon(Icons.forward_10_rounded,
                      size: 24, color: AppColors.primaryDark)),
              Expanded(
                child: Slider(
                    value: _dur > Duration.zero &&
                            _pos <= _dur
                        ? _pos.inMilliseconds.toDouble()
                        : 0,
                    max: _dur > Duration.zero
                        ? _dur.inMilliseconds.toDouble()
                        : 1,
                    activeColor: AppColors.primaryDark,
                    onChanged: (v) async {
                      await _player
                          .seek(Duration(milliseconds: v.round()));
                    }),
              ),
              Text(_fmt(_pos),
                  style: TextStyle(fontSize: 11, color: txt.withOpacity(.6))),
            ]),
          ]),
        ),
      );

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }
}
