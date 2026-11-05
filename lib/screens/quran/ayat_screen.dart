import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import '../../data/downloader.dart';
import '../../data/favorites.dart';
import 'open_quran.dart' show toArabicDigits;

/// Original: AyatActivity — daily ayah with recitation, zoom, copy & share.
class AyatScreen extends StatefulWidget {
  const AyatScreen({super.key});
  @override
  State<AyatScreen> createState() => _AyatScreenState();
}

class _AyatScreenState extends State<AyatScreen> {
  Map<String, Object?>? _row;
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  double _zoom = 24;

  @override
  void initState() {
    super.initState();
    _load();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
  }

  Future<void> _load() async {
    // Deterministic "ayah of the day": day-of-year drives the pick.
    final day = DateTime.now().difference(DateTime(2024)).inDays;
    final sura = Random(day).nextInt(114) + 1;
    final ayat = await Db.I.ayat(sura, AppPrefs.I.tafsir);
    if (ayat.isEmpty || !mounted) return;
    final a = ayat[Random(day).nextInt(ayat.length)];
    setState(() => _row = a);
  }

  String _audioUrl(Map<String, Object?> row) {
    final link = row['link']?.toString().trim() ?? '';
    if (link.isEmpty) throw const FormatException('Ayah audio link is empty');
    if (link.startsWith('https://') || link.startsWith('http://')) {
      return link.replaceFirst(RegExp(r'^http://', caseSensitive: false), 'https://');
    }
    final file = link.toLowerCase().endsWith('.mp3') ? link : link + '.mp3';
    final number = file.replaceAll('.mp3', '').padLeft(3, '0');
    final base = AppPrefs.I.qariUrl;
    return base.endsWith('/') ? '$base$number.mp3' : '$base/$number.mp3';
  }

  Future<void> _play() async {
    final link = '${_row?['link'] ?? ''}';
    if (link.isEmpty) return;
    try {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.stop();
        final url = Downloader.httpsify(_audioUrl(_row!));
        try {
          await _player.play(UrlSource(url));
        } catch (_) {
          // streaming refused — download then play
          final file = await Downloader.download(
              url, 'ayat/${Downloader.safeName(link)}',
              timeout: const Duration(minutes: 3));
          await _player.play(DeviceFileSource(file.path));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('کێشە لە پەخشکردنی دەنگ')));
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
    final r = _row;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFF004D7B),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('ئایەتی ڕۆژ',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ),
        body: r == null
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color: dark ? AppColors.nightCard : Colors.white,
                        borderRadius: BorderRadius.circular(18)),
                    child: Column(children: [
                      Row(children: [
                        Text(AppPrefs.I.showQuranSurahName
                          ? 'سوڕەتی ${r['sura_name_ar']} • ئایەتی ${toArabicDigits((r['ayah'] as num?)?.toInt() ?? 0)}'
                          : 'ئایەتی ${toArabicDigits((r['ayah'] as num?)?.toInt() ?? 0)}',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark)),
                        const Spacer(),
                        FavoriteButton(
                          id: 'daily_ayah::${r['suraId']}::${r['ayah']}',
                          title: '${r['sura_name_ar']} • ئایەتی ${toArabicDigits((r['ayah'] as num?)?.toInt() ?? 0)}',
                          content: '${r['text']}\\n\\n${r[AppPrefs.I.tafsir] ?? ''}',
                          color: dark ? AppColors.gold : AppColors.primaryDark),
                        Text('ڕێگای ئیسلام',
                            style: TextStyle(
                                fontSize: 11, color: txt.withOpacity(.4))),
                      ]),
                      const Divider(height: 22),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text('${r['text']}',
                            style: TextStyle(
                                fontFamily: AppPrefs.I.fontQuran,
                                fontFamilyFallback: const ['Quran', 'Quran1', 'Quran3'],
                                fontSize: _zoom, height: 2.1, color: txt)),
                      ),
                      const SizedBox(height: 14),
                      if (AppPrefs.I.showQuranTafsir) Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: dark
                                ? Colors.white.withOpacity(.05)
                                : const Color(0xFFF7F5EF),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('${r[AppPrefs.I.tafsir] ?? ''}',
                            style: TextStyle(
                                fontSize: 14, height: 1.8,
                                color: txt.withOpacity(.85))),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _btn(Icons.copy_rounded, 'کۆپی', () {
                      Clipboard.setData(ClipboardData(
                          text: '${r['text']}\n\n${r[AppPrefs.I.tafsir] ?? ''}\n\n#ڕێگای ئیسلام'));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('کۆپی کرا')));
                    }),
                    _btn(Icons.share_rounded, 'هاوبەشی', () => Share.share(
                        '${r['text']}\n\n${r[AppPrefs.I.tafsir] ?? ''}\n\n#ڕێگای ئیسلام')),
                    _btn(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        'دەنگ', _play),
                  ]),
                ]),
              ),
        bottomNavigationBar: SafeArea(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                onPressed: () =>
                    setState(() => _zoom = (_zoom - 2).clamp(14, 60)),
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    color: Colors.white70)),
            Text('قەبارەی نووسین: ${_zoom.round()}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            IconButton(
                onPressed: () =>
                    setState(() => _zoom = (_zoom + 2).clamp(14, 60)),
                icon: const Icon(Icons.add_circle_outline_rounded,
                    color: Colors.white70)),
          ]),
        ),
      ),
    );
  }

  Widget _btn(IconData i, String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          InkResponse(
              onTap: onTap,
              child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Icon(i, color: AppColors.primaryDark))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );
}
