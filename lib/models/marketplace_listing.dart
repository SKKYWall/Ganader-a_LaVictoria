// lib/models/marketplace_listing.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:manual_ganadero_flutter/models/animal.dart'; // Importa VaccineRecord y AnimalStat

class MarketplaceListing {
  final String
      listingId; // ID del listado en el marketplace (generado por Firestore)
  final String animalId; // ID del animal original que se está vendiendo
  final String ownerId; // ID del usuario que publica el animal
  final String title;
  final String description;
  final double price;
  final String?
      profileImageUrl; // Cambiado a String? para la URL de una sola imagen de perfil
  final DateTime publishDate;
  final String status; // Ej: 'activo', 'vendido', 'pausado'

  // Nuevos campos copiados del modelo Animal
  final String? breed;
  final String? sex;
  final DateTime?
      birthDate; // Para calcular la edad si no se guarda 'age' directamente
  final String? earTagNumber;
  final String? legNumber;
  final String? location;
  final String? registrationNumber;
  final double? birthWeight;
  final double? weaningWeight;
  final String? father;
  final String? mother;
  final String? diseaseResistance;
  final String? fertilityInfo;
  final String? geneticMarkers;

  // Información de contacto del publicador (si quieres que sea pública en el listado)
  final String? publisherEmail;
  final String? publisherPhone;
  final String? publisherRanchAddress;
  // Añadido: Campo para redes sociales del publicador
  final Map<String, dynamic>? publisherSocialMedia;

  // Campos de Vacunación y Preñez copiados del modelo Animal
  final List<VaccineRecord>? vaccinations; // Lista de registros de vacunas
  final bool? isPregnant; // ¿Está preñada? (Solo para hembras)
  final DateTime? pregnancyDate; // Fecha de preñez (Solo si isPregnant es true)

  MarketplaceListing({
    required this.listingId,
    required this.animalId,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.price,
    this.profileImageUrl,
    required this.publishDate,
    required this.status,
    this.breed,
    this.sex,
    this.birthDate,
    this.earTagNumber,
    this.legNumber,
    this.location,
    this.registrationNumber,
    this.birthWeight,
    this.weaningWeight,
    this.father,
    this.mother,
    this.diseaseResistance,
    this.fertilityInfo,
    this.geneticMarkers,
    this.publisherEmail,
    this.publisherPhone,
    this.publisherRanchAddress,
    this.vaccinations, // Añadido al constructor
    this.isPregnant, // Añadido al constructor
    this.pregnancyDate, // Añadido al constructor
    this.publisherSocialMedia, // Añadido al constructor
  });

  factory MarketplaceListing.fromFirestore(
      Map<String, dynamic> data, String id) {
    DateTime? parsedPublishDate;
    if (data['publishedAt'] is Timestamp) {
      parsedPublishDate = (data['publishedAt'] as Timestamp).toDate();
    } else {
      parsedPublishDate = DateTime.now(); // Fallback
    }

    DateTime? parsedBirthDate;
    if (data['birthDate'] is Timestamp) {
      parsedBirthDate = (data['birthDate'] as Timestamp).toDate();
    }

    DateTime? parsedPregnancyDate;
    if (data['pregnancyDate'] is Timestamp) {
      parsedPregnancyDate = (data['pregnancyDate'] as Timestamp).toDate();
    }

    List<VaccineRecord> parsedVaccinations = [];
    if (data['vaccinations'] is List) {
      parsedVaccinations = (data['vaccinations'] as List)
          .map((vaccineData) =>
              VaccineRecord.fromMap(vaccineData as Map<String, dynamic>))
          .toList();
    }

    // Parsear publisherSocialMedia
    Map<String, dynamic>? parsedSocialMedia;
    if (data['publisherSocialMedia'] is Map) {
      parsedSocialMedia = data['publisherSocialMedia'] as Map<String, dynamic>;
    }

    return MarketplaceListing(
      listingId: id,
      animalId: data['animalId'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      title: data['title'] as String? ?? 'N/A',
      description: data['description'] as String? ?? 'N/A',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      profileImageUrl: data['profileImageUrl'] as String?,
      publishDate: parsedPublishDate,
      status: data['status'] as String? ?? 'activo',
      breed: data['breed'] as String?,
      sex: data['sex'] as String?,
      birthDate: parsedBirthDate,
      earTagNumber: data['earTagNumber'] as String?,
      legNumber: data['legNumber'] as String?,
      location: data['location'] as String?,
      registrationNumber: data['registrationNumber'] as String?,
      birthWeight: (data['birthWeight'] as num?)?.toDouble(),
      weaningWeight: (data['weaningWeight'] as num?)?.toDouble(),
      father: data['father'] as String?,
      mother: data['mother'] as String?,
      diseaseResistance: data['diseaseResistance'] as String?,
      fertilityInfo: data['fertilityInfo'] as String?,
      geneticMarkers: data['geneticMarkers'] as String?,
      publisherEmail: data['publisherEmail'] as String?,
      publisherPhone: data['publisherPhone'] as String?,
      publisherRanchAddress: data['publisherRanchAddress'] as String?,
      vaccinations: parsedVaccinations.isEmpty
          ? null
          : parsedVaccinations, // Guardar como null si está vacío
      isPregnant: data['isPregnant'] as bool?,
      pregnancyDate: parsedPregnancyDate,
      publisherSocialMedia: parsedSocialMedia, // Asignar el mapa parseado
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'animalId': animalId,
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'price': price,
      'profileImageUrl': profileImageUrl, // Ahora es una sola URL
      'publishedAt':
          Timestamp.fromDate(publishDate), // Renombrado a publishedAt
      'status': status,
      // Incluir los nuevos campos en el mapa de Firestore
      if (breed != null) 'breed': breed,
      if (sex != null) 'sex': sex,
      if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate!),
      if (earTagNumber != null) 'earTagNumber': earTagNumber,
      if (legNumber != null) 'legNumber': legNumber,
      if (location != null) 'location': location,
      if (registrationNumber != null) 'registrationNumber': registrationNumber,
      if (birthWeight != null) 'birthWeight': birthWeight,
      if (weaningWeight != null) 'weaningWeight': weaningWeight,
      if (father != null) 'father': father,
      if (mother != null) 'mother': mother,
      if (diseaseResistance != null) 'diseaseResistance': diseaseResistance,
      if (fertilityInfo != null) 'fertilityInfo': fertilityInfo,
      if (geneticMarkers != null) 'geneticMarkers': geneticMarkers,
      if (publisherEmail != null) 'publisherEmail': publisherEmail,
      if (publisherPhone != null) 'publisherPhone': publisherPhone,
      if (publisherRanchAddress != null)
        'publisherRanchAddress': publisherRanchAddress,
      if (vaccinations != null && vaccinations!.isNotEmpty)
        'vaccinations': vaccinations!.map((v) => v.toMap()).toList(),
      if (isPregnant != null) 'isPregnant': isPregnant,
      if (pregnancyDate != null)
        'pregnancyDate': Timestamp.fromDate(pregnancyDate!),
      if (publisherSocialMedia != null &&
          publisherSocialMedia!.isNotEmpty) // Añadir a toFirestore
        'publisherSocialMedia': publisherSocialMedia,
    };
  }
}
