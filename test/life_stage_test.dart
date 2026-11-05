import 'package:flutter_test/flutter_test.dart';
import 'package:manual_ganadero_flutter/core/life_stage.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';

Animal _animalBornOn(DateTime? birthDate) {
  return Animal(
    id: 'A',
    name: 'A',
    earTagNumber: 'A',
    legNumber: 'A',
    location: 'N/A',
    birthDate: birthDate,
  );
}

void main() {
  group('computeLifeStage', () {
    final now = DateTime(2026, 1, 1);

    test('classifies an animal under 12 months as ternero', () {
      final a = _animalBornOn(DateTime(2025, 6, 1));
      expect(computeLifeStage(a, now: now), LifeStage.ternero);
    });

    test('classifies an animal between 1 and 2 years as novillo', () {
      final a = _animalBornOn(DateTime(2024, 6, 1));
      expect(computeLifeStage(a, now: now), LifeStage.novillo);
    });

    test('classifies an animal over 2 years as adulto', () {
      final a = _animalBornOn(DateTime(2020, 1, 1));
      expect(computeLifeStage(a, now: now), LifeStage.adulto);
    });

    test('returns desconocido when birthDate is missing', () {
      final a = _animalBornOn(null);
      expect(computeLifeStage(a, now: now), LifeStage.desconocido);
    });
  });
}
