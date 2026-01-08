// lib/models/animal_stat.dart
class AnimalStat {
  final String name;
  final double value;

  AnimalStat({required this.name, required this.value});

  // Si necesitas serialización/deserialización para Firestore
  factory AnimalStat.fromJson(Map<String, dynamic> json) {
    return AnimalStat(
      name: json['name'] as String? ?? 'N/A',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'value': value,
    };
  }
}
