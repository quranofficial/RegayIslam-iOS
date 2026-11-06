import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart';
import '../../data/db.dart';
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
  });

  final int surahId;
  final String surahName;
  final int ayaCount;
  final String place;
  final String juz;

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

  @override
  void initState() {
    super.initState();
    AudioSetup.prepare(_player); // item 2: steady full volume everywhere
    _tafsir = AppPrefs.I.tafsir;
    _load();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _player.onPositionChanged.listen((p) {
      if (!_ayahByAyah) _highlightByTime(p);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      if (_ayahByAyah && _playingAyah != null) {
        final next = _playingAyah! + 1;
        if (next <= widget.ayaCount) {
          _playAyahFile(next);
          return;
        }
      }
      setState(() { _state = PlayerState.stopped; _playingAyah = null; });
    });
  }

  Future<void> _load() async {
    final rows = await Db.I.ayat(widget.surahId, _tafsir);
    if (!mounted) return;
    setState(() { _ayat = rows; _loading = false; });
    _timings = await Db.I.timings(AppPrefs.I.qariId);
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
      return f.existsSync() && f.lengthSync() > 0 ? f : null;
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
        final cached = await _cachedAudio();
        if (cached != null) {
          await _player.play(DeviceFileSource(cached.path));
        } else {
          try {
            await _player.play(UrlSource(url));
          } catch (_) {
            // streaming refused — download then play, like the original
            final file = await Downloader.download(url,
                'quran_audio/${Downloader.safeName(AppPrefs.I.qariId)}_'
                '${widget.surahId.toString().padLeft(3, '0')}.mp3');
            await _player.play(DeviceFileSource(file.path));
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

  /// Item 10: recite from this ayah to the end of the surah, ayah by ayah,
  /// with highlight + auto scroll. Falls back to surah audio + timings.
  Future<void> _playFromAyah(int ayah) async {
    setState(() { _ayahByAyah = true; _playingAyah = ayah; });
    await _playAyahFile(ayah);
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
      setState(() => _playingAyah = cur);
      _scrollToAyah(cur);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Auto-scroll the ayah list to the currently recited ayah (item 20).
  void _scrollToAyah(int ayahNum) {
    if (!_scroll.hasClients) return;
    final itemIndex = _ayat.indexWhere(
        (a) => ((a['ayah'] as num?)?.toInt() ?? 0) == ayahNum);
    if (itemIndex < 0) return;
    const itemExtent = 170.0;
    final target = (itemIndex * itemExtent).clamp(
        0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut);
  }

  void _copyAyah(String ayah, String tafsir) async {
    await copyPage('$ayah\n\n$tafsir');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('کۆپی کرا')));
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
                      return GestureDetector(
                        onTap: () => _copyAyah(ayahText, tafsir),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: highlighted
                                ? (dark ? AppColors.nightCard : const Color(0xFFE8F0FE))
                                : (customBg ?? card),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: highlighted
                                    ? AppColors.primaryDark
                                    : dark ? Colors.white10 : Colors.black12),
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
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(ayahText,
                                  style: TextStyle(
                                      fontFamily: AppPrefs.I.fontQuran,
                                      fontFamilyFallback: const ['Quran', 'Quran1', 'Quran3'],
                                      fontSize: AppPrefs.I.quranFontSize
                                          .toDouble(),
                                      height: 2, color: ayahColor)),
                            ),
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
                AudioPlayerBar(
                  player: _player,
                  dark: dark,
                  card: card,
                  title: _ayahByAyah
                      ? 'ئایەت بە ئایەت — ${AppPrefs.I.qariName}'
                      : 'دەنگی سوورەت — ${AppPrefs.I.qariName}',
                  onPlayPause: _ayahByAyah
                      ? () async {
                          await _player.stop();
                          if (mounted) {
                            setState(() { _ayahByAyah = false; _playingAyah = null; });
                          }
                        }
                      : _playSurah,
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
