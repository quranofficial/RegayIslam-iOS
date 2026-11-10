import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart';
import '../../data/db.dart';
import '../../data/downloader.dart';
import '../../data/reciters.dart';
import 'mushaf_screen.dart';
import 'open_quran.dart' show toArabicDigits;

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
  /// Item 8: the reciter/surah/range pickers no longer sit in the middle
  /// of the screen — the reader shows ONLY the Quran. The pickers hide
  /// behind the ⚙ appbar action for when they are really needed.
  bool _showPickers = false;
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _scroll = ScrollController();
  Map<String, int> _timings = {};
  int _timingsBase = -1; // surah id the timings belong to

  // --- Playback robustness (the stop-after-2-3-ayahs bug): streams die
  // mid-surah and the per-ayah chain used to end silently. Every position
  // advance is tracked; a watchdog + post-stop check auto-continue the
  // recitation from the last position via the downloaded local file.
  bool _perAyahMode = false; // reciter without a timings db → per-ayah files
  int _lastPosMs = 0;
  int _lastDurMs = 0;
  DateTime _lastAdvance = DateTime.now();
  bool _recovering = false;
  bool _postChecking = false;
  int _recoverTries = 0;
  Timer? _stall;

  @override
  void initState() {
    super.initState();
    AudioSetup.prepare(_player); // item 2: steady full volume everywhere
    _load();
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s == PlayerState.playing);
      if ((s == PlayerState.completed || s == PlayerState.stopped) &&
          !_perAyahMode && !_recovering) {
        _postStopCheck(); // natural end vs premature death
      }
    });
    _player.onDurationChanged.listen((d) {
      if (d > Duration.zero) _lastDurMs = d.inMilliseconds;
    });
    _player.onPositionChanged.listen((p) {
      if (p.inMilliseconds > _lastPosMs) {
        _lastPosMs = p.inMilliseconds;
        _lastAdvance = DateTime.now();
      }
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      _playNext();
    });
    _stall = Timer.periodic(const Duration(seconds: 4), (_) => _watchdogTick());
  }

  Future<void> _load() async {
    try {
      // Only doxx=true reciters (audio + timings db assets/db/<id>.db ready).
      final reciters = await Reciters.supportedList();
      final surahs = await Db.I.surahs();
      if (!mounted) return;
      setState(() {
        _reciters = reciters;
        _surahs = surahs;
        if (_reciters.isNotEmpty) {
          // Start with the reciter the whole app already uses, when present.
          final saved = AppPrefs.I.qariId;
          _reciter = reciters.firstWhere(
              (r) => '${r['id']}' == saved,
              orElse: () => reciters.first);
        }
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
      _recoverTries = 0;
      _lastPosMs = 0;
      final startMs = _timings['$sid:$_from'];
      if (startMs == null || startMs <= 0) {
        // Reciters without a timings db: recite ayah by ayah from the
        // per-ayah CDN — and CONTINUE through the whole range (the old
        // code played one ayah and went silent).
        _perAyahMode = true;
        if (mounted) setState(() => _currentAyah = _from);
        await _playAyahFile(_from);
        return;
      }
      _perAyahMode = false;
      // Stream first for an instant start — but wait for the source to
      // be ready BEFORE seeking (seeking a buffering stream used to kill
      // playback after a couple of ayahs).
      bool started = false;
      try {
        await _player.stop();
        await _player.play(UrlSource(Downloader.httpsify(_surahUrl())));
        var dur = 0;
        for (var i = 0; i < 16 && dur <= 0; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          try { dur = (await _player.getDuration())?.inMilliseconds ?? 0; } catch (_) { dur = 0; }
        }
        await _player.seek(Duration(milliseconds: startMs));
        started = true;
        _lastPosMs = startMs;
        _lastDurMs = dur;
        _lastAdvance = DateTime.now();
      } catch (_) {
        started = false;
      }
      if (!started) {
        // local file never stalls mid-stream — bullet-proof path
        final file = await Downloader.download(
            Downloader.httpsify(_surahUrl()),
            'quran_audio/${Downloader.safeName('${_reciter?['id'] ?? 'r'}')}_'
            '${sid.toString().padLeft(3, '0')}.mp3');
        await _player.stop();
        await _player.play(DeviceFileSource(file.path));
        await _player.seek(Duration(milliseconds: startMs));
        _lastPosMs = startMs;
        _lastAdvance = DateTime.now();
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

  /// One per-ayah file (per-ayah mode) — cached locally when possible.
  Future<void> _playAyahFile(int ayah) async {
    try {
      await _player.stop();
      if (mounted) setState(() => _currentAyah = ayah);
      final sid = ((_surah?['soraid'] ?? 1) as num).toInt();
      final g = await Db.I.globalAyah(sid, ayah);
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/quran_audio/ayah_$g.mp3');
      final url = Downloader.httpsify(await _ayahUrl(ayah));
      if (f.existsSync() && f.lengthSync() > 0) {
        await _player.play(DeviceFileSource(f.path));
      } else {
        try {
          await _player.play(UrlSource(url));
        } catch (_) {
          final got = await Downloader.download(
              url, 'quran_audio/ayah_$g.mp3',
              timeout: const Duration(minutes: 3));
          await _player.play(DeviceFileSource(got.path));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('کێشە لە پەخشکردنی دەنگی ئەم ئایەتە')));
      }
    }
  }

  Future<void> _playNext() async {
    final next = (_currentAyah ?? _from) + 1;
    if (next > _to || next > _ayaCount) {
      await _player.stop();
      _lastPosMs = 0;
      if (mounted) setState(() => _currentAyah = null);
      return;
    }
    if (_perAyahMode) {
      // Per-ayah fallback: actually START the next file — the old hook
      // only moved the highlight and went silent.
      await _playAyahFile(next);
      return;
    }
    // Surah audio keeps playing across ayah boundaries.
    if (mounted) setState(() => _currentAyah = next);
  }

  // ---------- Playback recovery ----------

  /// Watchdog: a frozen position for 10s while "playing" = stalled stream
  /// → auto-continue from the last position.
  Future<void> _watchdogTick() async {
    if (!mounted || _recovering || _postChecking) return;
    if (_perAyahMode) return;
    if (!_playing) return;
    final idle = DateTime.now().difference(_lastAdvance).inMilliseconds;
    if (idle < 10000) return;
    await _recoverSurah();
  }

  /// stopped/completed fired — surah finished naturally, or died early?
  Future<void> _postStopCheck() async {
    if (_postChecking || !mounted || _perAyahMode) return;
    if (_lastPosMs < 3000 || _currentAyah == null) return;
    _postChecking = true;
    try {
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted || _recovering || _perAyahMode) return;
      if (_playing) return; // resumed in the meantime
      final dur = _lastDurMs;
      if (dur > 0 && _lastPosMs >= dur - 4000) {
        // natural end — the range is done
        if (mounted) setState(() => _currentAyah = null);
        _lastPosMs = 0;
        return;
      }
      await _recoverSurah();
    } finally {
      _postChecking = false;
    }
  }

  /// Resume the surah audio from the last position: plain resume first,
  /// then the fully downloaded local file (never dies mid-stream).
  Future<void> _recoverSurah() async {
    if (_recovering || !mounted) return;
    final resumeAt = _lastPosMs;
    if (resumeAt < 3000) return;
    _recovering = true;
    try {
      if (_recoverTries >= 3) {
        if (mounted) setState(() => _currentAyah = null);
        return;
      }
      _recoverTries++;
      try { await _player.resume(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted || _playing) return; // it recovered
      try {
        final file = await Downloader.download(
            Downloader.httpsify(_surahUrl()),
            'quran_audio/${Downloader.safeName('${_reciter?['id'] ?? 'r'}')}_'
            '${((_surah?['soraid'] ?? 1) as num).toInt().toString().padLeft(3, '0')}.mp3',
            timeout: const Duration(minutes: 5));
        await _player.stop();
        await _player.play(DeviceFileSource(file.path));
        await _player.seek(Duration(milliseconds: resumeAt));
        _lastPosMs = resumeAt;
        _lastAdvance = DateTime.now();
        if (mounted) setState(() {});
      } catch (_) {
        if (mounted) setState(() => _currentAyah = null);
      }
    } finally {
      _recovering = false;
    }
  }

  @override
  void dispose() {
    _stall?.cancel();
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
                tooltip: 'هەڵبژاردنی قاری و ئایەت',
                icon: Icon(Icons.tune_rounded,
                    color: _showPickers ? AppColors.gold : Colors.white),
                onPressed: () => setState(() => _showPickers = !_showPickers)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: txt)))
                : Column(children: [
                    // Item 8: only the Quran remains on the page — the
                    // pickers are folded away behind the ⚙ button.
                    if (_showPickers) _pickerRow(dark, txt, card),
                    if (!_showPickers && _surah != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                        child: Row(children: [
                          Icon(Icons.menu_book_rounded, size: 17,
                              color: dark ? AppColors.gold : AppColors.primaryDark),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                                '${suraLabel('${_surah!['name'] ?? ''}')} — '
                                'ئایەتی ${toArabicDigits(_from)} بۆ ${toArabicDigits(_to)}'
                                ' • ${_reciter?['name_ar'] ?? AppPrefs.I.qariName}',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: dark ? AppColors.gold : AppColors.primaryDark)),
                          ),
                        ]),
                      ),
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
            const SizedBox(width: 10),
            // One tap = recite to the END of the surah (no more manually
            // stepping the range up while the audio keeps stopping at the
            // range edge).
            ActionChip(
              visualDensity: VisualDensity.compact,
              backgroundColor: _to >= _ayaCount
                  ? (dark ? AppColors.gold.withOpacity(.25) : AppColors.primaryDark.withOpacity(.12))
                  : card,
              side: BorderSide(
                  color: dark ? Colors.white24 : Colors.black12),
              label: Text('بۆ کۆتایی',
                  style: TextStyle(fontSize: 11.5,
                      color: _to >= _ayaCount
                          ? (dark ? AppColors.gold : AppColors.primaryDark)
                          : txt)),
              onPressed: () => setState(() => _to = _ayaCount),
            ),
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
    // Item 10: the real 604-page mushaf, opened at the current ayah.
    return MushafScreen(
        surahId: ((_surah?['soraid'] ?? 1) as num).toInt(),
        ayah: _currentAyah ?? _from,
        title: '${_surah?['name'] ?? ''}');
  }
}
