import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart';
import '../../data/db.dart';
import '../../data/downloader.dart';
import 'open_quran.dart' show toArabicDigits;

/// Item 13 — ئیدیتی قورئان (the editquran.java page rebuilt properly):
/// create a verse IMAGE or VIDEO from any surah/ayah-range with full control:
///  • ayah range (from → to) and reciter dropdown
///  • ayah text color, size and Quran font
///  • background color, background IMAGE or background VIDEO
///  • animation (none / fade / zoom) for the video
/// Saved straight to the gallery, shareable from there.
class QuranStudioScreen extends StatefulWidget {
  const QuranStudioScreen({super.key});
  @override
  State<QuranStudioScreen> createState() => _QuranStudioScreenState();
}

class _QuranStudioScreenState extends State<QuranStudioScreen> {
  List<Map<String, Object?>> _surahs = [];
  List<Map<String, Object?>> _ayat = [];
  List<Map<String, dynamic>> _reciters = [];
  Map<String, Object?>? _surah;
  Map<String, dynamic>? _reciter;
  int _from = 1;
  int _to = 3;

  // ---- design options ----------------------------------------------------
  int _fontIndex = 0;
  double _textSize = 46;
  int _textColor = 0xFFFFFFFF;
  int _bgColor = 0xFF0D2137;
  String? _bgImagePath;   // picked from gallery
  String? _bgVideoPath;   // picked from gallery (video mode)
  int _animation = 0;     // 0 none, 1 fade, 2 zoom
  bool _withAudio = true; // video recitation
  bool _useReciterAudio = false; // false = per-ayah alafasy, true = selected reciter surah audio

  bool _working = false;
  String _progress = '';

  static const _textColors = [
    0xFFFFFFFF, 0xFF000000, 0xFFFFF3C4, 0xFFFFD54F,
    0xFF80DEEA, 0xFFA5D6A7, 0xFFF8BBD0, 0xFFCE93D8,
  ];
  static const _bgColors = [
    0xFF0D2137, 0xFF1B5E20, 0xFF004D7B, 0xFF4A148C,
    0xFFBF360C, 0xFF212121, 0xFFF7F1E3, 0xFF3E2723,
  ];
  static const _animations = ['بێ ئەنیمەیشن', 'فەید (fade)', 'زووم'];

  @override
  void initState() {
    super.initState();
    // item 13: restore the last saved studio design (font, size, colors,
    // animation) so reopening the section shows the same look.
    final p = AppPrefs.I;
    _fontIndex = p.studioFontIndex.clamp(0, kFontsQuran.length - 1);
    _textSize = p.studioTextSize;
    _textColor = p.studioTextColor;
    _bgColor = p.studioBgColor;
    _animation = p.studioAnimation.clamp(0, _animations.length - 1);
    _load();
  }

  /// Persist the design options whenever one of them changes.
  void _saveDesign() {
    final p = AppPrefs.I;
    p.studioFontIndex = _fontIndex;
    p.studioTextSize = _textSize;
    p.studioTextColor = _textColor;
    p.studioBgColor = _bgColor;
    p.studioAnimation = _animation;
  }

