// lib/core/pedigree.dart
//
// Resolución de pedigrí y cálculo del coeficiente de consanguinidad de
// Wright para la cría resultante de cruzar dos animales candidatos. Usa el
// campo father/mother de Animal (que guarda el earTagNumber del progenitor
// real, o un texto libre si el progenitor no está en el sistema — ver
// animal_parent_picker.dart) para subir hasta 3 generaciones por cada lado.
//
// El cálculo asume que los ancestros de la generación base (los que no se
// pudieron verificar más allá de 3 generaciones) no están emparentados
// entre sí — la simplificación estándar de "path counting" que usan las
// calculadoras de consanguinidad de campo cuando no se cuenta con un
// pedigrí completo certificado. Por eso el resultado siempre se acompaña
// de cuántos de los ancestros dentro de esas 3 generaciones realmente se
// pudieron verificar: un F de 0 con poca genealogía verificada NO es lo
// mismo que un F de 0 con genealogía completa.
import 'package:manual_ganadero_flutter/models/animal.dart';

/// Índice por earTagNumber (recortado, no vacío, distinto de 'N/A') —
/// incluye animales de CUALQUIER estado (activo/inactivo), porque el
/// pedigrí de un animal archivado sigue siendo real.
Map<String, Animal> buildEarTagIndex(List<Animal> animals) {
  final index = <String, Animal>{};
  for (final a in animals) {
    final tag = a.earTagNumber.trim();
    if (tag.isEmpty || tag == 'N/A') continue;
    index[tag] = a;
  }
  return index;
}

class PedigreeWalkResult {
  /// earTagNumber de un ancestro real (resuelto en el sistema) -> la
  /// generación MÁS CERCANA en la que se encontró (0 = el propio animal).
  final Map<String, int> resolvedGenerations;

  /// Cuántos de las referencias padre/madre dentro de las generaciones
  /// recorridas tienen al menos un nombre/arete capturado (resuelto o
  /// texto manual).
  final int knownSlots;

  /// Total de referencias padre/madre posibles dentro de las generaciones
  /// recorridas (fijo: 2 + 4 + 8 = 14 para 3 generaciones).
  final int totalSlots;

  const PedigreeWalkResult(
      this.resolvedGenerations, this.knownSlots, this.totalSlots);
}

/// Sube por father/mother desde [start] hasta [maxGenerations] generaciones.
/// Cuenta como "conocido" cualquier referencia con texto (aunque no resuelva
/// a un animal real del sistema), pero solo los que SÍ resuelven a un
/// animal real quedan en [PedigreeWalkResult.resolvedGenerations] — un
/// nombre manual coincidente entre dos árboles (ej. "Toro Externo" en
/// ambos) no debe contarse como un ancestro común real.
PedigreeWalkResult walkAncestors(
  Animal start,
  Map<String, Animal> byEarTag, {
  int maxGenerations = 3,
}) {
  final resolved = <String, int>{};
  int knownSlots = 0;
  int totalSlots = 0;

  final startTag = start.earTagNumber.trim();
  if (startTag.isNotEmpty && startTag != 'N/A') {
    resolved[startTag] = 0;
  }

  void walk(Animal? node, int generation) {
    if (generation > maxGenerations) return;
    final refs = [node?.father, node?.mother];
    for (final ref in refs) {
      totalSlots++;
      final tag = ref?.trim();
      Animal? next;
      if (tag != null && tag.isNotEmpty) {
        knownSlots++;
        next = byEarTag[tag];
        if (next != null) {
          final key = next.earTagNumber.trim();
          final existing = resolved[key];
          if (existing == null || generation < existing) {
            resolved[key] = generation;
          }
        }
      }
      walk(next, generation + 1);
    }
  }

  walk(start, 1);
  return PedigreeWalkResult(resolved, knownSlots, totalSlots);
}

enum InbreedingRisk { none, low, moderate, high, critical }

class InbreedingResult {
  final double coefficient; // F de Wright de la cría resultante
  final InbreedingRisk risk;
  final int knownAncestorSlots;
  final int totalAncestorSlots;

  const InbreedingResult({
    required this.coefficient,
    required this.risk,
    required this.knownAncestorSlots,
    required this.totalAncestorSlots,
  });

  /// Qué tan completa estaba la genealogía disponible para este cálculo —
  /// relevante para no dar falsa tranquilidad cuando coefficient == 0 pero
  /// casi no había pedigrí capturado.
  double get pedigreeCompleteness =>
      totalAncestorSlots == 0 ? 0 : knownAncestorSlots / totalAncestorSlots;

  String get riskLabel {
    switch (risk) {
      case InbreedingRisk.critical:
        return 'CRÍTICO';
      case InbreedingRisk.high:
        return 'ALTO';
      case InbreedingRisk.moderate:
        return 'MODERADO';
      case InbreedingRisk.low:
        return 'BAJO';
      case InbreedingRisk.none:
        return 'SIN RELACIÓN DETECTADA';
    }
  }
}

InbreedingRisk _classify(double f) {
  if (f >= 0.25) return InbreedingRisk.critical;
  if (f >= 0.125) return InbreedingRisk.high;
  if (f >= 0.0625) return InbreedingRisk.moderate;
  if (f > 0) return InbreedingRisk.low;
  return InbreedingRisk.none;
}

/// Coeficiente de consanguinidad (F) de la cría hipotética de cruzar
/// [candidateFather] (semental) con [candidateMother] (vientre), sumando
/// (1/2)^(n1+n2+1) por cada ancestro que ambos comparten dentro de
/// [maxGenerations] generaciones — n1 = generaciones del padre a ese
/// ancestro, n2 = generaciones de la madre a ese ancestro (0 si el propio
/// padre o madre ES ese ancestro, ej. un caso abuelo-nieto).
InbreedingResult calculateInbreeding(
  Animal candidateFather,
  Animal candidateMother,
  Map<String, Animal> byEarTag, {
  int maxGenerations = 3,
}) {
  final fatherWalk =
      walkAncestors(candidateFather, byEarTag, maxGenerations: maxGenerations);
  final motherWalk =
      walkAncestors(candidateMother, byEarTag, maxGenerations: maxGenerations);

  double f = 0;
  for (final entry in fatherWalk.resolvedGenerations.entries) {
    final n2 = motherWalk.resolvedGenerations[entry.key];
    if (n2 == null) continue;
    final n1 = entry.value;
    f += 1 / (1 << (n1 + n2 + 1)); // (1/2)^(n1+n2+1)
  }

  return InbreedingResult(
    coefficient: f,
    risk: _classify(f),
    knownAncestorSlots: fatherWalk.knownSlots + motherWalk.knownSlots,
    totalAncestorSlots: fatherWalk.totalSlots + motherWalk.totalSlots,
  );
}
