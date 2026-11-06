import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Configure SQLite to persist browser databases in IndexedDB.
void configureDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}
