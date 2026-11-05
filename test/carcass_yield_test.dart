import 'package:flutter_test/flutter_test.dart';
import 'package:manual_ganadero_flutter/core/breed_groups.dart';
import 'package:manual_ganadero_flutter/core/carcass_yield.dart';

void main() {
  group('breedGroupOf', () {
    test('classifies known breeds into the right group', () {
      expect(breedGroupOf('Charolais'), BreedGroup.continental);
      expect(breedGroupOf('Holstein'), BreedGroup.lechera);
      expect(breedGroupOf('Nelore'), BreedGroup.cebu);
      expect(breedGroupOf('Brangus'), BreedGroup.cruzaOtro);
    });

    test('falls back to cruzaOtro for unknown or null breed', () {
      expect(breedGroupOf('Raza inventada'), BreedGroup.cruzaOtro);
      expect(breedGroupOf(null), BreedGroup.cruzaOtro);
    });
  });

  group('carcassYieldFor', () {
    test('uses the continental base rate for beef-specialized breeds', () {
      expect(carcassYieldFor('Charolais', 'Hembra'), 0.60);
    });

    test('uses the dairy base rate for dairy breeds', () {
      expect(carcassYieldFor('Holstein', 'Hembra'), 0.58);
    });

    test('uses the lower cebu base rate for Bos indicus breeds', () {
      expect(carcassYieldFor('Nelore', 'Hembra'), 0.52);
    });

    test('applies a small upward adjustment for males', () {
      final female = carcassYieldFor('Angus', 'Hembra');
      final male = carcassYieldFor('Angus', 'Macho');
      expect(male, greaterThan(female));
      expect(male - female, closeTo(0.015, 1e-9));
    });
  });
}
