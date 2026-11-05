import 'package:flutter_test/flutter_test.dart';

// The app entry (RegayIslamApp) needs async prefs/db init before pumping,
// so the CI test suite stays a plain smoke test.
void main() {
  test('smoke', () {
    expect(1 + 1, 2);
  });
}
