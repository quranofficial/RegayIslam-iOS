import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'db_factory_stub.dart'
    if (dart.library.html) 'db_factory_web.dart' as platform_db;

/// Port of MydbClass.java — copies the bundled SQLite databases from assets
/// to the app documents directory on first run and exposes typed queries.
class Db {
  Db._();
  static final Db I = Db._();

  Database? _quran; // regayislam.db  (ayah_text: text + rebar tafsir)
  Database? _surat; // surat.db       (114 surah metadata)
  Database? _times; // time2.db       (prayer times per city table)
  Database? _names; // name.db        (99 names of Allah)
  Database? _mu; // mu.db           (aqidah book: babat/sarki)
  Database? _rm; // rm.db           (ramadan content)
  Database? _duha; // duha.db        (du3a list)
  Database? _garanawa; // garanawa.db (books chapters)
  Database? _ramazanew; // ramazanew.db
  Database? _info; // ayah_info.db   (mushaf glyph layout: ayah -> page)

  Future<String> _databasePath(String file) async {
    // Browser SQLite stores its virtual files in IndexedDB, so it uses a
    // stable logical filename rather than a device filesystem path.
    if (kIsWeb) return file;
    return join(await getDatabasesPath(), file);
  }

  Future<Database> _open(String file) async {
    final path = await _databasePath(file);
    if (!await databaseFactory.databaseExists(path)) {
      final data = await rootBundle.load('assets/db/$file');
      final bytes = data.buffer.asUint8List(
          data.offsetInBytes, data.lengthInBytes);
      await databaseFactory.writeDatabaseBytes(path, bytes);
    }
    return databaseFactory.openDatabase(
      path,
      options: const OpenDatabaseOptions(readOnly: true),
    );
  }

  Future<void> init() async {
    platform_db.configureDatabaseFactory();
    _quran = await _open('regayislam.db');
    _surat = await _open('surat.db');
    _times = await _open('time2.db');
    _names = await _open('name.db');
    _mu = await _open('mu.db');
    _rm = await _open('rm.db');
    _duha = await _open('duha.db');
    _garanawa = await _open('garanawa.db');
    _ramazanew = await _open('ramazanew.db');
    _info = await _open('ayah_info.db');
  }

  /// 114 surah rows: soraid, name, aya, place, juz, link
  Future<List<Map<String, Object?>>> surahs() async =>
      _surat!.query('surat', orderBy: 'soraid');

  /// All ayat of one surah with the selected tafsir column.
  Future<List<Map<String, Object?>>> ayat(int suraId, String tafsirCol) async {
    final safe = _safeCol(tafsirCol);
    return _quran!.query('ayah_text',
        where: 'suraId = ?', whereArgs: [suraId],
        columns: ['suraId', 'ayah', 'page', 'link', 'sura_name_ar', 'text', safe],
        orderBy: 'ayah');
  }

  /// Full-quran search over text and tafsir.
  Future<List<Map<String, Object?>>> searchQuran(String q, String tafsirCol) async {
    final safe = _safeCol(tafsirCol);
    return _quran!.query('ayah_text',
        where: 'text LIKE ? OR $safe LIKE ?',
        whereArgs: ['%$q%', '%$q%'],
        limit: 100,
        orderBy: 'suraId, ayah');
  }

  /// Whole-surah tafsir text (Fate7a detail screens).
  Future<String> surahTafsir(int suraId, String tafsirCol) async {
    final rows = await _quran!.query('ayah_text',
        where: 'suraId = ?', whereArgs: [suraId],
        columns: [_safeCol(tafsirCol)], orderBy: 'ayah');
    final sb = StringBuffer();
    for (final r in rows) {
      final v = r[tafsirCol];
      if (v != null && v.toString().trim().isNotEmpty) {
        sb.writeln(v); sb.writeln();
      }
    }
    return sb.toString();
  }

  String _safeCol(String c) {
    const allowed = [
      'text', 'rebar', 'raman', 'roshn', 'sanahi', 'hazhar', 'tawhid',
      'asan', 'maiser', 'zhin', 'puxta'
    ];
    return allowed.contains(c) ? c : 'rebar';
  }

  /// Recitation timings db for a reciter id (assets/db/<id>.db).
  Future<Map<String, int>> timings(String reciterId) async {
    final f = '${reciterId.replaceAll(RegExp(r'[^0-9]'), '')}.db';
    final path = await _databasePath(f);
    try {
      if (!await databaseFactory.databaseExists(path)) {
        final data = await rootBundle.load('assets/db/$f');
        final bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await databaseFactory.writeDatabaseBytes(path, bytes);
      }
      final db = await databaseFactory.openDatabase(
        path,
        options: const OpenDatabaseOptions(readOnly: true),
      );
      final rows = await db.query('timings');
      final out = <String, int>{};
      for (final r in rows) {
        out['${r['sura']}:${r['ayah']}'] = (r['time'] as num?)?.toInt() ?? 0;
      }
      await db.close();
      return out;
    } catch (_) {
      return {};
    }
  }

