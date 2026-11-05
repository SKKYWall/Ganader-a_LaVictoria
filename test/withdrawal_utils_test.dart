import 'package:flutter_test/flutter_test.dart';
import 'package:manual_ganadero_flutter/core/withdrawal_utils.dart';

void main() {
  group('daysUntilRelease / isInWithdrawal', () {
    test('ignores time-of-day when comparing calendar dates', () {
      final now = DateTime(2026, 1, 10, 23, 50); // casi medianoche
      final release = DateTime(2026, 1, 11, 0, 5); // un minuto después, otro día
      expect(daysUntilRelease(release, now: now), 1);
      expect(isInWithdrawal(release, now: now), isTrue);
    });

    test('is not in withdrawal on the release day itself', () {
      final now = DateTime(2026, 1, 11, 8, 0);
      final release = DateTime(2026, 1, 11, 20, 0);
      expect(daysUntilRelease(release, now: now), 0);
      expect(isInWithdrawal(release, now: now), isFalse);
    });

    test('is not in withdrawal once the release date has passed', () {
      final now = DateTime(2026, 1, 15);
      final release = DateTime(2026, 1, 10);
      expect(isInWithdrawal(release, now: now), isFalse);
    });
  });
}
