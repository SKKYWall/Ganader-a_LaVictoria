// lib/models/calendar.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date; // Solo la fecha (sin hora para simplicidad)
  final String category; // Ej: 'Vacunación', 'Parto', 'Cita', 'Mantenimiento'
  // Puedes añadir más campos según tus necesidades, ej:
  // final DateTime? startTime;
  // final DateTime? endTime;
  // final String? relatedAnimalId;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.date,
    required this.category,
    // this.startTime,
    // this.endTime,
    // this.relatedAnimalId,
  });

  // Método para crear un CalendarEvent desde un documento de Firestore
  factory CalendarEvent.fromFirestore(Map<String, dynamic> data, String id) {
    return CalendarEvent(
      id: id,
      title: data['title'] ?? 'Sin título',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp)
          .toDate(), // Convierte Timestamp a DateTime
      category: data['category'] ?? 'General',
      // startTime: (data['startTime'] as Timestamp?)?.toDate(),
      // endTime: (data['endTime'] as Timestamp?)?.toDate(),
      // relatedAnimalId: data['relatedAnimalId'],
    );
  }

  // Método para convertir CalendarEvent a un mapa para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date), // Guarda la fecha como Timestamp
      'category': category,
      // 'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      // 'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      // 'relatedAnimalId': relatedAnimalId,
    };
  }

  @override
  String toString() => title; // Útil para depuración o visualización rápida
}
