// lib/core/life_stage.dart
//
// Categoría de vida por edad (ternero/novillo/adulto), calculada siempre a
// partir de birthDate — nunca se guarda como campo en Firestore, para que
// nunca quede desactualizada (un animal que cumple un año no necesita que
// nadie lo "pase de categoría" a mano). Mismos umbrales que ya usa
// estadisticas_screen.dart, para que ambas pantallas cuenten lo mismo.
import 'package:manual_ganadero_flutter/models/animal.dart';

enum LifeStage { ternero, novillo, adulto, desconocido }

LifeStage computeLifeStage(Animal animal, {DateTime? now}) {
  final birthDate = animal.birthDate;
  if (birthDate == null) return LifeStage.desconocido;
  final ageMonths = (now ?? DateTime.now()).difference(birthDate).inDays / 30.44;
  if (ageMonths < 12) return LifeStage.ternero;
  if (ageMonths < 24) return LifeStage.novillo;
  return LifeStage.adulto;
}

String lifeStageLabel(LifeStage stage) {
  switch (stage) {
    case LifeStage.ternero:
      return 'Ternero/a (< 1 año)';
    case LifeStage.novillo:
      return 'Novillo/Vaquilla (1-2 años)';
    case LifeStage.adulto:
      return 'Adulto (> 2 años)';
    case LifeStage.desconocido:
      return 'Sin fecha de nacimiento';
  }
}
