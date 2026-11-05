import 'package:flutter_test/flutter_test.dart';
import 'package:manual_ganadero_flutter/core/contemporary_groups.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';

Animal _calf(String tag,
    {required String breed,
    required String sex,
    required int year,
    required double weaning}) {
  return Animal(
    id: tag,
    name: tag,
    earTagNumber: tag,
    legNumber: tag,
    location: 'N/A',
    breed: breed,
    sex: sex,
    birthDate: DateTime(year, 3, 1),
    weaningWeight: weaning,
  );
}

void main() {
  group('ContemporaryGroups', () {
    test('uses the group average when there are enough real peers', () {
      final animals = [
        _calf('A', breed: 'Charolais', sex: 'Macho', year: 2024, weaning: 200),
        _calf('B', breed: 'Charolais', sex: 'Macho', year: 2024, weaning: 220),
        _calf('C', breed: 'Charolais', sex: 'Macho', year: 2024, weaning: 240),
      ];
      final groups = ContemporaryGroups.fromAnimals(animals);

      final (avg, isGroup) = groups.averageFor(animals.first);
      expect(isGroup, true);
      expect(avg, closeTo(220, 1e-9));
    });

    test('falls back to the overall average when the group is too small', () {
      final animals = [
        _calf('A', breed: 'Charolais', sex: 'Macho', year: 2024, weaning: 200),
        _calf('B', breed: 'Holstein', sex: 'Hembra', year: 2020, weaning: 150),
      ];
      final groups = ContemporaryGroups.fromAnimals(animals);

      final (avg, isGroup) = groups.averageFor(animals.first);
      expect(isGroup, false);
      expect(avg, closeTo(175, 1e-9)); // promedio general de las 2
    });

    test('falls back to the overall average when birthDate is missing', () {
      final withDate = _calf('A',
          breed: 'Charolais', sex: 'Macho', year: 2024, weaning: 200);
      final noDate = Animal(
        id: 'B',
        name: 'B',
        earTagNumber: 'B',
        legNumber: 'B',
        location: 'N/A',
        breed: 'Charolais',
        sex: 'Macho',
        weaningWeight: 240,
      );
      final groups = ContemporaryGroups.fromAnimals([withDate, noDate]);

      final (avg, isGroup) = groups.averageFor(noDate);
      expect(isGroup, false);
      expect(avg, closeTo(220, 1e-9));
    });
  });
}
