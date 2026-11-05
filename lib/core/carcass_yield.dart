// lib/core/carcass_yield.dart
//
// Estimación de rendimiento en canal (% de peso vivo que queda como canal
// limpia) ANTES de pesar en el rastro. Reemplaza un 58% fijo para todos los
// animales por una tabla que al menos distingue por grupo racial y sexo,
// basada en literatura zootécnica general:
//   - Razas de carne especializadas: 60-62% (se usa 60% como punto conservador)
//   - Razas lecheras: 58-60% (Holstein específicamente citado en ese rango)
//   - Cebú/Bos indicus: rendimiento menor por menor marmoleo/mayor peso de
//     vísceras; cruzas Cebú×lechera documentadas en ~47-49% en campo
//   - Cruza/otro: valor intermedio
// Esto SIGUE siendo una estimación de planeación, no sustituye el peso real
// en báscula — por eso el diálogo de envío al rastro (engorda_screen.dart)
// siempre pide y usa el peso en canal real cuando ya se tiene.
import 'package:manual_ganadero_flutter/core/breed_groups.dart';

const Map<BreedGroup, double> _baseYield = {
  BreedGroup.continental: 0.60,
  BreedGroup.lechera: 0.58,
  BreedGroup.cebu: 0.52,
  BreedGroup.cruzaOtro: 0.55,
};

/// Ajuste conservador por sexo: los machos (toros/novillos) suelen rendir
/// un poco más que las hembras a igual edad/raza.
const double _maleAdjustment = 0.015;

double carcassYieldFor(String? breed, String? sex) {
  final group = breedGroupOf(breed);
  final base = _baseYield[group] ?? 0.55;
  final isMale = sex?.trim() == 'Macho';
  return isMale ? base + _maleAdjustment : base;
}
