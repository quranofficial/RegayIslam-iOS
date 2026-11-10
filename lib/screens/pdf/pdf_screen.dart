import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/downloader.dart';

String _arDigits(int n) {
  if (!AppPrefs.I.useKurdishDigits) return '$n';
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return '$n'.split('').map((c) => d[int.parse(c)]).join();
}

/// Original: PdfActivity — downloads a PDF (with progress) and renders it;
/// downloaded books reopen offline.
///
/// Item 7: the reader remembers WHERE you stopped (per book), reopens at
/// that page automatically, shows "لاپەڕە x / y", lets you jump to any
/// page by number AND keeps a page HISTORY — the last 24 pages you visited
/// are listed so you can go several pages back with one tap. The URL is
/// re-encoded because some ktebakan entries mix raw Kurdish characters
/// with %XX escapes.
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
  PDFViewController? _controller;
  int _pages = 0;
  int _page = 0;
  int _lastReadPage = 0;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _lastReadPage = AppPrefs.I.bookLastPage(widget.url);
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
        Downloader.httpsify(widget.url),
        'ktebakan/${Downloader.safeName(widget.title)}.pdf',
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

  /// Item 7: jump to a page by number.
  Future<void> _askPage() async {
    final c = TextEditingController(text: _page > 0 ? '${_page + 1}' : '');
    final v = await showDialog<int>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('چوونە لاپەڕە'),
          content: TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
                hintText: _pages > 0
                    ? 'لاپەڕە (١ - ${_arDigits(_pages)})'
                    : 'ژمارەی لاپەڕە',
                border: const OutlineInputBorder()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d),
                child: const Text('لابردن')),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(d, int.tryParse(c.text.trim())),
                child: const Text('بڕوان')),
          ],
        ),
      ),
    );
    if (v == null || _pages == 0) return;
    final target = (v - 1).clamp(0, _pages - 1);
    await _goTo(target);
  }

  Future<void> _goTo(int target) async {
    await _controller?.setPage(target);
    setState(() => _page = target);
    AppPrefs.I.setBookLastPage(widget.url, target);
    AppPrefs.I.addBookPageHistory(widget.url, target);
  }

  /// Item 7: page HISTORY — every visited page is remembered per book so
  /// "چەند لاپەڕە بگەڕێوە" is one tap, not one long swipe.
  Future<void> _showHistory() async {
    final pages = AppPrefs.I.bookPageHistory(widget.url);
    if (pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('هێشتا مێژووی لاپەڕە نییە — لاپەڕەکان بگۆڕە'),
          duration: Duration(milliseconds: 1200)));
      return;
    }
    final target = await showDialog<int>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('مێژووی لاپەڕەکان'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('دوا لاپەڕەکانی خوێندنەوە — کلیک بکە بۆ گەڕانەوە',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppPrefs.I.day ? Colors.black54 : Colors.white70)),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in pages)
                          ActionChip(
                              label: Text(
                                  'لاپەڕە ${_arDigits(p + 1)}',
                                  style: const TextStyle(fontSize: 12)),
                              onPressed: () => Navigator.pop(d, p)),
                      ]),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  AppPrefs.I.clearBookPageHistory(widget.url);
                  Navigator.pop(d);
                },
                child: const Text('سڕینەوەی مێژوو',
                    style: TextStyle(color: Colors.red))),
            TextButton(
                onPressed: () => Navigator.pop(d),
                child: const Text('داخستن')),
          ],
        ),
      ),
    );
    if (target != null && _pages > 0) {
      await _goTo(target.clamp(0, _pages - 1));
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
          title: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
            Text(widget.title,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            if (_pages > 0)
              Text('لاپەڕە ${_arDigits(_page + 1)} / ${_arDigits(_pages)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
          actions: [
            if (!_downloading && _localPath != null && _pages > 0)
              IconButton(
                  tooltip: 'مێژووی لاپەڕەکان',
                  onPressed: _showHistory,
                  icon: const Icon(Icons.history_rounded,
                      color: Colors.white)),
            if (!_downloading && _localPath != null && _pages > 0)
              TextButton.icon(
                  onPressed: _askPage,
                  icon: const Icon(Icons.pin_drop_rounded,
                      color: Colors.white, size: 18),
                  label: Text('لاپەڕە ${_arDigits(_page + 1)}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11.5))),
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
                        : Stack(children: [
                            PDFView(
                              filePath: _localPath,
                              enableSwipe: true,
                              swipeHorizontal: false,
                              autoSpacing: true,
                              pageFling: true,
                              // Item 7: reopen exactly where reading stopped.
                              defaultPage:
                                  _lastReadPage > 0 ? _lastReadPage : 0,
                              onViewCreated: (c) async {
                                _controller = c;
                                if (_lastReadPage > 0 && !_restored) {
                                  try {
                                    await c.setPage(_lastReadPage);
                                  } catch (_) {}
                                  _restored = true;
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text(
                                            'لە لاپەڕەی ${_lastReadPage + 1}ەوە بەردەوام بوو — دوا جار ئێرە خوێندرایە'),
                                        duration:
                                            const Duration(milliseconds: 1500)));
                                  }
                                }
                              },
                              onRender: (total) {
                                if (mounted) {
                                  setState(() => _pages = total ?? 0);
                                }
                              },
                              onPageChanged: (page, total) {
                                if (page == null) return;
                                setState(() { _page = page; });
                                // Item 7: remember the reading position AND
                                // the visited page (history).
                                AppPrefs.I.setBookLastPage(widget.url, page);
                                AppPrefs.I.addBookPageHistory(widget.url, page);
                                if (total != null && total > 0 && mounted &&
                                    _pages != total) {
                                  setState(() => _pages = total);
                                }
                              },
                              onError: (e) => setState(
                                  () => _error = 'کردنەوەی فایلەکە سەرکەوتوو نەبوو'),
                            ),
                          ]),
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
