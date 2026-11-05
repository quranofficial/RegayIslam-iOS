import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart';
import '../../data/db.dart';
import '../../data/downloader.dart';
import '../../data/favorites.dart';
import 'open_quran.dart' show toArabicDigits;

/// Dedicated Ayat al-Kursi reader (Al-Baqarah 2:255) with recitation
/// (item 16): per-ayah audio from cdn.islamic.network with an offline copy.
class AyatulKursiScreen extends StatefulWidget {
  const AyatulKursiScreen({super.key});
  @override
  State<AyatulKursiScreen> createState() => _AyatulKursiScreenState();
}

class _AyatulKursiScreenState extends State<AyatulKursiScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _busy = false;
  File? _local;

  static const String _cdnUrl =
      'https://cdn.islamic.network/quran/audio/128/ar.alafasy/262.mp3';

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _findLocal();
  }

  Future<void> _findLocal() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/kursi/002_255.mp3');
      if (mounted) setState(() => _local = f.existsSync() ? f : null);
    } catch (_) {}
  }

  Future<void> _play() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _player.stop();
      if (_local != null) {
        await _player.play(DeviceFileSource(_local!.path));
      } else {
        try {
          await _player.play(UrlSource(_cdnUrl));
        } catch (_) {
          final f = await Downloader.download(_cdnUrl, 'kursi/002_255.mp3');
          await _player.play(DeviceFileSource(f.path));
          if (mounted) setState(() => _local = f);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('کێشە لە پەخشکردنی دەنگ — ئینتەرنێت بپشکنە')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    if (_local != null || _busy) return;
    setState(() => _busy = true);
    try {
      final f = await Downloader.download(_cdnUrl, 'kursi/002_255.mp3');
      if (mounted) {
        setState(() => _local = f);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('دەنگی ئایەتی کورسی بۆ ئۆفلاین داگیرا ✅')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('داگرتن سەرکەوتوو نەبوو')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
          title: const Text('ئایەتی کورسی',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        bottomNavigationBar: AudioPlayerBar(
          player: _player,
          dark: dark,
          title: 'دەنگی ئایەتی کورسی — مشاری العفاسي',
          onPlayPause: _play,
          playing: _playing,
        ),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: Db.I.ayat(2, AppPrefs.I.tafsir),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return Center(child: Text('خوێندنەوەی ئایەتەکە سەرکەوتوو نەبوو',
                  style: TextStyle(color: txt)));
            }
            final rows = snap.data!
                .where((r) => (r['ayah'] as num?)?.toInt() == 255)
                .toList();
            if (rows.isEmpty) {
              return Center(child: Text('ئایەتی کورسی لە داتابەیسدا نەدۆزرایەوە',
                  style: TextStyle(color: txt)));
            }
            final row = rows.first;
            final arabic = '${row['text'] ?? ''}';
            final tafsir = '${row[AppPrefs.I.tafsir] ?? ''}';
            return ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: dark ? AppColors.nightCard : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: dark ? Colors.white12 : Colors.black12),
                ),
                child: Column(children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.gold, size: 34),
                  const SizedBox(height: 8),
                  FavoriteButton(id: 'quran::2::255',
                    title: 'سوورەتی البقرة • ئایەتی ${toArabicDigits(255)}',
                    content: arabic),
                  Text('سوورەتی البقرة • ئایەتی ${toArabicDigits(255)}',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 15, color: txt)),
                  const SizedBox(height: 18),
                  SelectableText(arabic,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: AppPrefs.I.fontQuran,
                      fontFamilyFallback: const ['Quran', 'Quran1', 'Quran3'],
                      fontSize: AppPrefs.I.quranFontSize.toDouble(),
                      height: 2.1, color: txt)),
                  if (tafsir.trim().isNotEmpty) ...[
                    const Divider(height: 28),
                    Align(alignment: Alignment.centerRight,
                      child: Text('تەفسیر',
                        style: TextStyle(fontWeight: FontWeight.bold,
                          color: dark ? AppColors.gold : AppColors.primaryDark))),
                    const SizedBox(height: 8),
                    SelectableText(tafsir,
                      style: TextStyle(fontSize: 15, height: 1.9, color: txt)),
                  ],
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8,
                      alignment: WrapAlignment.center, children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await copyPage(
                            'ئایەتی کورسی — البقرة ٢٥٥\n\n$arabic\n\n$tafsir');
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ئایەتەکە کۆپی کرا')));
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('کۆپی ئایەت'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => sharePage('$arabic\n\n$tafsir',
                          title: 'ئایەتی کورسی'),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('هاوبەشی'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _local == null ? _download : null,
                      icon: Icon(_local != null
                          ? Icons.download_done_rounded
                          : (_busy
                              ? Icons.downloading_rounded
                              : Icons.download_rounded)),
                      label: Text(_local != null
                          ? 'داگیراوە بۆ ئۆفلاین'
                          : 'داگرتنی دەنگ'),
                    ),
                  ]),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
