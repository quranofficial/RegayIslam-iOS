import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/downloader.dart';

/// Original: PdfActivity — downloads a PDF (with progress) and renders it;
/// downloaded books reopen offline. The URL is re-encoded because some
/// ktebakan entries mix raw Kurdish characters with %XX escapes.
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
    _load();
  }

  Future<void> _load() async {
    setState(() { _downloading = true; _error = null; _progress = 0; });
    try {
      // 1) cached from a previous download (or from the library screen)
      final cached = AppPrefs.I.pdfCachePath(widget.url);
      if (cached != null && cached.isNotEmpty && await File(cached).exists()) {
        if (!mounted) return;
        setState(() { _localPath = cached; _downloading = false; _progress = 100; });
        return;
      }
      // 2) download with progress, like PRDownloader in the original
      final file = await Downloader.download(
        widget.url, 'ktebakan/${Downloader.safeName(widget.title)}.pdf',
        onProgress: (received, total) {
          if (mounted) {
            setState(() => _progress = (received / total * 100).round());
          }
        });
      AppPrefs.I.setPdfCachePath(widget.url, file.path);
      if (!mounted) return;
      setState(() { _localPath = file.path; _downloading = false; _progress = 100; });
    } catch (_) {
      // maybe a stale cache entry pointing to a deleted file
      AppPrefs.I.setPdfCachePath(widget.url, '');
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = 'داگرتن سەرکەوتوو نەبوو — تکایە پەیوەندی ئینتەرنێت بپشکنە';
      });
    }
  }

  Future<void> _openExternally() async {
    // flutter_pdfview is Android-only; on iOS hand the file to the system.
    final path = _localPath;
    if (path == null) return;
    try {
      if (Platform.isIOS) {
        await Share.shareXFiles([XFile(path)], text: widget.title);
      } else {
        await launchUrl(Uri.file(path), mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
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
          actions: [
            if (!_downloading && _localPath == null)
              IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
            if (_localPath != null)
              IconButton(
                  tooltip: 'کردنەوە بە ئەپی تر',
                  onPressed: _openExternally,
                  icon: const Icon(Icons.open_in_new_rounded,
                      color: Colors.white)),
          ],
        ),
        body: _downloading
            ? Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(
                    value: _progress > 0 ? _progress / 100 : null),
                const SizedBox(height: 14),
                Text(_progress > 0 ? 'داگرتن... $_progress%' : 'داگرتن...',
                    style: TextStyle(color: dark ? Colors.white70 : Colors.black54)),
              ]))
            : _error != null
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.cloud_off_rounded, size: 44,
                        color: Colors.red.withOpacity(.7)),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('دووبارە هەوڵبدەرەوە')),
                  ]))
                : _localPath == null
                    ? const SizedBox()
                    : Platform.isIOS
                        ? _iosNotice()
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

  Widget _iosNotice() {
    final dark = !AppPrefs.I.day;
    return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.picture_as_pdf_rounded, size: 44,
            color: dark ? Colors.white70 : AppColors.primaryDark),
        const SizedBox(height: 12),
        Text('کتێبەکە دابگیرا. بۆ کردنەوەی لە ئایفۆن دوگمەی "کردنەوە بە ئەپی تر" لە سەرەوە بەکاربهێنە.',
            textAlign: TextAlign.center,
            style: TextStyle(color: dark ? Colors.white70 : Colors.black54)),
      ]));
  }
}
