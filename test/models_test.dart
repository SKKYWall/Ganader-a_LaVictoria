import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';

void main() {
  group('Animal.fromFirestore / toFirestore', () {
    test('round-trips all fields including vaccinations and dates', () {
      final birthDate = DateTime(2022, 3, 15);
      final pregnancyDate = DateTime(2024, 1, 10);
      final original = Animal(
        id: 'a1',
        name: 'Luna',
        earTagNumber: '285',
        legNumber: '3',
        location: 'Potrero 2',
        imageUrls: const ['http://example.com/luna.jpg'],
        breed: 'Nelore',
        sex: 'Hembra',
        birthDate: birthDate,
        birthWeight: 35.5,
        weaningWeight: 180.0,
        purpose: 'Reproductora',
        vaccinations: [
          VaccineRecord(name: 'Brucelosis', date: DateTime(2023, 6, 1)),
        ],
        isPregnant: true,
        pregnancyDate: pregnancyDate,
      );

      final firestoreMap = original.toFirestore();
      final restored = Animal.fromFirestore(firestoreMap, original.id);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.earTagNumber, original.earTagNumber);
      expect(restored.legNumber, original.legNumber);
      expect(restored.breed, original.breed);
      expect(restored.sex, original.sex);
      expect(restored.birthDate, birthDate);
      expect(restored.birthWeight, original.birthWeight);
      expect(restored.weaningWeight, original.weaningWeight);
      expect(restored.purpose, original.purpose);
      expect(restored.isPregnant, true);
      expect(restored.pregnancyDate, pregnancyDate);
      expect(restored.vaccinations, isNotNull);
      expect(restored.vaccinations!.single.name, 'Brucelosis');
    });

    test('defaults required fields to N/A when missing from Firestore', () {
      final animal = Animal.fromFirestore(const {}, 'missing-fields');

      expect(animal.name, 'N/A');
      expect(animal.earTagNumber, 'N/A');
      expect(animal.legNumber, 'N/A');
      expect(animal.location, 'N/A');
      expect(animal.breed, isNull);
      expect(animal.vaccinations, isNull);
    });

    test('parses birthDate from a String as well as a Timestamp', () {
      final fromString =
          Animal.fromFirestore({'birthDate': '2021-05-20T00:00:00.000'}, 'x');
      final fromTimestamp = Animal.fromFirestore(
          {'birthDate': Timestamp.fromDate(DateTime(2021, 5, 20))}, 'y');

      expect(fromString.birthDate, DateTime(2021, 5, 20));
      expect(fromTimestamp.birthDate, DateTime(2021, 5, 20));
    });

    test('toFirestore omits null optional fields entirely', () {
      final animal = Animal(
        id: 'a2',
        name: 'Toro 1',
        earTagNumber: '10',
        legNumber: 'Sin pierna',
        location: 'N/A',
      );

      final map = animal.toFirestore();

      expect(map.containsKey('breed'), isFalse);
      expect(map.containsKey('vaccinations'), isFalse);
      expect(map.containsKey('isPregnant'), isFalse);
    });
  });
}
