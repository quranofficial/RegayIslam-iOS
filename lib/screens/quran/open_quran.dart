import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart';
import '../../data/db.dart';
import 'reciter_picker.dart';
import '../../data/downloader.dart';
import '../../data/favorites.dart';
import 'mushaf_screen.dart';
import 'quran_settings_sheet.dart';

/// Original: OpenquranActivity — ayah list with tafsir, audio playback with
/// ayah highlighting via the reciter timings dbs, and mushaf page mode.
///
/// Item 10 upgrades:
///  • tapping an ayah number recites from THAT ayah to the end of the
///    surah, ayah by ayah, highlighting + auto-scrolling each verse;
///  • the mushaf button opens the real 604-page MushafScreen at this ayah;
///  • reader text/background colors from the Quran editor are respected.
class OpenQuranScreen extends StatefulWidget {
  const OpenQuranScreen({
    super.key,
    required this.surahId,
    required this.surahName,
    required this.ayaCount,
    required this.place,
    required this.juz,
    this.initialAyah,
    this.highlightAyah,
    this.highlightWord,
  });

  final int surahId;
  final String surahName;
  final int ayaCount;
  final String place;
  final String juz;

  /// Item 3: when opened from a favorite / the daily ayah / a name of
  /// Allah, the reader opens AT that ayah (not at the top of the surah),
  /// scrolls to it and rings it for a few seconds.
  final int? initialAyah;
  final int? highlightAyah;

  /// Item 13: a word to highlight inside the ayah text (e.g. one of the
  /// 99 names of Allah appearing in the verse).
  final String? highlightWord;

  @override
  State<OpenQuranScreen> createState() => _OpenQuranScreenState();
}

class _OpenQuranScreenState extends State<OpenQuranScreen> {
  List<Map<String, Object?>> _ayat = [];
  bool _loading = true;
  String _tafsir = 'rebar';
  final AudioPlayer _player = AudioPlayer();
  String? _currentUrl;
  int? _playingAyah;

  /// null = whole-surah mode; non-null = playing ayah-by-ayah from here.
  bool _ayahByAyah = false;
  PlayerState _state = PlayerState.stopped;
  Map<String, int> _timings = {};
  final ScrollController _scroll = ScrollController();

  /// Item 3: the ayah that came from outside (favorite / daily ayah /
  /// name of Allah) keeps a golden ring for a few seconds.
  int? _ringedAyah;
  Timer? _ringTimer;

  /// Item 3: reading position is remembered while scrolling, so "بەردەوامبوون"
  /// (continue reading) can always return to the same place.
  int _lastVisibleAyah = 1;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  /// Item 10: one GlobalKey per ayah row so "recite from this ayah"
  /// scrolls to the EXACT widget (the old fixed 170px estimate landed on
  /// the wrong verse on long surahs).
  final Map<int, GlobalKey> _ayahKeys = {};

  // --- Playback robustness (keshay peshraw / the stop-after-2-3-ayahs bug):
  // network streams stall or die mid-surah (often around 30-40% of a long
  // surah) and the old code never recovered — pressing play did nothing.
  // Now: every position advance is tracked, a watchdog + a post-stop check
  // detect premature death and the playback auto-continues from the last
  // position using the fully-downloaded local file.
  int _lastPosMs = 0; // last observed playback position
  int _lastDurMs = 0; // last known duration of the active source
  DateTime _lastAdvance = DateTime.now(); // when position last moved
  bool _recovering = false; // auto-continue in progress
  bool _postChecking = false; // single-flight for the stop check
  int _recoverTries = 0; // cap auto-recovery attempts per session
  Timer? _stall; // watchdog tick
  // item 12: repeat each ayah 1/3/5/10 times before moving on
  int _repeatLeft = 1;
  bool _reseeking = false;

  // item 1+6: the ROW repeat mode — a button on every ayah row repeats
  // THAT ayah N times (or ∞) and then stops. _repeatTotal: 0 = off,
  // -1 = بێسنوور, N = that many plays. _repeatDone drives the live
  // "دووبارە ٢/٥" badge on the verse row so the feature is VISIBLE.
  int _repeatTotal = 0;
  int _repeatDone = 0;

  bool get _rowRepeatActive => _repeatTotal != 0 && _ayahByAyah;

