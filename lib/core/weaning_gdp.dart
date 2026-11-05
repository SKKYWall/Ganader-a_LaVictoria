// lib/core/weaning_gdp.dart
//
// Ganancia diaria de peso (GDP) entre nacimiento y destete. Usa la fecha
// real del registro de peso en animal.stats cuyo valor coincide con el
// peso al destete capturado (dentro de una tolerancia razonable) en vez de
// asumir siempre 205 días — ese valor estándar de la industria solo se usa
// como respaldo cuando no hay un registro de peso fechado que coincida, y
// el resultado siempre indica cuál de los dos se usó.
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:manual_ganadero_flutter/models/animal_stat.dart';

const int defaultWeaningAgeDays = 205;
const double weightMatchToleranceKg = 5.0;

class WeaningGdpResult {
  final double gramsPerDay;
  final bool usedRealWeaningDate;
  const WeaningGdpResult(this.gramsPerDay, this.usedRealWeaningDate);
}

int? _resolveWeaningDays(Animal animal) {
  if (animal.birthDate == null || animal.weaningWeight == null) return null;
  final weightStats = animal.stats
      .where((s) => s.label == 'Peso' || s.label.startsWith('Peso '))
      .toList();
  if (weightStats.isEmpty) return null;

  AnimalStat? closest;
  double closestDiff = double.infinity;
  for (final s in weightStats) {
    final diff = (s.value - animal.weaningWeight!).abs();
    if (diff < closestDiff) {
      closestDiff = diff;
      closest = s;
    }
  }
  if (closest == null || closestDiff > weightMatchToleranceKg) return null;

  final days = closest.date.difference(animal.birthDate!).inDays;
  return days > 0 ? days : null;
}

/// Null si falta peso al nacer o al destete. gramsPerDay puede ser negativo
/// si los datos capturados son inconsistentes — eso debe mostrarse como
/// alerta, no ocultarse.
WeaningGdpResult? calculateWeaningGdp(Animal animal) {
  if (animal.birthWeight == null || animal.weaningWeight == null) return null;
  final realDays = _resolveWeaningDays(animal);
  final days = realDays ?? defaultWeaningAgeDays;
  if (days <= 0) return null;
  final kgPerDay = (animal.weaningWeight! - animal.birthWeight!) / days;
  return WeaningGdpResult(kgPerDay * 1000, realDays != null);
}
