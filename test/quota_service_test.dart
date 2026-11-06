import 'package:flutter_test/flutter_test.dart';
import 'package:manual_ganadero_flutter/services/quota_service.dart';

void main() {
  final now = DateTime.now();
  final future = now.add(const Duration(days: 30));
  final past = now.subtract(const Duration(days: 1));

  group('PaidBatch.isValid', () {
    test('is valid when not expired and amount > 0', () {
      final batch = PaidBatch(amount: 5, expiry: future, purchased: now);
      expect(batch.isValid, isTrue);
    });

    test('is invalid when expired', () {
      final batch = PaidBatch(amount: 5, expiry: past, purchased: now);
      expect(batch.isValid, isFalse);
    });

    test('is invalid when amount is zero', () {
      final batch = PaidBatch(amount: 0, expiry: future, purchased: now);
      expect(batch.isValid, isFalse);
    });
  });

  group('QuotaStatus.monthlyRemaining', () {
    test('subtracts used from free and clamps at zero', () {
      const status = QuotaStatus(
        monthlyUsed: 3,
        monthlyFree: 5,
        paidBatches: [],
        isPremium: false,
      );
      expect(status.monthlyRemaining, 2);
    });

    test('never goes negative when used exceeds free', () {
      const status = QuotaStatus(
        monthlyUsed: 9,
        monthlyFree: 5,
        paidBatches: [],
        isPremium: false,
      );
      expect(status.monthlyRemaining, 0);
    });
  });

  group('QuotaStatus.premiumActive', () {
    test('true when premium flag set and expiry in the future', () {
      final status = QuotaStatus(
        monthlyUsed: 0,
        monthlyFree: 5,
        paidBatches: const [],
        isPremium: true,
        premiumExpiry: future,
      );
      expect(status.premiumActive, isTrue);
    });

    test('false when premium flag set but expiry already passed', () {
      final status = QuotaStatus(
        monthlyUsed: 0,
        monthlyFree: 5,
        paidBatches: const [],
        isPremium: true,
        premiumExpiry: past,
      );
      expect(status.premiumActive, isFalse);
    });

    test('false when premium flag is false regardless of expiry', () {
      final status = QuotaStatus(
        monthlyUsed: 0,
        monthlyFree: 5,
        paidBatches: const [],
        isPremium: false,
        premiumExpiry: future,
      );
      expect(status.premiumActive, isFalse);
    });
  });

  group('QuotaStatus.paidConsults / activeBatches', () {
    test('sums only non-expired batches and ignores expired ones', () {
      final status = QuotaStatus(
        monthlyUsed: 5,
        monthlyFree: 5,
        paidBatches: [
          PaidBatch(amount: 10, expiry: future, purchased: now),
          PaidBatch(amount: 99, expiry: past, purchased: now),
        ],
        isPremium: false,
      );
      expect(status.paidConsults, 10);
    });

    test('activeBatches is sorted by soonest expiry first', () {
      final soon = now.add(const Duration(days: 5));
      final later = now.add(const Duration(days: 60));
      final status = QuotaStatus(
        monthlyUsed: 0,
        monthlyFree: 5,
        paidBatches: [
          PaidBatch(amount: 1, expiry: later, purchased: now),
          PaidBatch(amount: 2, expiry: soon, purchased: now),
        ],
        isPremium: false,
      );
      expect(status.activeBatches.first.expiry, soon);
      expect(status.nearestPaidExpiry, soon);
    });
  });

  group('QuotaStatus.clarificationsRemaining', () {
    test('subtracts used from the free clarification cap', () {
      const status = QuotaStatus(
        monthlyUsed: 0,
        monthlyFree: 5,
        paidBatches: [],
        isPremium: false,
        clarificationsUsed: 2,
      );
      expect(status.clarificationsRemaining,
          QuotaService.kMonthlyFreeClarifications - 2);
    });

    test('never goes negative when used exceeds the cap', () {
      const status = QuotaStatus(
        monthlyUsed: 0,
        monthlyFree: 5,
        paidBatches: [],
        isPremium: false,
        clarificationsUsed: QuotaService.kMonthlyFreeClarifications + 5,
      );
      expect(status.clarificationsRemaining, 0);
    });

    test('defaults to the full cap when nothing has been used', () {
      const status = QuotaStatus(
        monthlyUsed: 0,
        monthlyFree: 5,
        paidBatches: [],
        isPremium: false,
      );
      expect(
          status.clarificationsRemaining, QuotaService.kMonthlyFreeClarifications);
    });
  });

  group('QuotaStatus.canSend / nextSource priority', () {
    test('premium active and under limit can send from premium', () {
      final status = QuotaStatus(
        monthlyUsed: 5,
        monthlyFree: 5,
        paidBatches: const [],
        isPremium: true,
        premiumExpiry: future,
        premiumMonthUsed: 10,
      );
      expect(status.canSend, isTrue);
      expect(status.nextSource, ConsultSource.premium);
    });

    test('premium active but over the invisible monthly cap falls through',
        () {
      final status = QuotaStatus(
        monthlyUsed: 5,
        monthlyFree: 5,
        paidBatches: const [],
        isPremium: true,
        premiumExpiry: future,
        premiumMonthUsed: QuotaService.kPremiumMonthlyLimit,
      );
      expect(status.nextSource, isNot(ConsultSource.premium));
    });

    test('not premium, free quota remaining uses monthly source', () {
      const status = QuotaStatus(
        monthlyUsed: 2,
        monthlyFree: 5,
        paidBatches: [],
        isPremium: false,
      );
      expect(status.canSend, isTrue);
      expect(status.nextSource, ConsultSource.monthly);
    });

    test('free quota exhausted but paid batches available uses paid source',
        () {
      final status = QuotaStatus(
        monthlyUsed: 5,
        monthlyFree: 5,
        paidBatches: [PaidBatch(amount: 3, expiry: future, purchased: now)],
        isPremium: false,
      );
      expect(status.canSend, isTrue);
      expect(status.nextSource, ConsultSource.paid);
    });

    test('nothing available returns none and cannot send', () {
      const status = QuotaStatus(
        monthlyUsed: 5,
        monthlyFree: 5,
        paidBatches: [],
        isPremium: false,
      );
      expect(status.canSend, isFalse);
      expect(status.nextSource, ConsultSource.none);
    });
  });
}