  @override
  void initState() {
    super.initState();
    AudioSetup.prepare(_player); // item 2: steady full volume everywhere
    _tafsir = AppPrefs.I.tafsir;
    _load();
    _scroll.addListener(_onScroll);
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
      if ((s == PlayerState.completed || s == PlayerState.stopped) &&
          !_ayahByAyah && _currentUrl != null && !_recovering) {
        _postStopCheck(); // natural end of the surah, or a premature death?
      }
    });
    _player.onDurationChanged.listen((d) {
      if (d > Duration.zero) _lastDurMs = d.inMilliseconds;
    });
    _player.onPositionChanged.listen((p) {
      if (!_ayahByAyah) _highlightByTime(p);
      if (p.inMilliseconds > _lastPosMs) {
        _lastPosMs = p.inMilliseconds;
        _lastAdvance = DateTime.now();
      }
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      if (_ayahByAyah && _playingAyah != null) {
        // item 1+6: ROW repeat — the verse from the row button replays N
        // times (or forever) and then STOPS, with a live badge on the row.
        if (_rowRepeatActive) {
          if (_repeatTotal == -1 || _repeatDone < _repeatTotal) {
            _repeatDone++;
            if (mounted) setState(() {});
            _playAyahFile(_playingAyah!);
            return;
          }
          // all repeats finished — stop and clear the badge
          _stopRowRepeat(done: true);
          return;
        }
        // item 12: repeat the SAME ayah 1/3/5/10 times first
        if (_repeatLeft > 1) {
          _repeatLeft--;
          _playAyahFile(_playingAyah!);
          return;
        }
        _repeatLeft = AppPrefs.I.ayahRepeat;
        final next = _playingAyah! + 1;
        if (next <= widget.ayaCount) {
          _playAyahFile(next);
          return;
        }
      }
      _postStopCheck();
    });
    _stall = Timer.periodic(const Duration(seconds: 4), (_) => _watchdogTick());
  }

  Future<void> _load() async {
    final rows = await Db.I.ayat(widget.surahId, _tafsir);
    if (!mounted) return;
    setState(() { _ayat = rows; _loading = false; });
    _timings = await Db.I.timings(AppPrefs.I.qariId);
    // Item 3: jump straight to the requested ayah (favorite / daily ayah /
    // a name of Allah) and ring it so the user sees exactly where it is.
    final target = widget.initialAyah ?? widget.highlightAyah;
    if (target != null && target > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToAyah(target);
        setState(() => _ringedAyah = target);
        _ringTimer?.cancel();
        _ringTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) setState(() => _ringedAyah = null);
        });
      });
    }
  }

  /// Item 3: while the reader scrolls, remember which ayah is on top and
  /// persist it (throttled) as the last-read position.
  void _onScroll() {
    if (!mounted || _ayat.isEmpty || !_scroll.hasClients) return;
    int? topAyah;
    double bestTop = double.infinity;
    for (final a in _ayat) {
      final n = (a['ayah'] as num?)?.toInt() ?? 0;
      final ctx = _ayahKeys[n]?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top >= -80 && top < bestTop) {
        bestTop = top;
        topAyah = n;
      }
    }
    if (topAyah == null) return;
    _lastVisibleAyah = topAyah;
    final now = DateTime.now();
    if (now.difference(_lastSave).inMilliseconds > 1500) {
      _lastSave = now;
      AppPrefs.I.saveReadingPosition(widget.surahId, topAyah);
    }
  }

  /// Item: reciter switcher ON the Quran page — the picked reciter is
  /// saved globally (mushaf + all other screens follow) and the ayah
  /// highlight timings are reloaded from that reciter's own db.
  Future<void> _pickReciter() async {
    final picked = await ReciterPickerSheet.show(context,
        currentId: AppPrefs.I.qariId, dark: !AppPrefs.I.day);
    if (picked == null || !mounted) return;
    // Save globally so the whole app (mushaf included) uses it — same
    // prefs QariakanScreen writes.
    AppPrefs.I.qariId = '${picked['id'] ?? ''}';
    AppPrefs.I.qariName = '${picked['name_ar'] ?? 'قاری'}'.trim();
    AppPrefs.I.qariUrl = '${picked['url'] ?? ''}'
        .replaceFirst(RegExp(r'^http://', caseSensitive: false), 'https://');
    await _player.stop();
    _currentUrl = null;
    _timings = await Db.I.timings(AppPrefs.I.qariId);
    if (!mounted) return;
    setState(() {
      _state = PlayerState.stopped;
      _playingAyah = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('قاری: ${picked['name_ar'] ?? ''} — دەنگ و ئایەت بەردەستە'),
        duration: const Duration(seconds: 2)));
  }

  String _mp3Url(String link) {
    if (link.startsWith('http')) return link;
    final n = link.replaceAll('.mp3', '').padLeft(3, '0');
    // Original: OpenquranActivity plays pref "url" + <surah>.mp3, reciter
    // chosen in QariakanActivity (default سعد الغامدي from SplashActivity).
    final base = AppPrefs.I.qariUrl;
    return base.endsWith('/') ? '$base$n.mp3' : '$base/$n.mp3';
  }

  /// Global per-ayah audio index (1..6236) for ayah-by-ayah recitation.
  Future<String> _ayahUrl(int ayah) async {
    final g = await Db.I.globalAyah(widget.surahId, ayah);
    return 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$g.mp3';
  }

  Future<File?> _cachedAudio() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/quran_audio/'
          '${Downloader.safeName(AppPrefs.I.qariId)}_'
          '${widget.surahId.toString().padLeft(3, '0')}.mp3');
      if (f.existsSync() && f.lengthSync() > 0) {
        // A partial download (app killed mid-fetch) plays a few seconds and
        // dies at the same spot forever — drop files that are impossibly
        // small for a real surah so they get re-downloaded.
        if (f.lengthSync() < 150000) {
          try { f.deleteSync(); } catch (_) {}
          return null;
        }
        return f;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<File?> _cachedAyahAudio(int ayah) async {
    try {
      final g = await Db.I.globalAyah(widget.surahId, ayah);
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/quran_audio/ayah_$g.mp3');
      return f.existsSync() && f.lengthSync() > 0 ? f : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _playSurah() async {
    final link = _ayat.isEmpty ? '' : '${_ayat.first['link'] ?? ''}';
    if (link.isEmpty) return;
    final url = Downloader.httpsify(_mp3Url(link));
    _ayahByAyah = false;
    try {
      if (_currentUrl == url && _state == PlayerState.playing) {
        await _player.pause();
      } else if (_currentUrl == url && _state == PlayerState.paused) {
        await _player.resume();
      } else {
        _recoverTries = 0;
        _lastPosMs = 0;
        _repeatLeft = AppPrefs.I.ayahRepeat;
        final cached = await _cachedAudio();
        if (cached != null) {
          await _player.play(DeviceFileSource(cached.path));
        } else {
          try {
            await _player.play(UrlSource(url));
          } catch (_) {
            // streaming refused — download then play, like the original
            if (await _playSurahLocal(notify: true)) return;
            rethrow; // surface the network snackbar below
          }
        }
        setState(() => _currentUrl = url);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('کێشە لە داگرتنی دەنگ، تکایە ئینتەرنێت بپشکنە')));
      }
    }
  }

  // ---------- Playback recovery (keshay peshraw) ----------

  /// Watchdog: while the surah audio is "playing", the position must keep
  /// advancing. A frozen position for 10s = stalled stream → auto-continue
  /// from the last position via the downloaded local file.
  Future<void> _watchdogTick() async {
    if (!mounted || _recovering || _postChecking) return;
    if (_ayahByAyah || _currentUrl == null) return;
    if (_state != PlayerState.playing) return;
    final idle = DateTime.now().difference(_lastAdvance).inMilliseconds;
    if (idle < 10000) return;
    await _recoverSurah();
  }

  /// The player reported stopped/completed (or froze) — was that the
  /// natural end of the surah audio, or a premature death that must be
  /// resumed so recitation keeps going through ALL the ayahs?
  Future<void> _postStopCheck() async {
    if (_postChecking || !mounted) return;
    if (_ayahByAyah || _currentUrl == null || _lastPosMs < 3000) return;
    _postChecking = true;
    try {
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted || _recovering || _currentUrl == null) return;
      if (_state == PlayerState.playing || _state == PlayerState.paused) {
        return; // resumed in the meantime
      }
      final dur = _lastDurMs;
      if (dur > 0 && _lastPosMs >= dur - 4000) {
        // natural end of the surah audio — clean up for a fresh next play
        setState(() {
          _state = PlayerState.stopped;
          _playingAyah = null;
          _currentUrl = null;
          _lastPosMs = 0;
        });
        return;
      }
      await _recoverSurah();
    } finally {
      _postChecking = false;
    }
  }

  /// Premature stop — resume recitation from the last position: first try
  /// a plain resume (transient stall), then fall back to the fully
  /// downloaded local file which never dies mid-stream.
  Future<void> _recoverSurah() async {
    if (_recovering || !mounted) return;
    final resumeAt = _lastPosMs;
    if (resumeAt < 3000) return;
    _recovering = true;
    try {
      if (_recoverTries >= 3) {
        if (mounted) {
          setState(() => _state = PlayerState.stopped);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('پەخشکردن وەستا — دوگمەی لێدە بدە بۆ بەردەوامبوون')));
        }
        return;
      }
      _recoverTries++;
      try {
        await _player.resume();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted || _state == PlayerState.playing) return; // it recovered
      final ok = await _playSurahLocal(resumeMs: resumeAt);
      if (!ok && mounted) setState(() => _state = PlayerState.stopped);
    } finally {
      _recovering = false;
    }
  }

  /// Bullet-proof surah playback from the LOCAL cached file — the file is
  /// downloaded in full first (missing parts can never stall mid-play)
  /// and seeking is instant and reliable. Returns true when playback is
  /// actually running.
  Future<bool> _playSurahLocal(
      {int resumeMs = 0, int startMs = 0, bool notify = false}) async {
    final link = _ayat.isEmpty ? '' : '${_ayat.first['link'] ?? ''}';
    if (link.isEmpty) return false;
    final url = Downloader.httpsify(_mp3Url(link));
    try {
      File? f = await _cachedAudio();
      if (f == null) {
        if (notify && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('دەنگ داگیر دەکرێت — چەند چرکەیەک...'),
              duration: Duration(seconds: 2)));
        }
        f = await Downloader.download(
            url,
            'quran_audio/${Downloader.safeName(AppPrefs.I.qariId)}_'
            '${widget.surahId.toString().padLeft(3, '0')}.mp3',
            timeout: const Duration(minutes: 5));
      }
      await _player.stop();
      await _player.play(DeviceFileSource(f.path));
      final at = resumeMs > 0 ? resumeMs : startMs;
      if (at > 0) await _player.seek(Duration(milliseconds: at));
      if (!mounted) return true;
      setState(() {
        _currentUrl = url;
        _state = PlayerState.playing;
      });
      _lastPosMs = at;
      _lastDurMs = 0;
      _lastAdvance = DateTime.now();
      _recoverTries = 0;
      _scrollToAyah(_playingAyah ?? 1);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- item 1+6: ROW repeat (button on the ayah row) ----------

  /// Opens the shared count sheet from the ayah row button and starts
  /// repeating exactly that verse.
  Future<void> _repeatThisAyah(int ayah) async {
    final dark = !AppPrefs.I.day;
    final n = await showRepeatCountSheet(context,
        dark: dark,
        title: 'دووبارەکردنەوەی ئایەتی ${toArabicDigits(ayah)}',
        subtitle: 'ئایەتەکە بە دەنگی ${AppPrefs.I.qariName} '
            'دووبارە دەکرێتەوە و دواتر وەستێنراو دەبێت');
    if (n == null || !mounted) return;
    _startRowRepeat(ayah, n);
  }

  void _startRowRepeat(int ayah, int n) {
    _recoverTries = 0;
    setState(() {
      _ayahByAyah = true;
      _playingAyah = ayah;
      _repeatTotal = n == 0 ? -1 : n;
      _repeatDone = 1;
      _repeatLeft = n == 0 ? (1 << 30) : n;
    });
    _playAyahFile(ayah);
  }

  /// Stop the row repeat — also used by the strip's stop button.
  Future<void> _stopRowRepeat({bool done = false}) async {
    _repeatTotal = 0;
    _repeatDone = 0;
    await _player.stop();
    if (!mounted) return;
    setState(() {
      _state = PlayerState.stopped;
      if (done) _playingAyah = null;
    });
    if (done) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('دووبارەکردنەوە تەواو بوو ✅'),
          duration: Duration(milliseconds: 1200)));
    }
  }

  /// Item 10: recite from this ayah to the end of the surah.
  /// Preferred: the SELECTED reciter's own surah audio seeked through its
  /// timings db (highlights follow position). Fallback: per-ayah files.
  Future<void> _playFromAyah(int ayah) async {
    final startMs = _timings['${widget.surahId}:$ayah'];
    if (startMs != null && startMs > 0) {
      setState(() { _ayahByAyah = false; _playingAyah = ayah; });
      // Stream first (instant start); if the stream/seek dies the watchdog
      // and post-stop check auto-continue from the last position.
      final ok = await _playSurahStreamed(startMs);
      if (ok) return;
      final local = await _playSurahLocal(startMs: startMs, notify: true);
      if (local) return;
    }
    setState(() { _ayahByAyah = true; _playingAyah = ayah; });
    await _playAyahFile(ayah);
  }

  /// Play the selected reciter's surah audio and seek to [startMs]. Waits
  /// for the stream metadata before seeking — seeking a still-buffering
  /// network source used to kill playback after 2-3 ayahs.
  Future<bool> _playSurahStreamed(int startMs) async {
    final link = _ayat.isEmpty ? '' : '${_ayat.first['link'] ?? ''}';
    if (link.isEmpty) return false;
    final url = Downloader.httpsify(_mp3Url(link));
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
      // wait until the source is really ready (duration known) — up to 8s
      var dur = 0;
      for (var i = 0; i < 16 && dur <= 0; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        try { dur = (await _player.getDuration())?.inMilliseconds ?? 0; } catch (_) { dur = 0; }
      }
      await _player.seek(Duration(milliseconds: startMs));
      if (!mounted) return true;
      setState(() => _currentUrl = url);
      _repeatLeft = AppPrefs.I.ayahRepeat;
      _lastPosMs = startMs;
      _lastDurMs = dur;
      _lastAdvance = DateTime.now();
      _scrollToAyah(_playingAyah ?? 1);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _playAyahFile(int ayah) async {
    try {
      await _player.stop();
      if (mounted) setState(() => _playingAyah = ayah);
      _scrollToAyah(ayah);
      final cached = await _cachedAyahAudio(ayah);
      if (cached != null) {
        await _player.play(DeviceFileSource(cached.path));
        return;
      }
      final url = Downloader.httpsify(await _ayahUrl(ayah));
      try {
        await _player.play(UrlSource(url));
      } catch (_) {
        final g = await Db.I.globalAyah(widget.surahId, ayah);
        final file = await Downloader.download(
            url, 'quran_audio/ayah_$g.mp3',
            timeout: const Duration(minutes: 3));
        await _player.play(DeviceFileSource(file.path));
      }
    } catch (_) {
      // Per-ayah file failed (offline?) — fall back to the reciter's
      // surah audio starting from the requested ayah via its timings.
      final startMs = _timings['${widget.surahId}:$ayah'];
      if (startMs != null) {
        _ayahByAyah = false;
        final link = _ayat.isEmpty ? '' : '${_ayat.first['link'] ?? ''}';
        if (link.isEmpty) return;
        final url = Downloader.httpsify(_mp3Url(link));
        final cached = await _cachedAudio();
        try {
          await _player.stop();
          if (cached != null) {
            await _player.play(DeviceFileSource(cached.path));
          } else {
            await _player.play(UrlSource(url));
          }
          await _player.seek(Duration(milliseconds: startMs));
          if (mounted) setState(() { _currentUrl = url; _playingAyah = ayah; });
          return;
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('کێشە لە پەخشکردنی دەنگی ئەم ئایەتە')));
      }
    }
  }

  void _highlightByTime(Duration p) {
    if (_timings.isEmpty || _ayat.isEmpty) return;
    final ms = p.inMilliseconds;
    int? cur;
    for (final a in _ayat) {
      final key = '${widget.surahId}:${a['ayah']}';
      final t = _timings[key];
      if (t != null && t <= ms) cur = (a['ayah'] as num).toInt();
    }
    if (cur != null && cur != _playingAyah) {
      // item 12: the finished ayah repeats 1/3/5/10 times — seek back to
      // its own start instead of moving to the next verse.
      if (_repeatLeft > 1 && !_reseeking) {
        _repeatLeft--;
        final again = _timings['${widget.surahId}:$_playingAyah'] ?? 0;
        if (again > 0) {
          _reseeking = true;
          _player.seek(Duration(milliseconds: again)).whenComplete(() {
            _reseeking = false;
          });
          return;
        }
      }
      _repeatLeft = AppPrefs.I.ayahRepeat;
      setState(() => _playingAyah = cur);
      _scrollToAyah(cur);
    }
  }

  @override
  void dispose() {
    _stall?.cancel();
    _ringTimer?.cancel();
    // Item 3: the reading position is saved on leaving the reader too.
    AppPrefs.I.saveReadingPosition(widget.surahId, _lastVisibleAyah);
    _player.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Auto-scroll the ayah list to the currently recited ayah — exact, via
  /// the row's GlobalKey, and CENTERED (item: "la naway awastet beka
  /// setSelection" — the highlighted verse lands in the middle of the
  /// screen, not at the very top edge).
  void _scrollToAyah(int ayahNum) {
    final ctx = _ayahKeys[ayahNum]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          alignment: 0.32);
      return;
    }
    if (!_scroll.hasClients) return;
    final itemIndex = _ayat.indexWhere(
        (a) => ((a['ayah'] as num?)?.toInt() ?? 0) == ayahNum);
    if (itemIndex < 0) return;
    const itemExtent = 170.0;
    final target = (itemIndex * itemExtent).clamp(
        0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut);
  }

  /// item 2 — setSelection to the MIDDLE on seek: the moment the user
  /// drops the seekbar thumb, the highlight + the list jump to the ayah
  /// under that position RIGHT AWAY (no waiting for the next position
  /// tick), and the verse is centered in the viewport.
  void _snapHighlightToSeek(Duration at) {
    if (_timings.isEmpty || _ayat.isEmpty || _rowRepeatActive) return;
    final ms = at.inMilliseconds;
    int? cur;
    for (final a in _ayat) {
      final key = '${widget.surahId}:${a['ayah']}';
      final t = _timings[key];
      if (t != null && t <= ms) cur = (a['ayah'] as num).toInt();
    }
    if (cur == null || cur == _playingAyah) return;
    setState(() => _playingAyah = cur);
    _scrollToAyah(cur);
  }

  /// item 1+6 — the redesigned repeat strip: live status + a real stop
  /// button while a row repeat runs, and the whole-recitation repeat count
  /// (هر ئایەتێک N جار) as pretty segmented pills when idle.
  Widget _repeatStrip(bool dark, Color card, Color txt) {
    final accent = dark ? AppColors.gold : AppColors.primaryDark;
    if (_rowRepeatActive) {
      final target = _repeatTotal == -1 ? '∞' : '${toArabicDigits(_repeatTotal)} جار';
      return Container(
        margin: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withOpacity(.55))),
        child: Row(children: [
          Icon(Icons.repeat_one_rounded, size: 18, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                'دووبارەکردنەوەی ئایەتی '
                '${toArabicDigits(_playingAyah ?? 0)} — $target • جاری '
                '${toArabicDigits(_repeatDone)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold)),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _stopRowRepeat(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('وەستان',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ),
          ),
        ]),
      );
    }
    return Container(
      color: dark ? AppColors.nightBg.withOpacity(.5) : const Color(0xFFF4F5F7),
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
      child: Row(children: [
        Icon(Icons.repeat_rounded, size: 16, color: accent),
        const SizedBox(width: 7),
        Text('دووبارەی هەر ئایەتێک:',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: txt.withOpacity(.75))),
        const SizedBox(width: 6),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final n in const [1, 3, 5, 10])
                GestureDetector(
                  onTap: () => setState(() {
                    AppPrefs.I.ayahRepeat = n;
                    _repeatLeft = n;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppPrefs.I.ayahRepeat == n
                            ? accent
                            : (dark
                                ? Colors.white.withOpacity(.06)
                                : Colors.black.withOpacity(.04)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppPrefs.I.ayahRepeat == n
                                ? accent
                                : accent.withOpacity(.25))),
                    child: Text(n == 1 ? 'یەک جار' : '$n جار',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppPrefs.I.ayahRepeat == n
                                ? (dark ? Colors.black : Colors.white)
                                : txt.withOpacity(.8))),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  void _copyAyah(String ayah, String tafsir) async {
    await copyPage('$ayah\n\n$tafsir');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('کۆپی کرا')));
  }

  /// Item 13: the ayah text with one word highlighted (e.g. one of the 99
  /// names of Allah when the reader is opened from the name screen).
  Widget _ayahText(String text, Color color) {
    final word = (widget.highlightWord ?? '').trim();
    if (word.isEmpty || !text.contains(word)) {
      return Text(text,
          style: TextStyle(
              fontFamily: AppPrefs.I.fontQuran,
              fontFamilyFallback: const ['Quran', 'Quran1', 'Quran3'],
              fontSize: AppPrefs.I.quranFontSize.toDouble(),
              height: 2, color: color));
    }
    final dark = !AppPrefs.I.day;
    final accent = dark ? AppColors.gold : AppColors.primaryDark;
    final spans = <TextSpan>[];
    var rest = text;
    while (rest.isNotEmpty) {
      final i = rest.indexOf(word);
      if (i < 0) {
        spans.add(TextSpan(text: rest));
        break;
      }
      if (i > 0) spans.add(TextSpan(text: rest.substring(0, i)));
      spans.add(TextSpan(
          text: word,
          style: TextStyle(
              background: Paint()..color = accent.withOpacity(.28),
              color: accent,
              fontWeight: FontWeight.bold)));
      rest = rest.substring(i + word.length);
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RichText(
          text: TextSpan(
              style: TextStyle(
                  fontFamily: AppPrefs.I.fontQuran,
                  fontFamilyFallback: const ['Quran', 'Quran1', 'Quran3'],
                  fontSize: AppPrefs.I.quranFontSize.toDouble(),
                  height: 2, color: color),
              children: spans)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final card = dark ? AppColors.nightCard : Colors.white;
    // Item 13: reader colors chosen in the Quran editor (0 = theme default).
    final customText = AppPrefs.I.quranTextColor != 0
        ? Color(AppPrefs.I.quranTextColor)
        : null;
    final customBg = AppPrefs.I.quranBgColor != 0
        ? Color(AppPrefs.I.quranBgColor)
        : null;
    final ayahColor = customText ?? txt;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: customBg ?? (dark ? AppColors.nightBg : Colors.white),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (AppPrefs.I.showQuranSurahName)
              Text(suraLabel(widget.surahName),
                style: const TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.bold)),
            Text('${widget.place} • ${widget.juz}',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
          actions: [
            // The reciter switcher ON the Quran page itself — pick any
            // dangakan doxx=true reciter without leaving the reader.
            IconButton(
                tooltip: 'گۆڕینی قاری — ${AppPrefs.I.qariName}',
                icon: const Icon(Icons.mic_rounded, color: Colors.white),
                onPressed: _pickReciter),
            IconButton(
                icon: const Icon(Icons.tune_rounded, color: Colors.white),
                onPressed: () => showQuranSettingsSheet(context, () {
                      setState(() {}); // refresh font prefs
                    })),
            IconButton(
                tooltip: 'مەشەف',
                icon: const Icon(Icons.menu_book_rounded, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => MushafScreen(
                        surahId: widget.surahId,
                        ayah: _playingAyah ?? 1,
                        title: suraLabel(widget.surahName))))),
            IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                onPressed: () => sharePage(
                    '${suraLabel(widget.surahName)} — ئەپی ڕێگای ئیسلام')),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Expanded(
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: _ayat.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final a = _ayat[i];
                      final ayahNum = (a['ayah'] as num?)?.toInt() ?? 0;
                      final ayahText = '${a['text'] ?? ''}';
                      final tafsir = '${a[_tafsir] ?? ''}';
                      final highlighted = _playingAyah == ayahNum;
                      final ringed = _ringedAyah == ayahNum;
                      final rowRepeatHere = _rowRepeatActive &&
                          _playingAyah == ayahNum;
                      return GestureDetector(
                        key: _ayahKeys.putIfAbsent(ayahNum, () => GlobalKey()),
                        onTap: () => _copyAyah(ayahText, tafsir),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: highlighted
                                ? (dark ? AppColors.nightCard : const Color(0xFFE8F0FE))
                                : (customBg ?? card),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: ringed
                                    ? AppColors.gold
                                    : highlighted
                                        ? AppColors.primaryDark
                                        : dark ? Colors.white10 : Colors.black12,
                                width: ringed ? 2.2 : 1),
                            boxShadow: ringed
                                ? [BoxShadow(
                                    color: AppColors.gold.withOpacity(.35),
                                    blurRadius: 14)]
                                : null,
                          ),
                          child: Column(crossAxisAlignment:
                              CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              if (AppPrefs.I.showQuranAyahNumbers) Tooltip(
                                message: 'لێدان لەم ئایەتەوە',
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => _playFromAyah(ayahNum),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: dark
                                            ? AppColors.gold.withOpacity(.15)
                                            : AppColors.primaryDark.withOpacity(.08),
                                        borderRadius: BorderRadius.circular(10)),
                                    child: Row(mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(toArabicDigits(ayahNum),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: dark
                                                      ? AppColors.gold
                                                      : AppColors.primaryDark)),
                                          const SizedBox(width: 3),
                                          Icon(Icons.play_arrow_rounded,
                                              size: 13,
                                              color: dark
                                                  ? AppColors.gold
                                                  : AppColors.primaryDark),
                                        ]),
                                  ),
                                ),
                              ),
                              // item 1+6: the REPEAT button ON the verse row
                              // — the old repeat was an invisible strip; now
                              // every ayah carries its own repeat control
                              // with a live "دووبارە ٢/٥" badge while active.
                              Tooltip(
                                message: 'دووبارەکردنەوەی ئایەتەکە',
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => _repeatThisAyah(ayahNum),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 5),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: (rowRepeatHere || _rowRepeatActive)
                                            ? AppColors.gold.withOpacity(.22)
                                            : (dark
                                                ? AppColors.gold.withOpacity(.08)
                                                : AppColors.primaryDark.withOpacity(.05)),
                                        borderRadius: BorderRadius.circular(10),
                                        border: rowRepeatHere
                                            ? Border.all(
                                                color: AppColors.gold,
                                                width: 1.2)
                                            : null),
                                    child: Icon(Icons.repeat_one_rounded,
                                        size: 15,
                                        color: (rowRepeatHere || _rowRepeatActive)
                                            ? AppColors.gold
                                            : (dark
                                                ? AppColors.gold.withOpacity(.75)
                                                : AppColors.primaryDark.withOpacity(.65))),
                                  ),
                                ),
                              ),
                              if (rowRepeatHere) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: AppColors.gold,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Text(
                                      _repeatTotal == -1
                                          ? '∞ دووبارە'
                                          : 'دووبارە '
                                              '${toArabicDigits(_repeatDone)}/'
                                              '${toArabicDigits(_repeatTotal)}',
                                      style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87)),
                                ),
                              ],
                              if (AppPrefs.I.showQuranAyahNumbers) const Spacer(),
                              FavoriteButton(
                                id: 'quran::${widget.surahId}::$ayahNum',
                                title: '${suraLabel(widget.surahName)} • ئایەتی ${toArabicDigits(ayahNum)}',
                                content: '$ayahText\n\n$tafsir',
                                route: 'quran::${widget.surahId}::$ayahNum',
                                color: dark ? AppColors.gold : AppColors.primaryDark),
                              if (AppPrefs.I.showQuranAyahNumbers) Text('${suraLabel(widget.surahName)} • ئایەتی ${toArabicDigits(ayahNum)}',
                                style: TextStyle(fontSize: 10,
                                  color: ayahColor.withOpacity(.55),
                                  fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 8),
                            _ayahText(ayahText, ayahColor),
                            if (AppPrefs.I.showQuranTafsir && tafsir.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: dark
                                        ? Colors.white.withOpacity(.05)
                                        : const Color(0xFFF7F5EF),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(tafsir,
                                    style: TextStyle(
                                        fontSize: 13, height: 1.7,
                                        color: ayahColor.withOpacity(.85))),
                              ),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                // item 1+6: the redesigned repeat strip — a real control
                // with live status and a working stop, not a bare toast.
                _repeatStrip(dark, card, txt),
                AudioPlayerBar(
                  player: _player,
                  dark: dark,
                  card: card,
                  onSeeked: _snapHighlightToSeek,
                  title: _rowRepeatActive
                      ? 'دووبارەکردنەوەی ئایەت — ${AppPrefs.I.qariName}'
                      : _ayahByAyah
                      ? 'ئایەت بە ئایەت — ${AppPrefs.I.qariName}'
                      : 'دەنگی سوورەت — ${AppPrefs.I.qariName}',
                  onPlayPause: _ayahByAyah
                      ? () async {
                          await _player.stop();
                          if (mounted) {
                            setState(() {
                              _ayahByAyah = false;
                              _playingAyah = null;
                              _repeatTotal = 0;
                              _repeatDone = 0;
                            });
                          }
                        }
                      : () {
                          if (_currentUrl != null &&
                              (_state == PlayerState.playing ||
                                  _state == PlayerState.paused)) {
                            // pause/resume the running reciter audio
                            if (_state == PlayerState.playing) {
                              _player.pause();
                            } else {
                              _player.resume();
                            }
                          } else if (_currentUrl != null &&
                              _state == PlayerState.stopped &&
                              _lastPosMs > 3000 &&
                              !_ayahByAyah) {
                            // the audio died mid-surah earlier — continue
                            // from where it stopped, NOT from the start
                            _playSurahLocal(resumeMs: _lastPosMs);
                          } else {
                            _playSurah();
                          }
                        },
                  playing: _state == PlayerState.playing,
                ),
              ]),
      ),
    );
  }
}

String toArabicDigits(int n) {
  if (!AppPrefs.I.useKurdishDigits) return n.toString();
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}
