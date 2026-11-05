import 'package:flutter_test/flutter_test.dart';
import 'package:manual_ganadero_flutter/core/weaning_gdp.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:manual_ganadero_flutter/models/animal_stat.dart';

Animal _baseAnimal({
  DateTime? birthDate,
  double? birthWeight,
  double? weaningWeight,
  List<AnimalStat> stats = const [],
}) {
  return Animal(
    id: 'A',
    name: 'A',
    earTagNumber: 'A',
    legNumber: 'A',
    location: 'N/A',
    birthDate: birthDate,
    birthWeight: birthWeight,
    weaningWeight: weaningWeight,
    stats: stats,
  );
}

void main() {
  group('calculateWeaningGdp', () {
    test('returns null when birth or weaning weight is missing', () {
      final animal = _baseAnimal(birthWeight: 35);
      expect(calculateWeaningGdp(animal), isNull);
    });

    test('falls back to the 205-day standard when there is no matching weight stat', () {
      final animal = _baseAnimal(
        birthDate: DateTime(2024, 1, 1),
        birthWeight: 35,
        weaningWeight: 215, // +180kg
      );
      final result = calculateWeaningGdp(animal)!;
      expect(result.usedRealWeaningDate, false);
      expect(result.gramsPerDay, closeTo(180000 / 205, 0.01));
    });

    test('uses the real date of the matching weight record when available', () {
      final animal = _baseAnimal(
        birthDate: DateTime(2024, 1, 1),
        birthWeight: 35,
        weaningWeight: 215,
        stats: [
          AnimalStat(date: DateTime(2024, 1, 1), value: 35, label: 'Peso'),
          // Destete real a los 180 días, no 205.
          AnimalStat(date: DateTime(2024, 6, 29), value: 216, label: 'Peso'),
        ],
      );
      final result = calculateWeaningGdp(animal)!;
      final realDays = DateTime(2024, 6, 29).difference(DateTime(2024, 1, 1)).inDays;
      expect(result.usedRealWeaningDate, true);
      expect(result.gramsPerDay, closeTo(180000 / realDays, 0.01));
    });

    test('reports a real negative GDP instead of hiding it', () {
      final animal = _baseAnimal(
        birthDate: DateTime(2024, 1, 1),
        birthWeight: 40,
        weaningWeight: 35, // perdió peso -- dato real, aunque anormal
      );
      final result = calculateWeaningGdp(animal)!;
      expect(result.gramsPerDay, lessThan(0));
    });
  });
}
