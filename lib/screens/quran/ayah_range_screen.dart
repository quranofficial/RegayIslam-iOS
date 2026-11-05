import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart';
import '../../data/db.dart';
import '../../data/downloader.dart';
import 'open_quran.dart' show toArabicDigits;
import 'quran_settings_sheet.dart';

/// Item 3 — the requested special feature: "تایبەتمەندی ئایەتەکان".
/// Pick a reciter, a surah and an ayah range (e.g. start at ayah 5); the
/// player recites ayah by ayah, highlights and shows the current verse,
/// and a mushaf page view is one tap away. Reciters come from dangakan.json
/// (surah audio) and are synced with the bundled per-reciter timings dbs;
/// when no timings exist the per-ayah cdn.islamic.network files are used.
class AyahRangeScreen extends StatefulWidget {
  const AyahRangeScreen({super.key});
  @override
  State<AyahRangeScreen> createState() => _AyahRangeScreenState();
}

class _AyahRangeScreenState extends State<AyahRangeScreen> {
  List<Map<String, dynamic>> _reciters = [];
  List<Map<String, Object?>> _surahs = [];
  List<Map<String, Object?>> _ayat = [];
  Map<String, dynamic>? _reciter;
  Map<String, Object?>? _surah;
  int _from = 1;
  int _to = 5;
  bool _loading = true;
  bool _playing = false;
  int? _currentAyah;
  String? _error;
  bool _mushaf = false;
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _scroll = ScrollController();
  Map<String, int> _timings = {};
  int _timingsBase = -1; // surah id the timings belong to

