import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Shared download helper — the original app downloaded every sound/PDF
/// before playing (PRDownloader), which survives flaky streaming stacks.
/// Everything lands under the app documents dir and is replayed offline.
class Downloader {
  Downloader._();

  static String httpsify(String url) =>
      url.startsWith('http://') && !url.startsWith('https://')
          ? url.replaceFirst('http://', 'https://')
          : url;

  static String safeName(String raw) =>
      raw.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  /// Downloads [url] into documents/<relPath>; returns the local file.
  static Future<File> download(
    String url,
    String relPath, {
    void Function(int received, int total)? onProgress,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$relPath');
    await file.parent.create(recursive: true);
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(httpsify(url)));
      final res = await client.send(req).timeout(timeout);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in res.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (onProgress != null && total > 0) onProgress(received, total);
      }
      await sink.close();
      if (await file.length() == 0) throw Exception('empty file');
      return file;
    } catch (_) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }
  }
}
