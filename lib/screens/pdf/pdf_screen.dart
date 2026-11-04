import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';

/// Original: PdfActivity — downloads a PDF and renders it.
class PdfScreen extends StatefulWidget {
  const PdfScreen({super.key, required this.title, required this.url});
  final String title;
  final String url;
  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  String? _localPath;
  bool _downloading = false;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    setState(() { _downloading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'pdf_cache_${widget.url}';
      final cachedPath = prefs.getString(cacheKey);
      if (cachedPath != null && await File(cachedPath).exists()) {
        if (!mounted) return;
        setState(() { _localPath = cachedPath; _downloading = false; _progress = 100; });
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final name = 'pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$name');
      final client = http.Client();
      final req = http.Request('GET', Uri.parse(widget.url));
      final res = await client.send(req).timeout(const Duration(minutes: 4));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final total = res.contentLength ?? 0;
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in res.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0 && mounted) {
          setState(() => _progress = (received / total * 100).round());
        }
      }
      await sink.close();
      client.close();
      await prefs.setString(cacheKey, file.path);
      if (!mounted) return;
      setState(() { _localPath = file.path; _downloading = false; _progress = 100; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _downloading = false; _error = 'داگرتن سەرکەوتوو نەبوو — دواتر دووبارە هەوڵبدەرەوە'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : Colors.white,
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: Text(widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        body: _downloading
            ? Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(value: _progress > 0 ? _progress / 100 : null),
                const SizedBox(height: 14),
                Text(_progress > 0 ? 'داگرتن... $_progress%' : 'داگرتن...',
                    style: TextStyle(color: dark ? Colors.white70 : Colors.black54)),
              ]))
            : _error != null
                ? Center(child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)))
                : _localPath == null
                    ? const SizedBox()
                    : PDFView(
                        filePath: _localPath,
                        enableSwipe: true,
                        swipeHorizontal: false,
                        autoSpacing: true,
                        pageFling: true,
                        onError: (e) => setState(
                            () => _error = 'کردنەوەی فایلەکە سەرکەوتوو نەبوو'),
                      ),
      ),
    );
  }
}
