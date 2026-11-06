// lib/models/sanitary_plan.dart
//
// Plan sanitario preconfigurado: una secuencia de pasos (vacunas,
// desparasitantes, etc.) que se puede asignar de un jalón a un grupo de
// animales. Asignar un plan NO aplica los tratamientos directamente —
// programa un recordatorio en el calendario para cada paso en su fecha
// correspondiente (hoy + offsetDays), reutilizando el sistema de
// calendario/notificaciones que ya existe, para que el usuario confirme y
// aplique cada tratamiento cuando realmente toque.
import 'package:cloud_firestore/cloud_firestore.dart';

class SanitaryPlanStep {
  final String type; // Vacuna | Desparasitante | Antibiótico | Vitamina | Tratamiento
  final String label; // Nombre/producto del paso
  final int offsetDays; // Días desde la asignación del plan
  final int? suggestedWithdrawalDays;

  const SanitaryPlanStep({
    required this.type,
    required this.label,
    required this.offsetDays,
    this.suggestedWithdrawalDays,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'label': label,
      'offsetDays': offsetDays,
      if (suggestedWithdrawalDays != null)
        'suggestedWithdrawalDays': suggestedWithdrawalDays,
    };
  }

  factory SanitaryPlanStep.fromMap(Map<String, dynamic> map) {
    return SanitaryPlanStep(
      type: map['type'] as String? ?? 'Tratamiento',
      label: map['label'] as String? ?? 'Sin nombre',
      offsetDays: (map['offsetDays'] as num?)?.toInt() ?? 0,
      suggestedWithdrawalDays:
          (map['suggestedWithdrawalDays'] as num?)?.toInt(),
    );
  }
}

class SanitaryPlan {
  final String id;
  final String name;
  final List<SanitaryPlanStep> steps;
  final DateTime? createdAt;

  const SanitaryPlan({
    required this.id,
    required this.name,
    required this.steps,
    this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'steps': steps.map((s) => s.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory SanitaryPlan.fromFirestore(Map<String, dynamic> data, String id) {
    List<SanitaryPlanStep> parsedSteps = [];
    if (data['steps'] is List) {
      parsedSteps = (data['steps'] as List)
          .map((s) => SanitaryPlanStep.fromMap(s as Map<String, dynamic>))
          .toList();
    }
    return SanitaryPlan(
      id: id,
      name: data['name'] as String? ?? 'Plan sin nombre',
      steps: parsedSteps,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