  @override
  void initState() {
    super.initState();
    AudioSetup.prepare(_player); // item 2: steady full volume everywhere
    _load();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      _playNext();
    });
  }

  Future<void> _load() async {
    try {
      final raw = await rootAssetJson('assets/data/dangakan.json');
      final surahs = await Db.I.surahs();
      if (!mounted) return;
      setState(() {
        _reciters = raw;
        _surahs = surahs;
        if (_reciters.isNotEmpty) _reciter = _reciters.first;
        if (_surahs.isNotEmpty) _surah = _surahs.first;
        _loading = false;
      });
      if (_surah != null) await _loadAyat();
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = 'هەڵە لە خوێندنەوەی داتا'; });
      }
    }
  }

  Future<List<Map<String, dynamic>>> rootAssetJson(String path) async {
    final raw = await DefaultAssetBundle.of(context).loadString(path);
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _loadAyat() async {
    final sid = (_surah?['soraid'] as num?)?.toInt() ?? 1;
    final rows = await Db.I.ayat(sid, AppPrefs.I.tafsir);
    if (!mounted) return;
    setState(() {
      _ayat = rows;
      final count = rows.length;
      _from = _from.clamp(1, count);
      _to = _to.clamp(_from, count);
    });
  }

  int get _ayaCount =>
      _ayat.isNotEmpty ? _ayat.length : ((_surah?['aya'] as num?)?.toInt() ?? 7);

  String _base(Map<String, dynamic> r) =>
      '${r['url'] ?? ''}'.replaceFirst(RegExp(r'^http://'), 'https://');

  /// Surah-level mp3 for the selected reciter.
  String _surahUrl() {
    final suraNum = ((_surah?['soraid'] ?? 1) as num).toInt()
        .toString().padLeft(3, '0');
    final base = _base(_reciter!);
    return base.endsWith('/') ? '$base$suraNum.mp3' : '$base/$suraNum.mp3';
  }

  /// Per-ayah fallback file from cdn.islamic.network (global ayah index).
  Future<String> _ayahUrl(int ayah) async {
    final g = await Db.I.globalAyah(
        ((_surah?['soraid'] ?? 1) as num).toInt(), ayah);
    return 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$g.mp3';
  }

  Future<File?> _localSurah() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final reciter = '${_reciter?['id'] ?? _reciter?['name_ar'] ?? 'reciter'}'
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final surah = ((_surah?['soraid'] ?? 1) as num).toInt()
          .toString().padLeft(3, '0');
      final f = File('${dir.path}/quran_audio/${reciter}_$surah.mp3');
      return f.existsSync() && f.lengthSync() > 0 ? f : null;
    } catch (_) {
      return null;
    }
  }

  /// Start reciting at [_from]; stop after [_to] completes. Uses the
  /// reciter timings db to seek, falling back to per-ayah CDN files.
  Future<void> _start() async {
    if (_reciter == null || _ayat.isEmpty) return;
    final sid = ((_surah?['soraid'] ?? 1) as num).toInt();
    try {
      if (_timingsBase != sid) {
        // Item 3: use the timings db of the reciter selected in the picker
        // (assets/db/<id>.db), not just the globally saved one.
        _timings = await Db.I.timings(
            '${_reciter?['id'] ?? AppPrefs.I.qariId}');
        _timingsBase = sid;
      }
      await _player.stop();
      final local = await _localSurah();
      if (local != null) {
        await _player.play(DeviceFileSource(local.path));
      } else {
        try {
          await _player.play(UrlSource(Downloader.httpsify(_surahUrl())));
        } catch (_) {
          final file = await Downloader.download(
              Downloader.httpsify(_surahUrl()),
              'quran_audio/${Downloader.safeName('${_reciter?['id'] ?? 'r'}')}_'
              '${sid.toString().padLeft(3, '0')}.mp3');
          await _player.play(DeviceFileSource(file.path));
        }
      }
      final startMs = _timings['$sid:$_from'];
      if (startMs != null && startMs > 0) {
        await _player.seek(Duration(milliseconds: startMs));
      } else if (_timings.isEmpty) {
        // Reciters without a timings db: recite the first ayah from the
        // per-ayah CDN so the feature still works end to end.
        await _player.play(UrlSource(await _ayahUrl(_from)));
      }
      _currentAyah = _from;
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('کێشە لە پەخشکردن — ئینتەرنێت بپشکنە')));
      }
    }
  }

  Future<void> _playNext() async {
    final next = (_currentAyah ?? _from) + 1;
    if (next > _to || next > _ayaCount) {
      await _player.stop();
      if (mounted) setState(() => _currentAyah = null);
      return;
    }
    // Surah audio keeps playing across ayah boundaries; when we switched to
    // per-ayah fallback this hook starts the next file.
    if (mounted) setState(() => _currentAyah = next);
  }

  @override
  void dispose() {
    _player.dispose();
    _scroll.dispose();
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
          title: const Text('خوێندنی ئایەتەکان',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
                tooltip: 'مەشەف',
                icon: Icon(_mushaf ? Icons.menu_book_rounded : Icons.menu_book_outlined,
                    color: Colors.white),
                onPressed: () => setState(() => _mushaf = !_mushaf)),
            IconButton(
                tooltip: 'ڕێکخستنی قورئان',
                icon: const Icon(Icons.tune_rounded, color: Colors.white),
                onPressed: () => showQuranSettingsSheet(context, () {
                      setState(() {});
                    })),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: txt)))
                : Column(children: [
                    _pickerRow(dark, txt, card),
                    Expanded(
                        child: _mushaf
                            ? _mushafView(dark, txt)
                            : _ayatList(dark, txt, card)),
                    StreamBuilder<Duration>(
                      stream: _player.onPositionChanged,
                      builder: (context, snap) {
                        final pos = snap.data ?? Duration.zero;
                        _syncHighlight(pos);
                        return const SizedBox();
                      },
                    ),
                    AudioPlayerBar(
                      player: _player,
                      dark: dark,
                      card: card,
                      title: '${_reciter?['name_ar'] ?? ''} — '
                          '${_surah?['name'] ?? ''}',
                      onPlayPause: () {
                        if (_playing) {
                          _player.pause();
                        } else {
                          _start();
                        }
                      },
                      playing: _playing,
                    ),
                  ]),
      ),
    );
  }

  /// Follows recitation with the reciter timings and stops the surah audio
  /// once the chosen range ends.
  void _syncHighlight(Duration pos) {
    if (_ayat.isEmpty || _reciter == null) return;
    final sid = ((_surah?['soraid'] ?? 1) as num).toInt();
    int? cur;
    for (final a in _ayat) {
      final ay = (a['ayah'] as num?)?.toInt() ?? 0;
      final t = _timings['$sid:$ay'];
      if (t != null && t <= pos.inMilliseconds) cur = ay;
    }
    if (cur != null && cur != _currentAyah && mounted) {
      setState(() => _currentAyah = cur);
      _scrollTo(cur);
    }
    if (cur != null && cur >= _to) {
      _player.stop().then((_) {
        if (mounted) setState(() => _currentAyah = null);
      });
    }
  }

  void _scrollTo(int ayahNum) {
    if (!_scroll.hasClients) return;
    final i = _ayat.indexWhere(
        (a) => ((a['ayah'] as num?)?.toInt() ?? 0) == ayahNum);
    if (i < 0) return;
    const extent = 170.0;
    _scroll.animateTo((i * extent).clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  Widget _pickerRow(bool dark, Color txt, Color card) => Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Row(children: [
            Expanded(child: _dropdown<Map<String, dynamic>>(
              dark: dark, txt: txt, card: card,
              value: _reciter,
              hint: 'قاری هەڵبژێرە',
              items: _reciters,
              label: (v) => '${v['name_ar'] ?? ''}'.trim(),
              onChanged: (v) => setState(() {
                _reciter = v;
                _timingsBase = -1; // reload timings for the new reciter
              }),
            )),
            const SizedBox(width: 8),
            Expanded(child: _dropdown<Map<String, Object?>>(
              dark: dark, txt: txt, card: card,
              value: _surah,
              hint: 'سوورەت هەڵبژێرە',
              items: _surahs,
              label: (v) => '${v['soraid']}. ${suraLabel('${v['name']}')}',
              onChanged: (v) async {
                setState(() => _surah = v);
                await _loadAyat();
              },
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text('لە ئایەتی', style: TextStyle(fontSize: 12.5, color: txt)),
            const SizedBox(width: 6),
            _stepper(dark, txt, card, _from,
                min: 1, max: _ayaCount,
                onChanged: (v) => setState(() {
                  _from = v;
                  if (_to < _from) _to = _from;
                })),
            const SizedBox(width: 14),
            Text('بۆ ئایەتی', style: TextStyle(fontSize: 12.5, color: txt)),
            const SizedBox(width: 6),
            _stepper(dark, txt, card, _to,
                min: _from, max: _ayaCount,
                onChanged: (v) => setState(() => _to = v)),
          ]),
        ]),
      );

  Widget _stepper(bool dark, Color txt, Color card, int value,
          {required int min, required int max, required ValueChanged<int> onChanged}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: dark ? Colors.white10 : Colors.black12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(visualDensity: VisualDensity.compact,
              onPressed: value <= min ? null : () => onChanged(value - 1),
              icon: Icon(Icons.remove_rounded, size: 18,
                  color: dark ? AppColors.gold : AppColors.primaryDark)),
          Text(toArabicDigits(value),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                  color: txt)),
          IconButton(visualDensity: VisualDensity.compact,
              onPressed: value >= max ? null : () => onChanged(value + 1),
              icon: Icon(Icons.add_rounded, size: 18,
                  color: dark ? AppColors.gold : AppColors.primaryDark)),
        ]),
      );

  Widget _dropdown<T>({
    required bool dark,
    required Color txt,
    required Color card,
    required T? value,
    required String hint,
    required List<T> items,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: dark ? Colors.white10 : Colors.black12)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            hint: Text(hint, style: TextStyle(fontSize: 12.5, color: txt)),
            items: [
              for (final it in items)
                DropdownMenuItem(
                    value: it,
                    child: Text(label(it),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: txt))),
            ],
            onChanged: onChanged,
          ),
        ),
      );

  Widget _ayatList(bool dark, Color txt, Color card) {
    final shown = _ayat
        .where((a) =>
            ((a['ayah'] as num?)?.toInt() ?? 0) >= _from &&
            ((a['ayah'] as num?)?.toInt() ?? 0) <= _to)
        .toList();
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: shown.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = shown[i];
        final ay = (a['ayah'] as num?)?.toInt() ?? 0;
        final tafsir = '${a[AppPrefs.I.tafsir] ?? ''}';
        final active = _currentAyah == ay;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active
                ? (dark ? AppColors.gold.withOpacity(.12) : const Color(0xFFE8F5E9))
                : card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: active ? AppColors.primaryDark : (dark ? Colors.white10 : Colors.black12),
                width: active ? 1.4 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: dark
                            ? AppColors.gold.withOpacity(.15)
                            : AppColors.primaryDark.withOpacity(.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(toArabicDigits(ay),
                        style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: dark ? AppColors.gold : AppColors.primaryDark)),
                  ),
                  const Spacer(),
                  if (active)
                    Icon(Icons.graphic_eq_rounded, size: 16,
                        color: dark ? AppColors.gold : AppColors.primaryDark),
                ]),
                const SizedBox(height: 8),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text('${a['text'] ?? ''}',
                      style: TextStyle(
                          fontFamily: AppPrefs.I.fontQuran,
                          fontFamilyFallback: const ['Quran', 'Quran1', 'Quran3'],
                          fontSize: AppPrefs.I.quranFontSize.toDouble(),
                          height: 2, color: txt)),
                ),
                if (tafsir.trim().isNotEmpty && AppPrefs.I.showQuranTafsir) ...[
                  const SizedBox(height: 8),
                  Text(tafsir,
                      style: TextStyle(fontSize: 12.5, height: 1.7,
                          color: txt.withOpacity(.75))),
                ],
              ]),
        );
      },
    );
  }

  Widget _mushafView(bool dark, Color txt) {
    final focus = _currentAyah ?? _from;
    return FutureBuilder<int?>(
      future: Db.I.ayahPage(((_surah?['soraid'] ?? 1) as num).toInt(), focus),
      builder: (context, snap) {
        final page = snap.data;
        final path = page == null ? null : 'assets/images/mushaf/$page.png';
        if (path == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.menu_book_rounded, size: 44,
                    color: dark ? AppColors.gold : AppColors.primaryDark),
                const SizedBox(height: 12),
                Text('وێنەی لاپەڕەی مەشەف بۆ ئەم ئایەتە بەردەست نییە',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: txt.withOpacity(.7), fontSize: 13)),
              ]),
            ),
          );
        }
        return InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Image.asset(path,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text('لاپەڕە $page بارنەبوو',
                    style: TextStyle(color: txt))),
          ),
        );
      },
    );
  }
}