  /// Prayer times for one day "MM-dd" from the city table.
  Future<Map<String, String>?> prayerTimes(String cityId, DateTime d) async {
    final key = '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final rows = await _times!.query(cityId, where: 'D = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  /// Prayer times for a whole month, for PrayersmonthActivity.
  Future<List<Map<String, Object?>>> prayerMonth(String cityId, int month) async {
    final key = '${month.toString().padLeft(2, '0')}-%';
    return _times!.query(cityId, where: 'D LIKE ?', whereArgs: [key], orderBy: 'D');
  }

  /// City tables of time2.db translated to Kurdish Sorani through
  /// cityme.json ("item 10: ناوە شارەکان بە کوردی سۆرانی").
  Future<List<Map<String, Object?>>> cities() async {
    final tables = await _times!.query('sqlite_master',
        where: "type='table' AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'");
    final ids = tables
        .map((t) => '${t['name'] ?? ''}')
        .where((n) => n.isNotEmpty)
        .toList();
    Map<String, String> names = {};
    try {
      final raw = await rootBundle.loadString('assets/data/cityme.json');
      final list = jsonDecode(raw) as List;
      names = {
        for (final e in list)
          '${e['id'] ?? ''}': '${e['Name'] ?? ''}',
      };
    } catch (_) {}
    // Item 15: the city list is ALWAYS shown with its Kurdish name from
    // cityme.json and sorted by that name (no raw English ids anywhere).
    final out = [
      for (final id in ids) {'id': id, 'name': names[id] ?? id},
    ]..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
    return out;
  }

  /// Mushaf page number containing an ayah (ayah_info.db line layout).
  Future<int?> ayahPage(int surahId, int ayah) async {
    try {
      final rows = await _info!.query('page_data_line',
          where: 'surah_id = ? AND verse_id = ?',
          whereArgs: [surahId, ayah],
          columns: ['page_number'],
          limit: 1);
      if (rows.isEmpty) return null;
      return (rows.first['page_number'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  /// Which surahs appear on a mushaf page (for the page header chips).
  /// Returns rows {soraid, name, firstAyah} ordered by surah id.
  Future<List<Map<String, Object?>>> pageSurahs(int page) async {
    try {
      final lines = await _info!.rawQuery(
          'SELECT surah_id, MIN(verse_id) AS firstAyah FROM page_data_line '
          'WHERE page_number = ? GROUP BY surah_id ORDER BY surah_id',
          [page]);
      if (lines.isEmpty) return [];
      final sRows = await surahs();
      final out = <Map<String, Object?>>[];
      for (final l in lines) {
        final sid = (l['surah_id'] as num?)?.toInt() ?? 0;
        final first = (l['firstAyah'] as num?)?.toInt() ?? 1;
        final s = sRows
            .where((r) => (r['soraid'] as num?)?.toInt() == sid)
            .toList();
        out.add({
          'soraid': sid,
          'name': s.isNotEmpty ? '${s.first['name'] ?? ''}' : '',
          'firstAyah': first,
        });
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Item 22: the line boxes of one mushaf page (ayah_info.db). Every row
  /// is one line segment of one verse with its bounding box in the 1246 ×
  /// 2031 mushaf coordinate space — used to hit-test taps ("دەست لە ئایەت
  /// بدە، هەڵی ببژێرە و لێی بدە") and to draw the recitation highlight.
  Future<List<Map<String, Object?>>> pageAyahLines(int page) async {
    try {
      return await _info!.query('page_data_line',
          where: 'page_number = ?',
          whereArgs: [page],
          columns: ['surah_id', 'verse_id', 'min_x', 'max_x', 'min_y', 'max_y'],
          orderBy: 'line_number, min_x');
    } catch (_) {
      return [];
    }
  }

  /// Global ayah index (1..6236) — needed by the cdn.islamic.network
  /// per-ayah audio endpoint used by the ayah player and creator.
  Future<int> globalAyah(int surahId, int ayah) async {
    final rows = await _surat!.query('surat',
        columns: ['soraid', 'aya'], orderBy: 'soraid');
    var cum = 0;
    for (final r in rows) {
      final sid = (r['soraid'] as num?)?.toInt() ?? 0;
      final count = (r['aya'] as num?)?.toInt() ?? 0;
      if (sid == surahId) return cum + ayah;
      cum += count;
    }
    return cum + ayah;
  }

  /// 99 names of Allah.
  Future<List<Map<String, Object?>>> names() async =>
      _names!.query('name', orderBy: '_id');

  /// Aqidah book chapters.
  Future<List<Map<String, Object?>>> muChapters() async =>
      _mu!.query('sarki', orderBy: 'i');

  Future<List<Map<String, Object?>>> muSection(String tag) async =>
      _mu!.query('babat', where: 'bash = ?', whereArgs: [tag], orderBy: '_id');

  /// Ramadan sections (rm.db / ramazanew.db).
  Future<List<Map<String, Object?>>> ramadanTitles({bool newer = false}) async =>
      (newer ? _ramazanew! : _rm!).query('Titles', orderBy: '_id');

  Future<List<Map<String, Object?>>> ramadanRows(String table, {bool newer = false}) async =>
      (newer ? _ramazanew! : _rm!).query(table, orderBy: '_id');

  /// Supplications (duha.db).
  Future<List<Map<String, Object?>>> du3a() async =>
      _duha!.query('du3a', orderBy: 'id');

  /// Books (garanawa.db).
  Future<List<Map<String, Object?>>> books() async =>
      _garanawa!.query('babatakan', orderBy: '_id');

  /// One garanawa.db section table (bochetawbabkain, chontawbabkam,
  /// marjakanitawba, neshanayqbulitawba) for the tawba book reader.
  Future<List<Map<String, Object?>>> garanawaTable(String table) async {
    const allowed = [
      'babatakan', 'bochetawbabkain', 'chontawbabkam',
      'marjakanitawba', 'neshanayqbulitawba'
    ];
    if (!allowed.contains(table)) return [];
    return _garanawa!.query(table, orderBy: '_id');
  }
}
