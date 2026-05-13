// lib/models/animal_stat.dart
import 'package:cloud_firestore/cloud_firestore.dart';

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

    // Manejo seguro de la fecha desde Firestore
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
      date: parsedDate,
      value: (data['value'] as num?)?.toDouble() ?? 0.0,
      label: data['label'] as String? ?? 'N/A',
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
