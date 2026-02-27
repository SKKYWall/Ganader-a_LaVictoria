// lib/models/animal.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Clase auxiliar para el registro de vacunas
// Mismo que en register_animal_screen.dart para consistencia
class VaccineRecord {
  String name;
  DateTime date;

  VaccineRecord({required this.name, required this.date});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'date': Timestamp.fromDate(date),
    };
  }

  factory VaccineRecord.fromMap(Map<String, dynamic> map) {
    return VaccineRecord(
      name: map['name'] as String,
      date: (map['date'] as Timestamp).toDate(),
    );
  }
}

class Animal {
  final String id;
  final String name;
  final String earTagNumber;
  final String legNumber;
  final String location;
  final List<String> imageUrls;
  final List<AnimalStat> stats;

  final String? breed;
  final int?
      age; // Este campo puede volverse redundante si siempre se calcula desde birthDate
  final String? sex;
  final DateTime? birthDate;
  final String? registrationNumber;

  final double? birthWeight;
  final double? weaningWeight;
  final String? father;
  final String? mother;
  final String? diseaseResistance;
  final String? fertilityInfo;
  final String? geneticMarkers;
  final String? description;
  final double? price;

  final String? profileImageUrl;

  // ¡NUEVOS CAMPOS AÑADIDOS!
  final List<VaccineRecord>? vaccinations; // Lista de registros de vacunas
  final bool? isPregnant; // ¿Está preñada? (Solo para hembras)
  final DateTime? pregnancyDate; // Fecha de preñez (Solo si isPregnant es true)
  final String? purpose;

  Animal({
    required this.id,
    required this.name,
    required this.earTagNumber,
    required this.legNumber,
    required this.location,
    this.imageUrls = const [],
    this.stats = const [],
    this.breed,
    this.age,
    this.sex,
    this.birthDate,
    this.registrationNumber,
    this.birthWeight,
    this.weaningWeight,
    this.father,
    this.mother,
    this.diseaseResistance,
    this.fertilityInfo,
    this.geneticMarkers,
    this.description,
    this.price,
    this.profileImageUrl,
    this.vaccinations, // Añadido al constructor
    this.isPregnant, // Añadido al constructor
    this.pregnancyDate, // Añadido al constructor
    this.purpose,
  });

  factory Animal.fromFirestore(Map<String, dynamic> data, String id) {
    List<String> urls = [];
    if (data['imageUrls'] is List) {
      urls = List<String>.from(data['imageUrls']);
    }

    List<AnimalStat> animalStats = [];
    if (data['stats'] is List) {
      animalStats = (data['stats'] as List)
          .map((statData) =>
              AnimalStat.fromFirestore(statData as Map<String, dynamic>))
          .toList();
    }

    DateTime? parsedBirthDate;
    final dynamic rawBirthDate = data['birthDate'];

    if (rawBirthDate is Timestamp) {
      parsedBirthDate = rawBirthDate.toDate();
    } else if (rawBirthDate is String) {
      try {
        parsedBirthDate = DateTime.parse(rawBirthDate);
      } catch (e) {
        print(
            'Error parsing birthDate string from Firestore: $rawBirthDate - $e');
        parsedBirthDate = null;
      }
    }

    // Mapeo de vacunas
    List<VaccineRecord> parsedVaccinations = [];
    if (data['vaccinations'] is List) {
      parsedVaccinations = (data['vaccinations'] as List)
          .map((vaccineData) =>
              VaccineRecord.fromMap(vaccineData as Map<String, dynamic>))
          .toList();
    }

    DateTime? parsedPregnancyDate;
    final dynamic rawPregnancyDate = data['pregnancyDate'];
    if (rawPregnancyDate is Timestamp) {
      parsedPregnancyDate = rawPregnancyDate.toDate();
    } else if (rawPregnancyDate is String) {
      try {
        parsedPregnancyDate = DateTime.parse(rawPregnancyDate);
      } catch (e) {
        print(
            'Error parsing pregnancyDate string from Firestore: $rawPregnancyDate - $e');
        parsedPregnancyDate = null;
      }
    }

    return Animal(
      id: id,
      name: data['name'] as String? ?? 'N/A',
      earTagNumber: data['earTagNumber'] as String? ?? 'N/A',
      legNumber: data['legNumber'] as String? ?? 'N/A',
      location: data['location'] as String? ?? 'N/A',
      imageUrls: urls,
      stats: animalStats,
      breed: data['breed'] as String?,
      age: (data['age'] as num?)?.toInt(),
      sex: data['sex'] as String?,
      birthDate: parsedBirthDate,
      registrationNumber: data['registrationNumber'] as String?,
      birthWeight: (data['birthWeight'] as num?)?.toDouble(),
      weaningWeight: (data['weaningWeight'] as num?)?.toDouble(),
      father: data['father'] as String?,
      mother: data['mother'] as String?,
      diseaseResistance: data['diseaseResistance'] as String?,
      fertilityInfo: data['fertilityInfo'] as String?,
      geneticMarkers: data['geneticMarkers'] as String?,
      description: data['description'] as String?,
      price: (data['price'] as num?)?.toDouble(),
      profileImageUrl: data['profileImageUrl'] as String?,
      purpose: data['purpose'] as String?,

      // Mapeo de nuevos campos
      vaccinations: parsedVaccinations.isEmpty
          ? null
          : parsedVaccinations, // Guardar como null si está vacío
      isPregnant: data['isPregnant'] as bool?,
      pregnancyDate: parsedPregnancyDate,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'earTagNumber': earTagNumber,
      'legNumber': legNumber,
      'location': location,
      'imageUrls': imageUrls,
      'stats': stats.map((stat) => stat.toFirestore()).toList(),
      if (breed != null) 'breed': breed,
      if (age != null)
        'age':
            age, // Mantenerlo si lo usas para otros fines, si no, puedes eliminarlo
      if (sex != null) 'sex': sex,
      if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate!),
      if (registrationNumber != null) 'registrationNumber': registrationNumber,
      if (birthWeight != null) 'birthWeight': birthWeight,
      if (weaningWeight != null) 'weaningWeight': weaningWeight,
      if (father != null) 'father': father,
      if (mother != null) 'mother': mother,
      if (diseaseResistance != null) 'diseaseResistance': diseaseResistance,
      if (fertilityInfo != null) 'fertilityInfo': fertilityInfo,
      if (geneticMarkers != null) 'geneticMarkers': geneticMarkers,
      if (description != null) 'description': description,
      if (price != null) 'price': price,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,

      // Guardar nuevos campos
      if (vaccinations != null && vaccinations!.isNotEmpty)
        'vaccinations': vaccinations!.map((v) => v.toMap()).toList(),
      if (isPregnant != null) 'isPregnant': isPregnant,
      if (pregnancyDate != null)
        'pregnancyDate': Timestamp.fromDate(pregnancyDate!),
      if (purpose != null) 'purpose': purpose,
    };
  }
}

class AnimalStat {
  final DateTime date;
  final double value;
  final String label;

  AnimalStat({
    required this.date,
    required this.value,
    required this.label,
  });

  factory AnimalStat.fromFirestore(Map<String, dynamic> data) {
    DateTime? parsedDate;
    final dynamic rawDate = data['date'];

    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      try {
        parsedDate = DateTime.parse(rawDate);
      } catch (e) {
        print(
            'Error parsing AnimalStat date string from Firestore: $rawDate - $e');
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    return AnimalStat(
      date: parsedDate, // Asegurarse de que no sea null
      value: (data['value'] as num).toDouble(),
      label: data['label'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'value': value,
      'label': label,
    };
  }
}