  Future<void> _load() async {
    final surahs = await Db.I.surahs();
    List<Map<String, dynamic>> reciters = [];
    try {
      final raw = await DefaultAssetBundle.of(context)
          .loadString('assets/data/dangakan.json');
      reciters = (jsonDecodeList(raw)).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _surahs = surahs;
      _reciters = reciters;
      _surah = surahs.isNotEmpty ? surahs.first : null;
      _reciter = reciters.isNotEmpty ? reciters.first : null;
    });
    await _loadAyat();
  }

  static List<Map<String, dynamic>> jsonDecodeList(String raw) {
    try {
      final l = const JsonDecoder().convert(raw) as List;
      return l.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadAyat() async {
    final sid = (_surah?['soraid'] as num?)?.toInt() ?? 1;
    final rows = await Db.I.ayat(sid, AppPrefs.I.tafsir);
    if (!mounted) return;
    setState(() {
      _ayat = rows;
      final n = rows.isEmpty ? 1 : rows.length;
      _from = _from.clamp(1, n);
      _to = _to.clamp(_from, n);
    });
  }

  String get _name => _surah == null ? '' : '${_surah!['name'] ?? ''}';

  String _reference(int ayah) =>
      '${suraLabel(_name)} • ئایەتی ${toArabicDigits(ayah)}';

  // ---- frame rendering ---------------------------------------------------
  Future<ui.Image?> _decodeImage(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  Future<ui.Image> _renderFrame(
    String text, String ref, {
    int? index,
    int? total,
    bool transparentBg = false,
    ui.Image? bgImage,
  }) async {
    final recorder = ui.PictureRecorder();
    const size = ui.Size(1080, 1350);
    final canvas = Canvas(recorder, Offset.zero & size);
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final paint = Paint();

    // background: transparent (for bg video overlay), image, or color
    if (transparentBg) {
      // nothing painted — alpha kept for video overlay
    } else if (bgImage != null) {
      final src = Rect.fromLTWH(0, 0,
          bgImage.width.toDouble(), bgImage.height.toDouble());
      // cover-fit
      final scale = (w / bgImage.width).clamp(0.0, double.infinity);
      final scaledH = bgImage.height * scale;
      final dst = scaledH >= h
          ? Rect.fromLTWH(0, (h - scaledH) / 2, w, scaledH)
          : Rect.fromLTWH(0, 0, w, scaledH);
      canvas.drawImageRect(bgImage, src, dst, paint);
      // dark scrim so the text stays readable
      paint.color = Colors.black.withOpacity(.35);
      canvas.drawRect(rect, paint);
    } else {
      paint.shader = ui.Gradient.linear(
          const Offset(0, 0), Offset(0, h),
          [Color(_bgColor), Color(_bgColor).withOpacity(.82)]);
      canvas.drawRect(rect, paint);
      paint.shader = ui.Gradient.radial(
          Offset(w / 2, h * .38), w * .75,
          [Colors.white.withOpacity(.10), Colors.transparent]);
      canvas.drawRect(rect, paint);
    }

    if (!transparentBg) {
      // decorative frame
      final frame = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFD54F).withOpacity(.8);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(26), const Radius.circular(28)),
          frame);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(34), const Radius.circular(22)),
          frame..strokeWidth = 1);
    }

    // bismillah header
    final bismPara = _paragraph(
        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', 30,
        Color(_textColor).withOpacity(.9), w - 160, center: true);
    canvas.drawParagraph(bismPara, Offset(80, 80));

    // verse text (wrapped, fitted)
    double fontSize = _textSize;
    ui.Paragraph para = _paragraph(text, fontSize, Color(_textColor), w - 150);
    while (para.height > h * 0.62 && fontSize > 20) {
      fontSize -= 2;
      para = _paragraph(text, fontSize, Color(_textColor), w - 150);
    }
    final startY = h * .30 + ((h * .58) - para.height) / 2;
    canvas.drawParagraph(para, Offset(75, _refY(startY, h)));

    // reference footer
    final refPara = _paragraph(ref, 26,
        Color(_textColor).withOpacity(.85), w - 160, center: true);
    canvas.drawParagraph(refPara, Offset(80, h - 170));
    final brand = _paragraph('ڕێگای ئیسلام', 20,
        Color(_textColor).withOpacity(.75), w - 160, center: true);
    canvas.drawParagraph(brand, Offset(80, h - 110));
    if (total != null && index != null && total > 1) {
      final cnt = _paragraph('${index + 1} / $total', 18,
          Color(_textColor).withOpacity(.55), w - 160, center: true);
      canvas.drawParagraph(cnt, Offset(80, h - 64));
    }

    final pic = recorder.endRecording();
    return pic.toImage(w.toInt(), h.toInt());
  }

  // keep the verse block vertically centered between header and footer
  double _refY(double startY, double h) => startY.clamp(h * .16, h * .62);

  ui.Paragraph _paragraph(String text, double fontSize, Color color,
      double width, {bool center = false}) {
    final font = kFontsQuran[_fontIndex.clamp(0, kFontsQuran.length - 1)];
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        fontSize: fontSize, fontFamily: font,
        textAlign: center ? TextAlign.center : TextAlign.right,
        height: 1.9, textDirection: ui.TextDirection.rtl))
      ..pushStyle(ui.TextStyle(color: color, fontSize: fontSize,
          fontFamily: font))
      ..addText(text);
    final para = builder.build()..layout(ui.ParagraphConstraints(width: width));
    return para;
  }

  Future<File> _frameToFile(String text, String ref, Directory dir,
      {int? index, int? total, bool transparentBg = false,
       ui.Image? bgImage}) async {
    final img = await _renderFrame(text, ref,
        index: index, total: total,
        transparentBg: transparentBg, bgImage: bgImage);
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!
        .buffer.asUint8List();
    final f = File('${dir.path}/frame_${index ?? 0}.png');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  // ---- image export ------------------------------------------------------
  Future<void> _makeImage() async {
    if (_working || _ayat.isEmpty) return;
    setState(() { _working = true; _progress = 'ئامادەکردنی وێنە...'; });
    try {
      final tmp = await getTemporaryDirectory();
      final work = Directory('${tmp.path}/studio_${DateTime.now().millisecondsSinceEpoch}');
      await work.create(recursive: true);
      final range = _range;
      final bgImage = _bgImagePath != null ? await _decodeImage(_bgImagePath!) : null;
      final frames = <File>[];
      for (var i = 0; i < range.length; i++) {
        final a = range[i];
        final ay = (a['ayah'] as num?)?.toInt() ?? 0;
        setState(() => _progress = 'دروستکردنی وێنە ${i + 1}/${range.length}');
        frames.add(await _frameToFile('${a['text'] ?? ''}', _reference(ay),
            work, index: i, total: range.length, bgImage: bgImage));
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
      try { work.deleteSync(recursive: true); } catch (_) {}
    } catch (e) {
      await _fail(e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  List<Map<String, Object?>> get _range => _ayat.where((a) {
        final n = (a['ayah'] as num?)?.toInt() ?? 0;
        return n >= _from && n <= _to;
      }).toList();

  // ---- video export ------------------------------------------------------
  Future<void> _makeVideo() async {
    if (_working || _ayat.isEmpty) return;
    setState(() { _working = true; _progress = 'ئامادەکاری...'; });
    Directory? work;
    try {
      final tmp = await getTemporaryDirectory();
      work = Directory('${tmp.path}/studio_${DateTime.now().millisecondsSinceEpoch}');
      await work.create(recursive: true);
      final range = _range;
      if (range.isEmpty) throw Exception('no ayat');
      final hasBgVideo = _bgVideoPath != null &&
          _bgVideoPath!.trim().isNotEmpty &&
          File(_bgVideoPath!).existsSync();

      // (1) frames — transparent when a bg video will be overlaid
      final bgImage = _bgImagePath != null && !hasBgVideo
          ? await _decodeImage(_bgImagePath!)
          : null;
      final audioFiles = <File>[];
      final durations = <double>[];

      if (_withAudio && _useReciterAudio && _reciter != null) {
        // Selected reciter, whole surah: one file, duration split by text length.
        final sid = ((_surah?['soraid'] ?? 1) as num).toInt();
        final base = '${_reciter!['url'] ?? ''}'.replaceFirst(
            RegExp(r'^http://', caseSensitive: false), 'https://');
        final n = sid.toString().padLeft(3, '0');
        final url = base.endsWith('/') ? '$base$n.mp3' : '$base/$n.mp3';
        setState(() => _progress = 'داگرتنی دەنگی قاری...');
        try {
          final audio = await Downloader.download(Downloader.httpsify(url),
              'creator_cache/${Downloader.safeName('${_reciter!['id']}')}_$n.mp3');
          final info = await FFprobeKit.getMediaInformation(audio.path);
          final d =
              double.tryParse('${info.getMediaInformation()?.getDuration()}') ?? 0;
          if (d > 0) {
            audioFiles.add(audio);
            final weights = [
              for (final a in range)
                ('${a['text'] ?? ''}'.length).clamp(8, 100000).toDouble()
            ];
            final sum = weights.fold<double>(0, (a, b) => a + b);
            for (final wgt in weights) {
              durations.add(d * wgt / sum);
            }
          }
        } catch (_) {}
      } else if (_withAudio) {
        for (var i = 0; i < range.length; i++) {
          final a = range[i];
          final ay = (a['ayah'] as num?)?.toInt() ?? 0;
          setState(() => _progress =
              'ئایەتی $ay — وێنە و دەنگ (${i + 1}/${range.length})');
          if (!_withAudio) {
            audioFiles.add(File(''));
            continue;
          }
          final g = await Db.I.globalAyah(
              ((_surah?['soraid'] ?? 1) as num).toInt(), ay);
          final url =
              'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$g.mp3';
          try {
            final f = await Downloader.download(url,
                'creator_cache/ayah_$ay.mp3',
                timeout: const Duration(minutes: 3));
            audioFiles.add(f);
          } catch (_) {
            audioFiles.add(File(''));
          }
        }
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
      }

      if (audioFiles.isEmpty) {
        // silent slideshow: equal durations
        for (var i = 0; i < range.length; i++) {
          durations.add(5.0);
        }
      }

      for (var i = 0; i < range.length; i++) {
        final a = range[i];
        final ay = (a['ayah'] as num?)?.toInt() ?? 0;
        if (_withAudio && !_useReciterAudio) {
          setState(() => _progress =
              'ئایەتی $ay — وێنە (${i + 1}/${range.length})');
        }
        await _frameToFile('${a['text'] ?? ''}', _reference(ay), work,
            index: i, total: range.length,
            transparentBg: hasBgVideo, bgImage: bgImage);
      }

      // (2) per-frame segments (with animation) then concat
      setState(() => _progress = 'دروستکردنی ڤیدیۆ...');
      final segments = <String>[];
      for (var i = 0; i < range.length; i++) {
        final d = durations[i].clamp(1.0, 60.0);
        final seg = '${work.path}/seg_$i.mp4';
        final fade = _animation == 1
            ? 'fade=t=in:st=0:d=0.5,fade=t=out:st=${(d - 0.5).toStringAsFixed(2)}:d=0.5,'
            : '';
        final zoom = _animation == 2
            ? 'zoompan=z=\'min(zoom+0.0012,1.12)\':d=${(d * 25).round()}:s=1080x1350:fps=25,'
            : '';
        final alpha = hasBgVideo ? '-c:v png' : '-pix_fmt yuv420p';
        final rc = await FFmpegKit.execute(
            '-loop 1 -i "${work.path}/frame_$i.png" -t ${d.toStringAsFixed(2)} '
            '-vf "${zoom}${fade}scale=1080:1350,fps=25" $alpha "$seg"');
        if (!ReturnCode.isSuccess(await rc.getReturnCode())) {
          throw Exception('segment $i failed');
        }
        segments.add(seg);
      }

      final list = File('${work.path}/list.txt');
      final buf = StringBuffer();
      for (final s in segments) {
        buf.writeln("file '${s.split('/').last}'");
      }
      await list.writeAsString(buf.toString());
      final framesOut = hasBgVideo
          ? '${work.path}/frames.mov'
          : '${work.path}/frames.mp4';
      final rc2 = await FFmpegKit.execute(
          '-f concat -safe 0 -i "${list.path}" -c copy "$framesOut"');
      if (!ReturnCode.isSuccess(await rc2.getReturnCode())) {
        throw Exception('concat failed');
      }

      String out;
      if (hasBgVideo) {
        // (3) overlay the transparent text frames over the looping bg video
        out = '${work.path}/quran_video.mp4';
        final rc3 = await FFmpegKit.execute(
            '-stream_loop -1 -i "${_bgVideoPath!}" -i "$framesOut" '
            '-filter_complex "[0:v]scale=1080:1350:force_original_aspect_ratio=increase,'
            'crop=1080:1350[bg];[bg][1:v]overlay=0:0:shortest=1" '
            '-c:v libx264 -preset medium -crf 23 -pix_fmt yuv420p "$out"');
        if (!ReturnCode.isSuccess(await rc3.getReturnCode())) {
          // fallback: first frame of the bg video as a static background
          final still = '${work.path}/bg_still.png';
          final rcs = await FFmpegKit.execute(
              '-i "${_bgVideoPath!}" -vframes 1 "$still"');
          if (ReturnCode.isSuccess(await rcs.getReturnCode())) {
            final bgImg = await _decodeImage(still);
            final stillWork = work;
            for (var i = 0; i < range.length; i++) {
              await _frameToFile('${range[i]['text'] ?? ''}',
                  _reference(((range[i]['ayah'] as num?)?.toInt() ?? 0)),
                  stillWork, index: i, total: range.length, bgImage: bgImg);
            }
            final list2 = File('${work.path}/list2.txt');
            final b2 = StringBuffer();
            for (var i = 0; i < range.length; i++) {
              b2.writeln("file 'frame_$i.png'");
              b2.writeln('duration ${durations[i].clamp(1.0, 60.0).toStringAsFixed(2)}');
            }
            b2.writeln("file 'frame_${range.length - 1}.png'");
            await list2.writeAsString(b2.toString());
            await FFmpegKit.execute(
                '-f concat -safe 0 -i "${list2.path}" -vf "scale=1080:1350" '
                '-vsync vfr -pix_fmt yuv420p "$out"');
          }
        }
      } else {
        out = framesOut;
      }

      // (4) mux audio if any
      final validAudio = audioFiles.where((f) => f.path.isNotEmpty).toList();
      if (validAudio.isNotEmpty) {
        String audioOut;
        if (_useReciterAudio && validAudio.length == 1) {
          audioOut = validAudio.first.path;
        } else {
          audioOut = '${work.path}/audio.mp3';
          final concatArg = validAudio.map((e) => e.path).join('|');
          final rcA = await FFmpegKit.execute(
              '-i "concat:$concatArg" -c copy "$audioOut"');
          if (!ReturnCode.isSuccess(await rcA.getReturnCode())) {
            final inputs = validAudio.map((e) => '-i "${e.path}"').join(' ');
            await FFmpegKit.execute(
                '$inputs -filter_complex '
                '"${[for (var i = 0; i < validAudio.length; i++) '[$i:a]'].join()}'
                'concat=n=${validAudio.length}:v=0:a=1[a]" -map "[a]" "$audioOut"');
          }
        }
        final outMux = '${work.path}/final.mp4';
        final rcM = await FFmpegKit.execute(
            '-i "$out" -i "$audioOut" -c:v copy -c:a aac -shortest '
            '-movflags +faststart "$outMux"');
        if (ReturnCode.isSuccess(await rcM.getReturnCode())) out = outMux;
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

  Future<void> _pickBgImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    setState(() { _bgImagePath = x.path; _bgVideoPath = null; });
  }

  Future<void> _pickBgVideo() async {
    final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    setState(() { _bgVideoPath = x.path; });
  }

  // ---- UI ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final accent = dark ? AppColors.gold : AppColors.primaryDark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('ئیدیتی قورئان — وێنە و ڤیدیۆ',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
        body: _surahs.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.fromLTRB(
                    14, 14, 14, bottomInset(context, extra: 16)),
                children: [
                // live preview of the current design
                _preview(txt),
                const SizedBox(height: 12),

                // ١ — سوورەت و مەودای ئایەت
                _section(
                  icon: Icons.filter_alt_rounded,
                  title: '١ • سوورەت و مەودای ئایەت',
                  dark: dark,
                  txt: txt,
                  accent: accent,
                  children: [
                    _pickerRow(dark, txt),
                    const SizedBox(height: 12),
                    _rangeRow(dark, txt),
                    const SizedBox(height: 12),
                    _rangeChips(txt, accent),
                  ],
                ),
                const SizedBox(height: 12),

                // ٢ — دەق و فۆنت
                _section(
                  icon: Icons.text_fields_rounded,
                  title: '٢ • دەق و فۆنت',
                  dark: dark,
                  txt: txt,
                  accent: accent,
                  children: [
                    _styleRow(dark, txt),
                    const SizedBox(height: 12),
                    _sizeRow(txt, accent),
                    const SizedBox(height: 12),
                    _fontRow(txt, accent),
                  ],
                ),
                const SizedBox(height: 12),

                // ٣ — پاشبنەما
                _section(
                  icon: Icons.wallpaper_rounded,
                  title: '٣ • پاشبنەما',
                  dark: dark,
                  txt: txt,
                  accent: accent,
                  children: [_bgRow(dark, txt, accent)],
                ),
                const SizedBox(height: 12),

                // ٤ — قاری و دەنگ
                _section(
                  icon: Icons.mic_rounded,
                  title: '٤ • قاری و دەنگ',
                  dark: dark,
                  txt: txt,
                  accent: accent,
                  children: [
                    _reciterRow(dark, txt),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.volume_up_rounded,
                          size: 18, color: txt.withOpacity(.65)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('دەنگ بۆ ڤیدیۆ',
                          style: TextStyle(fontSize: 13, color: txt))),
                      Switch(
                        value: _withAudio,
                        activeColor: accent,
                        onChanged: (v) => setState(() => _withAudio = v),
                      ),
                    ]),
                    if (_withAudio) ...[
                      const SizedBox(height: 8),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                              value: false,
                              label: Text('ئایەت بە ئایەت',
                                  style: TextStyle(fontSize: 11.5))),
                          ButtonSegment(
                              value: true,
                              label: Text('قاری هەڵبژێردراو',
                                  style: TextStyle(fontSize: 11.5))),
                        ],
                        selected: {_useReciterAudio},
                        onSelectionChanged: (s) =>
                            setState(() => _useReciterAudio = s.first),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // ٥ — ئەنیمەیشنی ڤیدیۆ
                _section(
                  icon: Icons.animation_rounded,
                  title: '٥ • ئەنیمەیشنی ڤیدیۆ',
                  dark: dark,
                  txt: txt,
                  accent: accent,
                  children: [
                    Text('ئەنیمەیشن تەنها بۆ ڤیدیۆ جێبەجێ دەکرێت',
                        style: TextStyle(fontSize: 12,
                            color: txt.withOpacity(.65))),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (var i = 0; i < _animations.length; i++)
                        ChoiceChip(
                          label: Text(_animations[i],
                              style: TextStyle(fontSize: 12,
                                  color: _animation == i ? accent : txt)),
                          selected: _animation == i,
                          selectedColor: accent.withOpacity(.18),
                          showCheckmark: false,
                          onSelected: (_) => setState(() {
                            _animation = i;
                            _saveDesign();
                          }),
                        ),
                    ]),
                  ],
                ),

                // progress + action buttons
                if (_working) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: dark
                            ? Colors.white.withOpacity(.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: dark ? Colors.white12 : Colors.black12)),
                    child: Row(children: [
                      const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_progress,
                          style: TextStyle(fontSize: 12.5, color: txt))),
                    ]),
                  ),
                ],
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor:
                              dark ? Colors.black : Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: _working ? null : _makeImage,
                      icon: const Icon(Icons.image_rounded),
                      label: const Text('دروستکردنی وێنە',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB71C1C),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: _working ? null : _makeVideo,
                      icon: const Icon(Icons.videocam_rounded),
                      label: const Text('دروستکردنی ڤیدیۆ',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Text('وێنە و ڤیدیۆکان دەچنە ناو گەلەری مۆبایل (ئەلبوومی ڕێگای ئیسلام). '
                    'دروستکردنی ڤیدیۆ پێویستی بە ئینتەرنێت هەیە بۆ دەنگی ئایەتەکان.',
                    style: TextStyle(fontSize: 11.5,
                        color: txt.withOpacity(.5))),
              ]),
      ),
    );
  }

  /// one rounded controls-group card: header (icon + bold title) + children
  Widget _section({
    required IconData icon,
    required String title,
    required bool dark,
    required Color txt,
    required Color accent,
    required List<Widget> children,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: dark ? AppColors.nightCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dark ? Colors.white10 : Colors.black12),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: accent.withOpacity(.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 14, color: txt)),
              ),
            ]),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );

  /// large live preview: bismillah + first ayah of the range + reference +
  /// brand; a picked background image/video is reflected here
  Widget _preview(Color txt) {
    final text = _ayat.isEmpty
        ? '...'
        : _range.isEmpty
            ? '...'
            : '${_range.first['text'] ?? ''}';
    final hasImage = _bgImagePath != null && _bgVideoPath == null;
    final hasVideo = _bgVideoPath != null;

    final content = Column(children: [
      Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
          style: TextStyle(
              color: Color(_textColor).withOpacity(.9), fontSize: 15)),
      const Spacer(),
      Text(text,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily:
                  kFontsQuran[_fontIndex.clamp(0, kFontsQuran.length - 1)],
              color: Color(_textColor),
              fontSize: _textSize.clamp(14, 30),
              height: 1.9)),
      const Spacer(),
      Text(_from <= _to ? _reference(_from) : '',
          style: TextStyle(
              color: Color(_textColor).withOpacity(.85), fontSize: 12)),
      const SizedBox(height: 2),
      Text('ڕێگای ئیسلام',
          style: TextStyle(
              color: Color(_textColor).withOpacity(.7), fontSize: 10)),
    ]);

    final Widget box;
    if (hasVideo) {
      // dark placeholder with the picked video file name
      box = Container(
        height: 240,
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: AppColors.gold.withOpacity(.6), width: 2)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_rounded,
                size: 36, color: AppColors.gold),
            const SizedBox(height: 8),
            Text('ڤیدیۆی پاشبنەما هەڵبژێردرا ✅',
                style: TextStyle(
                    color: Colors.white.withOpacity(.85), fontSize: 12.5)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(_bgVideoPath!.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(.45), fontSize: 11)),
            ),
          ],
        ),
      );
    } else if (hasImage) {
      // picked image over the color, dark scrim so text stays readable
      box = SizedBox(
        height: 240,
        child: Container(
          foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.gold.withOpacity(.6), width: 2)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(children: [
              Positioned.fill(child: Container(color: Color(_bgColor))),
              Positioned.fill(
                  child: Image.file(File(_bgImagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox())),
              Positioned.fill(
                  child: Container(color: Colors.black.withOpacity(.35))),
              Padding(padding: const EdgeInsets.all(12), child: content),
            ]),
          ),
        ),
      );
    } else {
      // gradient of the picked background color
      box = Container(
        height: 240,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(_bgColor),
                  Color(_bgColor).withOpacity(.82)
                ]),
            border:
                Border.all(color: AppColors.gold.withOpacity(.6), width: 2)),
        padding: const EdgeInsets.all(12),
        child: content,
      );
    }

    return Column(children: [
      box,
      if (hasImage || hasVideo)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36)),
            onPressed: () => setState(() {
              _bgImagePath = null;
              _bgVideoPath = null;
            }),
            child: Text('سڕینەوەی پاشبنەما',
                style:
                    TextStyle(fontSize: 12, color: txt.withOpacity(.65))),
          ),
        ),
    ]);
  }

  /// surah dropdown
  Widget _pickerRow(bool dark, Color txt) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: dark
                ? Colors.white.withOpacity(.05)
                : const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: dark ? Colors.white12 : Colors.black12)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Map<String, Object?>>(
            value: _surah,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: txt.withOpacity(.6)),
            dropdownColor: dark ? AppColors.nightCard : Colors.white,
            items: [
              for (final s in _surahs)
                DropdownMenuItem(
                    value: s,
                    child: Text(
                        '${toArabicDigits((s['soraid'] as num?)?.toInt() ?? 0)}. ${s['name']}',
                        style: TextStyle(fontSize: 12.5, color: txt))),
            ],
            onChanged: (v) async {
              setState(() => _surah = v);
              await _loadAyat();
            },
          ),
        ),
      );

  /// quick range actions: start / end / whole surah + ayah count
  Widget _rangeChips(Color txt, Color accent) {
    final count = _ayat.isEmpty ? 1 : _ayat.length;
    return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ChoiceChip(
            avatar:
                Icon(Icons.first_page_rounded, size: 14, color: accent),
            label:
                Text('سەرەتا', style: TextStyle(fontSize: 11.5, color: txt)),
            selected: false,
            onSelected: (_) => setState(() {
              _from = 1;
              if (_to < _from) _to = _from;
            }),
          ),
          ChoiceChip(
            avatar: Icon(Icons.last_page_rounded, size: 14, color: accent),
            label:
                Text('کۆتایی', style: TextStyle(fontSize: 11.5, color: txt)),
            selected: false,
            onSelected: (_) => setState(() => _to = count),
          ),
          ChoiceChip(
            avatar: Icon(Icons.select_all_rounded, size: 14, color: accent),
            label:
                Text('هەموو', style: TextStyle(fontSize: 11.5, color: txt)),
            selected: false,
            onSelected: (_) => setState(() {
              _from = 1;
              _to = count;
            }),
          ),
          Text('ژمارەی ئایەتەکان: ${toArabicDigits(count)}',
              style:
                  TextStyle(fontSize: 12, color: txt.withOpacity(.65))),
        ]);
  }

  /// from → to steppers (min/max clamps kept)
  Widget _rangeRow(bool dark, Color txt) {
    final count = _ayat.isEmpty ? 1 : _ayat.length;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text('لە ئایەتی',
              style:
                  TextStyle(fontSize: 12.5, color: txt.withOpacity(.8))),
          const SizedBox(height: 6),
          _stepper(dark, txt, _from,
              min: 1,
              max: count,
              onChanged: (v) => setState(() {
                    _from = v;
                    if (_to < _from) _to = _from;
                  })),
        ]),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text('بۆ ئایەتی',
              style:
                  TextStyle(fontSize: 12.5, color: txt.withOpacity(.8))),
          const SizedBox(height: 6),
          _stepper(dark, txt, _to,
              min: _from,
              max: count,
              onChanged: (v) => setState(() => _to = v)),
        ]),
      ),
    ]);
  }

  /// − value + stepper
  Widget _stepper(bool dark, Color txt, int value,
      {required int min,
      required int max,
      required ValueChanged<int> onChanged}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
            color: dark
                ? Colors.white.withOpacity(.05)
                : const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: dark ? Colors.white12 : Colors.black12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: value <= min ? null : () => onChanged(value - 1),
              icon: Icon(Icons.remove_rounded,
                  size: 18,
                  color: dark ? AppColors.gold : AppColors.primaryDark)),
          Text(toArabicDigits(value),
              style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.bold, color: txt)),
          IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: value >= max ? null : () => onChanged(value + 1),
              icon: Icon(Icons.add_rounded,
                  size: 18,
                  color: dark ? AppColors.gold : AppColors.primaryDark)),
        ]),
      );

  /// round color swatch with a gold ring when selected
  Widget _colorDot(Color color,
          {required bool dark,
          required bool selected,
          required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected
                      ? AppColors.gold
                      : (dark ? Colors.white24 : Colors.black26),
                  width: selected ? 3 : 1)),
        ),
      );

  /// ayah text color dots
  Widget _styleRow(bool dark, Color txt) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ڕەنگی دەقی ئایەت',
              style:
                  TextStyle(fontSize: 12, color: txt.withOpacity(.65))),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final c in _textColors)
              _colorDot(Color(c),
                  dark: dark,
                  selected: _textColor == c,
                  onTap: () => setState(() {
                        _textColor = c;
                        _saveDesign();
                      })),
          ]),
        ],
      );

  /// ayah text size slider (22..72), value shown in Arabic digits
  Widget _sizeRow(Color txt, Color accent) => Row(children: [
        Icon(Icons.text_decrease_rounded,
            size: 18, color: txt.withOpacity(.6)),
        Expanded(
          child: Slider(
            min: 22,
            max: 72,
            divisions: 25,
            value: _textSize.clamp(22, 72),
            label: toArabicDigits(_textSize.round()),
            activeColor: accent,
            onChanged: (v) {
              setState(() => _textSize = v);
              _saveDesign();
            },
          ),
        ),
        Icon(Icons.text_increase_rounded,
            size: 18, color: txt.withOpacity(.6)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: accent.withOpacity(.12),
              borderRadius: BorderRadius.circular(10)),
          child: Text(toArabicDigits(_textSize.round()),
              style: TextStyle(fontSize: 12.5,
                  fontWeight: FontWeight.bold, color: accent)),
        ),
      ]);

  /// Quran font chips (each label rendered in its own font)
  Widget _fontRow(Color txt, Color accent) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < kFontsQuran.length; i++)
            ChoiceChip(
              label: Text(kFontsQuran[i],
                  style: TextStyle(
                      fontFamily: kFontsQuran[i],
                      fontSize: 12,
                      color: _fontIndex == i ? accent : txt,
                      fontWeight: _fontIndex == i
                          ? FontWeight.bold
                          : FontWeight.normal)),
              selected: _fontIndex == i,
              selectedColor: accent.withOpacity(.18),
              showCheckmark: false,
              onSelected: (_) => setState(() {
                _fontIndex = i;
                _saveDesign();
              }),
            ),
        ],
      );

  /// background color dots + image/video pick buttons
  Widget _bgRow(bool dark, Color txt, Color accent) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ڕەنگی پاشبنەما',
              style:
                  TextStyle(fontSize: 12, color: txt.withOpacity(.65))),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final c in _bgColors)
              _colorDot(Color(c),
                  dark: dark,
                  selected: _bgColor == c &&
                      _bgImagePath == null &&
                      _bgVideoPath == null,
                  onTap: () => setState(() {
                        _bgColor = c;
                        _bgImagePath = null;
                        _bgVideoPath = null;
                        _saveDesign();
                      })),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: dark ? Colors.white24 : Colors.black26),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10)),
                onPressed: _pickBgImage,
                icon: Icon(Icons.image_rounded,
                    size: 18,
                    color: _bgImagePath != null
                        ? AppColors.gold
                        : txt.withOpacity(.7)),
                label: Text(
                    _bgImagePath == null
                        ? 'وێنەی پاشبنەما'
                        : 'وێنە هەڵبژێردرا ✅',
                    style: TextStyle(fontSize: 11.5, color: txt)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: dark ? Colors.white24 : Colors.black26),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10)),
                onPressed: _pickBgVideo,
                icon: Icon(Icons.videocam_rounded,
                    size: 18,
                    color: _bgVideoPath != null
                        ? AppColors.gold
                        : txt.withOpacity(.7)),
                label: Text(
                    _bgVideoPath == null
                        ? 'ڤیدیۆی پاشبنەما'
                        : 'ڤیدیۆ هەڵبژێردرا ✅',
                    style: TextStyle(fontSize: 11.5, color: txt)),
              ),
            ),
          ]),
        ],
      );

  /// reciter dropdown for the video audio
  Widget _reciterRow(bool dark, Color txt) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: dark
                ? Colors.white.withOpacity(.05)
                : const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: dark ? Colors.white12 : Colors.black12)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Map<String, dynamic>>(
            value: _reciter,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: txt.withOpacity(.6)),
            dropdownColor: dark ? AppColors.nightCard : Colors.white,
            hint: Text('قاری بۆ دەنگی ڤیدیۆ',
                style: TextStyle(fontSize: 12.5,
                    color: txt.withOpacity(.65))),
            items: [
              for (final r in _reciters)
                DropdownMenuItem(
                    value: r,
                    child: Text('${r['name_ar'] ?? ''}'.trim(),
                        style: TextStyle(fontSize: 12.5, color: txt))),
            ],
            onChanged: (v) => setState(() => _reciter = v),
          ),
        ),
      );
}
