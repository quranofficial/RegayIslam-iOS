import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart';
import '../../data/db.dart';
import '../../data/downloader.dart';
import 'open_quran.dart' show toArabicDigits;

/// Item 15 — the original editquran.java page rebuilt in Flutter:
/// create a verse IMAGE or a verse VIDEO (frames per ayah + recitation)
/// from any surah/range, save it to the gallery or share it.
class QuranCreatorScreen extends StatefulWidget {
  const QuranCreatorScreen({super.key});
  @override
  State<QuranCreatorScreen> createState() => _QuranCreatorScreenState();
}

class _QuranCreatorScreenState extends State<QuranCreatorScreen> {
  List<Map<String, Object?>> _surahs = [];
  List<Map<String, Object?>> _ayat = [];
  Map<String, Object?>? _surah;
  int _from = 1;
  int _to = 3;
  int _style = 0;
  bool _withAudio = true;
  bool _working = false;
  String _progress = '';

  static const _styles = [
    ('سەوزی چوارچێوەی زێڕین', Color(0xFF1B5E20), Color(0xFF004D40), Color(0xFFFFD54F)),
    ('شەوی ئاسمانی', Color(0xFF0D2137), Color(0xFF0A0F2C), Color(0xFF90CAF9)),
    ('کاغەزی کلاسیک', Color(0xFFF7F1E3), Color(0xFFEADFC8), Color(0xFF5D4037)),
    ('کاتی خۆرئاوابوون', Color(0xFF4A148C), Color(0xFFBF360C), Color(0xFFFFCC80)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final surahs = await Db.I.surahs();
    if (!mounted) return;
    setState(() { _surahs = surahs; _surah = surahs.first; });
    await _loadAyat();
  }

  Future<void> _loadAyat() async {
    final sid = (_surah?['soraid'] as num?)?.toInt() ?? 1;
    final rows = await Db.I.ayat(sid, AppPrefs.I.tafsir);
    if (!mounted) return;
    setState(() {
      _ayat = rows;
      final n = rows.length;
      _from = _from.clamp(1, n);
      _to = (_from + 2).clamp(_from, n);
    });
  }

  String get _name => _surah == null ? '' : '${_surah!['name'] ?? ''}';

  String _reference(int ayah) =>
      '${suraLabel(_name)} • ئایەتی ${toArabicDigits(ayah)}';

  Future<String> _ayahUrl(int ayah) async {
    final g = await Db.I.globalAyah(
        ((_surah?['soraid'] ?? 1) as num).toInt(), ayah);
    return 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$g.mp3';
  }

  // ---- image rendering -------------------------------------------------
  Future<ui.Image> _renderFrame(String text, String ref, {int? index, int? total}) async {
    final style = _styles[_style];
    final recorder = ui.PictureRecorder();
    const size = ui.Size(1080, 1350);
    final canvas = Canvas(recorder, Offset.zero & size);
    final w = size.width, h = size.height;

    final paint = Paint();
    // radial glow + vertical gradient background
    final rect = Offset.zero & size;
    paint.shader = ui.Gradient.linear(
        const Offset(0, 0), Offset(0, h),
        [style.$2, style.$3]);
    canvas.drawRect(rect, paint);
    paint.shader = ui.Gradient.radial(
        Offset(w / 2, h * .38), w * .75,
        [Colors.white.withOpacity(.10), Colors.transparent]);
    canvas.drawRect(rect, paint);
    // decorative frame
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = style.$4.withOpacity(.8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(26), const Radius.circular(28)),
        frame);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(34), const Radius.circular(22)),
        frame..strokeWidth = 1);

    // bismillah header
    final bism = _bismillah(_style);
    final bismPara = _paragraph(bism, 30, style.$4, w - 160, center: true);
    canvas.drawParagraph(bismPara, Offset(80, 80));

    // verse text (wrapped, fitted)
    double fontSize = 52;
    ui.Paragraph para = _paragraph(text, fontSize, Colors.white, w - 150);
    var lines = para.maxIntrinsicWidth > 0 ? para.height : 0.0;
    // shrink until it fits the box
    while (para.height > h * 0.62 && fontSize > 22) {
      fontSize -= 2;
      para = _paragraph(text, fontSize, Colors.white, w - 150);
    }
    lines = para.height;
    final startY = h * .30 + ((h * .58) - lines) / 2;
    canvas.drawParagraph(para, Offset(75, max(startY, h * .24)));

    // reference footer
    final refPara = _paragraph(ref, 26, style.$4, w - 160, center: true);
    canvas.drawParagraph(refPara, Offset(80, h - 170));
    final brand = _paragraph('ڕێگای ئیسلام', 20,
        Colors.white.withOpacity(.75), w - 160, center: true);
    canvas.drawParagraph(brand, Offset(80, h - 110));
    if (total != null && index != null && total > 1) {
      final cnt = _paragraph('${index + 1} / $total', 18,
          Colors.white.withOpacity(.55), w - 160, center: true);
      canvas.drawParagraph(cnt, Offset(80, h - 64));
    }

    final pic = recorder.endRecording();
    return pic.toImage(w.toInt(), h.toInt());
  }

  String _bismillah(int style) =>
      style == 2 ? 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ' : '﷽';

  ui.Paragraph _paragraph(String text, double fontSize, Color color,
      double width, {bool center = false}) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        fontSize: fontSize, fontFamily: 'Quran',
        textAlign: center ? TextAlign.center : TextAlign.right,
        height: 1.9, textDirection: ui.TextDirection.rtl))
      ..pushStyle(ui.TextStyle(color: color, fontSize: fontSize,
          fontFamily: 'Quran'))
      ..addText(text);
    final para = builder.build()..layout(ui.ParagraphConstraints(width: width));
    return para;
  }

  Future<File> _frameToFile(String text, String ref, Directory dir,
      {int? index, int? total}) async {
    final img = await _renderFrame(text, ref, index: index, total: total);
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!
        .buffer.asUint8List();
    final f = File('${dir.path}/frame_${index ?? 0}.png');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  // ---- actions ----------------------------------------------------------
  Future<void> _makeImage() async {
    if (_working || _ayat.isEmpty) return;
    setState(() { _working = true; _progress = 'ئامادەکردنی وێنە...'; });
    try {
      final tmp = await getTemporaryDirectory();
      final frames = <File>[];
      final range = _ayat.where((a) {
        final n = (a['ayah'] as num?)?.toInt() ?? 0;
        return n >= _from && n <= _to;
      }).toList();
      for (var i = 0; i < range.length; i++) {
        final a = range[i];
        final ay = (a['ayah'] as num?)?.toInt() ?? 0;
        setState(() => _progress = 'دروستکردنی وێنە ${i + 1}/${range.length}');
        frames.add(await _frameToFile('${a['text'] ?? ''}',
            _reference(ay), tmp, index: i, total: range.length));
      }
      if (frames.length == 1) {
        final bytes = await frames.first.readAsBytes();
        await Gal.putImageBytes(bytes, album: 'ڕێگای ئیسلام');
        await _done('وێنەکە پاشەکەوت کرا بۆ گەلەری ✅');
      } else {
        await Share.shareXFiles(
            [for (final f in frames) XFile(f.path)],
            text: '${_reference(_from)} — ڕێگای ئیسلام');
        await _done('وێنەکان ئامادەن و بۆ هاوبەشی کردنەوە ✅');
      }
    } catch (e) {
      await _fail(e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _makeVideo() async {
    if (_working || _ayat.isEmpty) return;
    setState(() { _working = true; _progress = 'ئامادەکاری...'; });
    Directory? work;
    try {
      final tmp = await getTemporaryDirectory();
      work = Directory('${tmp.path}/creator_${DateTime.now().millisecondsSinceEpoch}');
      await work.create(recursive: true);
      final range = _ayat.where((a) {
        final n = (a['ayah'] as num?)?.toInt() ?? 0;
        return n >= _from && n <= _to;
      }).toList();
      if (range.isEmpty) throw Exception('no ayat');

      // 1) frames + ayah audio
      final audioFiles = <File>[];
      for (var i = 0; i < range.length; i++) {
        final a = range[i];
        final ay = (a['ayah'] as num?)?.toInt() ?? 0;
        setState(() => _progress = 'ئایەتی ${ay} — وێنە و دەنگ (${i + 1}/${range.length})');
        await _frameToFile('${a['text'] ?? ''}', _reference(ay), work,
            index: i, total: range.length);
        if (!_withAudio) {
          audioFiles.add(File(''));
          continue;
        }
        final url = await _ayahUrl(ay);
        try {
          final f = await Downloader.download(url,
              'creator_cache/ayah_$ay.mp3',
              timeout: const Duration(minutes: 3));
          audioFiles.add(f);
        } catch (_) {
          // no audio for this ayah: still keep the frame visible for 5s
          audioFiles.add(File(''));
        }
      }

      // 2) per-ayah durations via ffprobe
      final durations = <double>[];
      for (final f in audioFiles) {
        if (f.path.isEmpty) {
          durations.add(5.0);
          continue;
        }
        try {
          final info = await FFprobeKit.getMediaInformation(f.path);
          final ms = info.getMediaInformation()?.getDuration();
          final d = double.tryParse('$ms') ?? 5.0;
          durations.add(d <= 0 ? 5.0 : d);
        } catch (_) {
          durations.add(5.0);
        }
      }

      // 3) concat audio (mp3 stream copy where possible)
      setState(() => _progress = 'یەکخستنی دەنگ...');
      final audioOut = '${work.path}/audio.mp3';
      final valid = [
        for (var i = 0; i < audioFiles.length; i++)
          if (audioFiles[i].path.isNotEmpty)
            MapEntry(audioFiles[i], durations[i])
      ];
      if (valid.isNotEmpty) {
        final concatArg = valid.map((e) => e.key.path).join('|');
        final rc = await FFmpegKit.execute(
            '-i "concat:$concatArg" -c copy "$audioOut"');
        if (!ReturnCode.isSuccess(await rc.getReturnCode())) {
          // fallback: re-encode
          final inputs = valid.map((e) => '-i "${e.key.path}"').join(' ');
          await FFmpegKit.execute(
              '$inputs -filter_complex '
              '"${[for (var i = 0; i < valid.length; i++) '[$i:a]'].join()}'
              'concat=n=${valid.length}:v=0:a=1[a]" -map "[a]" "$audioOut"');
        }
      }

      // 4) frames slideshow with per-ayah duration
      setState(() => _progress = 'دروستکردنی ڤیدیۆ...');
      final list = File('${work.path}/list.txt');
      final buf = StringBuffer();
      for (var i = 0; i < range.length; i++) {
        buf.writeln("file 'frame_$i.png'");
        buf.writeln('duration ${durations[i].toStringAsFixed(2)}');
      }
      buf.writeln("file 'frame_${range.length - 1}.png'");
      await list.writeAsString(buf.toString());
      final framesOut = '${work.path}/frames.mp4';
      final rc2 = await FFmpegKit.execute(
          '-f concat -safe 0 -i "${list.path}" -vf "scale=1080:1350" '
          '-vsync vfr -pix_fmt yuv420p "$framesOut"');
      if (!ReturnCode.isSuccess(await rc2.getReturnCode())) {
        throw Exception('frames failed');
      }

      // 5) mux
      final out = '${work.path}/quran_video.mp4';
      if (valid.isNotEmpty) {
        final rc3 = await FFmpegKit.execute(
            '-i "$framesOut" -i "$audioOut" -c:v copy -c:a aac '
            '-shortest -movflags +faststart "$out"');
        if (!ReturnCode.isSuccess(await rc3.getReturnCode())) {
          await FFmpegKit.execute(
              '-i "$framesOut" -c:v libx264 -preset medium -crf 23 '
              '-pix_fmt yuv420p "$out"');
        }
      } else {
        await FFmpegKit.execute(
            '-i "$framesOut" -c:v libx264 -preset medium -crf 23 '
            '-pix_fmt yuv420p "$out"');
      }
      final outBytes = await File(out).length();
      if (outBytes == 0) throw Exception('video empty');
      await Gal.putVideo(out, album: 'ڕێگای ئیسلام');
      await _done('ڤیدیۆکە پاشەکەوت کرا بۆ گەلەری ✅');
    } catch (e) {
      await _fail(e);
    } finally {
      try {
        if (work != null) await work.delete(recursive: true);
      } catch (_) {}
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _done(String msg) async {
    if (!mounted) return;
    setState(() => _progress = '');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _fail(Object e) async {
    if (!mounted) return;
    setState(() => _progress = '');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('سەرکەوتوو نەبوو — ${e.toString().isEmpty ? 'هەڵەیەکی نەزانراو' : 'دووبارە هەوڵبدەرەوە'}')));
  }

  // ---- UI ---------------------------------------------------------------
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
          title: const Text('دروستکردنی ڤیدیۆ و وێنە',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
        body: _surahs.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(14), children: [
                _preview(card, txt, dark),
                const SizedBox(height: 14),
                _pickerRow(dark, txt, card),
                const SizedBox(height: 10),
                _styleRow(dark, txt, card),
                const SizedBox(height: 10),
                SwitchListTile(
                  activeColor: dark ? AppColors.gold : AppColors.primaryDark,
                  contentPadding: EdgeInsets.zero,
                  title: Text('دەنگی ئایەتەکان بۆ ڤیدیۆ (مشاری العفاسي)',
                      style: TextStyle(fontSize: 13.5, color: txt)),
                  subtitle: Text('هەر ئایەتێک بە دەنگی خۆی لە ڤیدیۆدا دەردەکەوێت',
                      style: TextStyle(fontSize: 11.5, color: txt.withOpacity(.55))),
                  value: _withAudio,
                  onChanged: (v) => setState(() => _withAudio = v),
                ),
                if (_working) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_progress,
                        style: TextStyle(fontSize: 12.5, color: txt))),
                  ]),
                ],
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor:
                            dark ? AppColors.gold : AppColors.primaryDark,
                        foregroundColor:
                            dark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: _working ? null : _makeImage,
                    icon: const Icon(Icons.image_rounded),
                    label: const Text('دروستکردنی وێنە'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB71C1C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: _working ? null : _makeVideo,
                    icon: const Icon(Icons.videocam_rounded),
                    label: const Text('دروستکردنی ڤیدیۆ'),
                  )),
                ]),
                const SizedBox(height: 10),
                Text('وێنە و ڤیدیۆکان دەچنە ناو گەلەری مۆبایل (ئەلبوومی ڕێگای ئیسلام). '
                    'دروستکردنی ڤیدیۆ پێویستی بە ئینتەرنێت هەیە بۆ دەنگی ئایەتەکان.',
                    style: TextStyle(fontSize: 11.5, color: txt.withOpacity(.5))),
              ]),
      ),
    );
  }

  Widget _preview(Color card, Color txt, bool dark) {
    final style = _styles[_style];
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [style.$2, style.$3]),
        border: Border.all(color: style.$4.withOpacity(.6), width: 2),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Text(_bismillah(_style),
            style: TextStyle(color: style.$4, fontSize: 16)),
        const Spacer(),
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
              _ayat.isEmpty
                  ? '...'
                  : '${_ayat.where((a) => ((a['ayah'] as num?)?.toInt() ?? 0) == _from).map((a) => '${a['text'] ?? ''}').join()}',
              maxLines: 4, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Quran',
                  color: Colors.white, fontSize: 19, height: 1.9)),
        ),
        const Spacer(),
        Text(_from <= _to ? '${suraLabel(_name)} • ئایەتی ${toArabicDigits(_from)}' : '',
            style: TextStyle(color: style.$4, fontSize: 12)),
        Text('ڕێگای ئیسلام',
            style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 10)),
      ]),
    );
  }

  Widget _pickerRow(bool dark, Color txt, Color card) => Row(children: [
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dark ? Colors.white10 : Colors.black12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Map<String, Object?>>(
              value: _surah,
              isExpanded: true,
              items: [
                for (final s in _surahs)
                  DropdownMenuItem(value: s,
                      child: Text('${s['soraid']}. ${s['name']}',
                          style: TextStyle(fontSize: 12.5, color: txt))),
              ],
              onChanged: (v) async {
                setState(() => _surah = v);
                await _loadAyat();
              },
            ),
          ),
        )),
      ]);

  Widget _styleRow(bool dark, Color txt, Color card) => Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('شێوازی وێنە', style: TextStyle(fontSize: 12.5, color: txt)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (var i = 0; i < _styles.length; i++)
            ChoiceChip(
              label: Text(_styles[i].$1, style: const TextStyle(fontSize: 11.5)),
              selected: _style == i,
              selectedColor: dark ? AppColors.gold.withOpacity(.25) : AppColors.primaryDark.withOpacity(.12),
              labelStyle: TextStyle(
                  color: _style == i
                      ? (dark ? AppColors.gold : AppColors.primaryDark)
                      : txt),
              onSelected: (_) => setState(() => _style = i),
            ),
        ]),
      ]);
}
