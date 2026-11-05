import 'package:flutter_test/flutter_test.dart';
import 'package:manual_ganadero_flutter/core/pedigree.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';

Animal _animal(String tag, {String? father, String? mother, String sex = 'Macho'}) {
  return Animal(
    id: tag,
    name: tag,
    earTagNumber: tag,
    legNumber: tag,
    location: 'N/A',
    sex: sex,
    father: father,
    mother: mother,
  );
}

void main() {
  group('calculateInbreeding', () {
    test('full siblings (same sire and dam) => F = 0.25', () {
      final sire = _animal('S');
      final dam = _animal('D', sex: 'Hembra');
      final candidateFather = _animal('F1', father: 'S', mother: 'D');
      final candidateMother = _animal('M1', father: 'S', mother: 'D', sex: 'Hembra');

      final byEarTag = buildEarTagIndex([sire, dam, candidateFather, candidateMother]);
      final result = calculateInbreeding(candidateFather, candidateMother, byEarTag);

      expect(result.coefficient, closeTo(0.25, 1e-9));
      expect(result.risk, InbreedingRisk.critical);
    });

    test('half siblings (same sire, different dams) => F = 0.125', () {
      final sire = _animal('S');
      final dam1 = _animal('D1', sex: 'Hembra');
      final dam2 = _animal('D2', sex: 'Hembra');
      final candidateFather = _animal('F1', father: 'S', mother: 'D1');
      final candidateMother = _animal('M1', father: 'S', mother: 'D2', sex: 'Hembra');

      final byEarTag =
          buildEarTagIndex([sire, dam1, dam2, candidateFather, candidateMother]);
      final result = calculateInbreeding(candidateFather, candidateMother, byEarTag);

      expect(result.coefficient, closeTo(0.125, 1e-9));
      expect(result.risk, InbreedingRisk.high);
    });

    test('grandparent-grandchild => F = 0.125', () {
      // candidateFather es el abuelo paterno de candidateMother:
      // candidateMother -> su padre (MF) -> el padre de MF (candidateFather).
      final candidateFather = _animal('GF');
      final motherFather = _animal('MF', father: 'GF', mother: 'MGD');
      final candidateMother =
          _animal('M1', father: 'MF', mother: 'MD', sex: 'Hembra');

      final byEarTag = buildEarTagIndex(
          [candidateFather, motherFather, candidateMother]);
      final result = calculateInbreeding(candidateFather, candidateMother, byEarTag);

      expect(result.coefficient, closeTo(0.125, 1e-9));
      expect(result.risk, InbreedingRisk.high);
    });

    test('unrelated pedigrees => F = 0', () {
      final candidateFather = _animal('F1', father: 'FGF', mother: 'FGM');
      final candidateMother =
          _animal('M1', father: 'MGF', mother: 'MGM', sex: 'Hembra');

      final byEarTag = buildEarTagIndex([candidateFather, candidateMother]);
      final result = calculateInbreeding(candidateFather, candidateMother, byEarTag);

      expect(result.coefficient, 0.0);
      expect(result.risk, InbreedingRisk.none);
    });

    test('tracks how many ancestor slots were actually known vs unknown', () {
      final candidateFather = _animal('F1'); // sin padres registrados
      final candidateMother = _animal('M1', sex: 'Hembra'); // sin padres registrados

      final byEarTag = buildEarTagIndex([candidateFather, candidateMother]);
      final result = calculateInbreeding(candidateFather, candidateMother, byEarTag);

      expect(result.totalAncestorSlots, 28); // 14 por cada lado (2+4+8)
      expect(result.knownAncestorSlots, 0);
      expect(result.pedigreeCompleteness, 0.0);
    });
  });
}
