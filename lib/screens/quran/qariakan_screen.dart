import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/prefs.dart';
import '../../data/db.dart';

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
  int? _selected;
  final AudioPlayer _player = AudioPlayer();
  bool _loading = true;
  bool _playing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
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
    final base = '${r['url'] ?? ''}';
    return base.endsWith('/') ? '$base$suraNum.mp3' : '$base/$suraNum.mp3';
  }

  Future<void> _play(Map<String, dynamic> r) async {
    try {
      final url = _url(r);
      if (_playing && _selected == r['id']) {
        await _player.pause();
      } else {
        final head = await http.head(Uri.parse(url)).timeout(
            const Duration(seconds: 8));
        if (head.statusCode >= 400) throw Exception();
        await _player.play(UrlSource(url));
        setState(() => _selected = r['id'] is int ? r['id'] as int : int.tryParse('${r['id']}'));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('داگرتن ئەنجام نەدرا — دواتر دووبارە هەوڵبدەرەوە')));
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
                          trailing: Icon(
                              _playing && (_selected == (r['id'] is int ? r['id'] : int.tryParse('${r['id']}')))
                                  ? Icons.pause_circle_rounded
                                  : Icons.play_circle_rounded,
                              size: 32, color: AppColors.primaryDark),
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
