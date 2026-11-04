import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import '../../data/favorites.dart';
import 'quran_settings_sheet.dart';

/// Original: OpenquranActivity — ayah list with tafsir, audio playback with
/// ayah highlighting via the reciter timings dbs, and mushaf page mode.
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
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Map<String, int> _timings = {};

  @override
  void initState() {
    super.initState();
    _tafsir = AppPrefs.I.tafsir;
    _load();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
      _highlightByTime(p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _state = PlayerState.stopped; _playingAyah = null; });
    });
  }

  Future<void> _load() async {
    final rows = await Db.I.ayat(widget.surahId, _tafsir);
    if (!mounted) return;
    setState(() { _ayat = rows; _loading = false; });
  }

  String _mp3Url(String link) {
    if (link.startsWith('http')) return link;
    final n = link.replaceAll('.mp3', '').padLeft(3, '0');
    return 'https://download.tvquran.com/download/recitations/343/266/$n.mp3';
  }

  Future<void> _playSurah() async {
    final link = _ayat.isEmpty ? '' : '${_ayat.first['link'] ?? ''}';
    if (link.isEmpty) return;
    final url = _mp3Url(link);
    try {
      if (_currentUrl == url && _state == PlayerState.playing) {
        await _player.pause();
      } else if (_currentUrl == url && _state == PlayerState.paused) {
        await _player.resume();
      } else {
        _timings = await Db.I.timings('${widget.surahId}');
        await _player.play(UrlSource(url));
        setState(() => _currentUrl = url);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('کێشە لە پەخشکردنی دەنگ، تکایە ئینتەرنێت بپشکنە')));
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
    if (cur != null && cur != _playingAyah) setState(() => _playingAyah = cur);
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
        backgroundColor: dark ? AppColors.nightBg : Colors.white,
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('سوڕەتی ${widget.surahName}',
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
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                onPressed: () => Share.share(
                    '${widget.surahName} — ڕێگای ئیسلام')),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
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
                                : card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: highlighted
                                    ? AppColors.primaryDark
                                    : dark ? Colors.white10 : Colors.black12),
                          ),
                          child: Column(crossAxisAlignment:
                              CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: dark
                                        ? AppColors.gold.withOpacity(.15)
                                        : AppColors.primaryDark.withOpacity(.08),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(toArabicDigits(ayahNum),
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: dark ? AppColors.gold : AppColors.primaryDark)),
                              ),
                              const Spacer(),
                              FavoriteButton(
                                id: 'quran::${widget.surahId}::$ayahNum',
                                title: 'سوڕەتی ${widget.surahName} • ئایەتی ${toArabicDigits(ayahNum)}',
                                content: '$ayahText\\n\\n$tafsir',
                                color: dark ? AppColors.gold : AppColors.primaryDark),
                              Text('سوڕەتی ${widget.surahName} • ئایەتی ${toArabicDigits(ayahNum)}',
                                style: TextStyle(fontSize: 10,
                                  color: txt.withOpacity(.55),
                                  fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 8),
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(ayahText,
                                  style: TextStyle(
                                      fontFamily: AppPrefs.I.fontQuran,
                                      fontSize: AppPrefs.I.quranFontSize
                                          .toDouble(),
                                      height: 2, color: txt)),
                            ),
                            if (tafsir.trim().isNotEmpty) ...[
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
                                        color: txt.withOpacity(.85))),
                              ),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                _playerBar(dark, card, txt),
              ]),
      ),
    );
  }

  Widget _playerBar(bool dark, Color card, Color txt) => Container(
        decoration: BoxDecoration(
            color: card,
            border: Border(top: BorderSide(color: dark ? Colors.white10 : Colors.black12))),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(children: [
          IconButton(
              onPressed: _playSurah,
              icon: Icon(_state == PlayerState.playing
                  ? Icons.pause_circle_rounded
                  : Icons.play_circle_rounded,
                  size: 36, color: AppColors.primaryDark)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_state == PlayerState.playing ? 'دەکرێتەوە...' : 'دەنگی سوورەت',
                  style: TextStyle(fontSize: 11, color: txt.withOpacity(.6))),
              LinearProgressIndicator(
                  value: _position.inMilliseconds > 0
                      ? (_position.inMilliseconds /
                          ((_timings['${widget.surahId}:${widget.ayaCount}'] ?? 60000)
                              .toDouble()))
                      : null,
                  minHeight: 3,
                  color: AppColors.primaryDark,
                  backgroundColor: dark ? Colors.white10 : Colors.black12),
            ]),
          ),
        ]),
      );

  void _copyAyah(String ayah, String tafsir) {
    Clipboard.setData(ClipboardData(text: '$ayah\n\n$tafsir\n\n#ڕێگای ئیسلام'));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('کۆپی کرا')));
  }
}

String toArabicDigits(int n) {
  if (!AppPrefs.I.useKurdishDigits) return n.toString();
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}
