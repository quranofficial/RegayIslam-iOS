import 'package:flutter_test/flutter_test.dart';

import '../lib/core/kurdish_date.dart';

void main() {
  group('Kurdish date formatting', () {
    final saturday = DateTime(2026, 11, 7);

    test('maps Saturday and Sunday to Kurdish weekday names', () {
      expect(weekdayKu(saturday), 'شەممە');
      expect(weekdayKu(DateTime(2026, 11, 8)), 'یەکشەممە');
    });

    test('formats Gregorian dates with Kurdish month names and digits', () {
      expect(gregorianKu(saturday), '٧ی تشرینی دووەم ٢٠٢٦');
      expect(kuDigits(123), '١٢٣');
    });

    test('combines weekday, Gregorian and tabular Hijri dates', () {
      final (year, month, day) = hijriOf(saturday);
      expect(year, greaterThan(1400));
      expect(month, inInclusiveRange(1, 12));
      expect(day, inInclusiveRange(1, 30));

      expect(
        fullDateKu(saturday),
        startsWith('شەممە — ٧ی تشرینی دووەم ٢٠٢٦ — '),
      );
    });
  });
}
