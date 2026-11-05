// lib/models/animal.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:manual_ganadero_flutter/models/animal_stat.dart'; // Ajusta la ruta según tus carpetas

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

// Registro de un servicio reproductivo (monta natural o inseminación
// artificial) y su seguimiento hasta el parto. `pregnancyDate`/`isPregnant`
// en Animal siguen siendo la fuente de verdad para "¿está preñada ahora?"
// (los usa toda la app) — este registro es el historial detallado de CÓMO
// se logró esa preñez, para poder calcular indicadores reales a futuro
// (% por tipo de servicio, intervalo entre partos, etc.) en vez de solo
// saber el estado actual.
class ReproductiveEvent {
  final String serviceType; // 'Monta Natural' | 'Inseminación Artificial'
  // earTag del semental si está en el sistema, o texto libre si es externo
  // (pajilla, semental ajeno) — misma convención que Animal.father/mother.
  final String? sireEarTag;
  final DateTime serviceDate;
  final bool? pregnancyConfirmed;
  final DateTime? pregnancyCheckDate;
  final String? outcome; // 'vivo' | 'muerto' | 'aborto' (null = pendiente)
  final DateTime? outcomeDate;
  final String? notes;

  ReproductiveEvent({
    required this.serviceType,
    this.sireEarTag,
    required this.serviceDate,
    this.pregnancyConfirmed,
    this.pregnancyCheckDate,
    this.outcome,
    this.outcomeDate,
    this.notes,
  });

  bool get isOpen => outcome == null;

  ReproductiveEvent copyWith({
    bool? pregnancyConfirmed,
    DateTime? pregnancyCheckDate,
    String? outcome,
    DateTime? outcomeDate,
  }) {
    return ReproductiveEvent(
      serviceType: serviceType,
      sireEarTag: sireEarTag,
      serviceDate: serviceDate,
      pregnancyConfirmed: pregnancyConfirmed ?? this.pregnancyConfirmed,
      pregnancyCheckDate: pregnancyCheckDate ?? this.pregnancyCheckDate,
      outcome: outcome ?? this.outcome,
      outcomeDate: outcomeDate ?? this.outcomeDate,
      notes: notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serviceType': serviceType,
      if (sireEarTag != null) 'sireEarTag': sireEarTag,
      'serviceDate': Timestamp.fromDate(serviceDate),
      if (pregnancyConfirmed != null) 'pregnancyConfirmed': pregnancyConfirmed,
      if (pregnancyCheckDate != null)
        'pregnancyCheckDate': Timestamp.fromDate(pregnancyCheckDate!),
      if (outcome != null) 'outcome': outcome,
      if (outcomeDate != null) 'outcomeDate': Timestamp.fromDate(outcomeDate!),
      if (notes != null) 'notes': notes,
    };
  }

  factory ReproductiveEvent.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) {
        try {
          return DateTime.parse(raw);
        } catch (_) {}
      }
      return DateTime.now();
    }

    return ReproductiveEvent(
      serviceType: map['serviceType'] as String? ?? 'Monta Natural',
      sireEarTag: map['sireEarTag'] as String?,
      serviceDate: parseDate(map['serviceDate']),
      pregnancyConfirmed: map['pregnancyConfirmed'] as bool?,
      pregnancyCheckDate: map['pregnancyCheckDate'] != null
          ? parseDate(map['pregnancyCheckDate'])
          : null,
      outcome: map['outcome'] as String?,
      outcomeDate:
          map['outcomeDate'] != null ? parseDate(map['outcomeDate']) : null,
      notes: map['notes'] as String?,
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
  final DateTime? withdrawalDate; // Fecha de retiro por medicamentos

  // Historial de servicios reproductivos (monta natural / IA) — ver
  // ReproductiveEvent arriba. isPregnant/pregnancyDate siguen siendo la
  // fuente de verdad del estado actual.
  final List<ReproductiveEvent>? reproductiveEvents;

  // Ciclo de vida del animal. 'activo' si no se ha dado de baja.
  final String status; // 'activo' | 'inactivo'
  final String? exitReason; // 'vendido' | 'sacrificado' | 'muerto'
  final DateTime? exitDate;
  final double? exitPrice;
  final String? exitNotes;

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
    this.reproductiveEvents,
    this.withdrawalDate,
    this.purpose,
    this.status = 'activo',
    this.exitReason,
    this.exitDate,
    this.exitPrice,
    this.exitNotes,
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
        debugPrint(
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

    // Mapeo de historial reproductivo
    List<ReproductiveEvent> parsedReproEvents = [];
    if (data['reproductiveEvents'] is List) {
      parsedReproEvents = (data['reproductiveEvents'] as List)
          .map((eventData) =>
              ReproductiveEvent.fromMap(eventData as Map<String, dynamic>))
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
        debugPrint(
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
      reproductiveEvents:
          parsedReproEvents.isEmpty ? null : parsedReproEvents,

      withdrawalDate: data['withdrawalDate'] != null
          ? (data['withdrawalDate'] as Timestamp).toDate()
          : null,

      // Ciclo de vida: los animales existentes sin este campo se tratan
      // como 'activo' para no romper datos ya guardados.
      status: data['status'] as String? ?? 'activo',
      exitReason: data['exitReason'] as String?,
      exitDate: data['exitDate'] is Timestamp
          ? (data['exitDate'] as Timestamp).toDate()
          : null,
      exitPrice: (data['exitPrice'] as num?)?.toDouble(),
      exitNotes: data['exitNotes'] as String?,
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
      if (reproductiveEvents != null && reproductiveEvents!.isNotEmpty)
        'reproductiveEvents':
            reproductiveEvents!.map((e) => e.toMap()).toList(),
      if (purpose != null) 'purpose': purpose,

      if (withdrawalDate != null)
        'withdrawalDate': Timestamp.fromDate(withdrawalDate!),

      'status': status,
      if (exitReason != null) 'exitReason': exitReason,
      if (exitDate != null) 'exitDate': Timestamp.fromDate(exitDate!),
      if (exitPrice != null) 'exitPrice': exitPrice,
      if (exitNotes != null) 'exitNotes': exitNotes,
    };
  }
}
