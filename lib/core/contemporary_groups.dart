// lib/core/contemporary_groups.dart
//
// Agrupa animales por "contemporáneos" (mismo grupo racial + sexo + año de
// nacimiento) para comparar el peso al destete contra un promedio más
// parecido en vez de un promedio global del hato que mezcla razas, sexos y
// épocas distintas — comparar el destete de un becerro Cebú de este año
// contra el promedio de vacas Holstein de hace 5 años no dice nada útil.
// Si un animal no tiene suficientes contemporáneos reales (se exige un
// mínimo de otros 2 animales en el mismo grupo) o le falta raza/sexo/fecha
// de nacimiento, se usa el promedio general del hato como respaldo —
// siempre indicando cuál de los dos se usó para no aparentar una precisión
// que no existe.
import 'package:manual_ganadero_flutter/core/breed_groups.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';

class ContemporaryGroups {
  final Map<String, List<double>> _weaningByGroup;
  final double overallWeaningAverage;

  static const int minPeersForGroupAverage = 2;

  ContemporaryGroups._(this._weaningByGroup, this.overallWeaningAverage);

  factory ContemporaryGroups.fromAnimals(List<Animal> animals) {
    final withWeaning = animals
        .where((a) => a.weaningWeight != null && a.weaningWeight! > 0)
        .toList();
    final overall = withWeaning.isEmpty
        ? 0.0
        : withWeaning.map((a) => a.weaningWeight!).reduce((a, b) => a + b) /
            withWeaning.length;

    final byGroup = <String, List<double>>{};
    for (final a in withWeaning) {
      final key = _keyFor(a);
      if (key == null) continue;
      byGroup.putIfAbsent(key, () => []).add(a.weaningWeight!);
    }
    return ContemporaryGroups._(byGroup, overall);
  }

  static String? _keyFor(Animal a) {
    final year = a.birthDate?.year;
    if (year == null) return null;
    final sex = a.sex?.trim().toLowerCase() == 'macho' ? 'M' : 'H';
    final group = breedGroupOf(a.breed);
    return '$group|$sex|$year';
  }

  /// Cuántos animales (incluyendo a [animal] si aplica) comparten su mismo
  /// grupo de contemporáneos.
  int groupSizeFor(Animal animal) {
    final key = _keyFor(animal);
    if (key == null) return 0;
    return _weaningByGroup[key]?.length ?? 0;
  }

  /// Promedio de referencia para comparar el destete de [animal] contra su
  /// grupo, y si ese promedio es realmente de contemporáneos (true) o es
  /// el respaldo general del hato (false) por no haber suficientes peers.
  (double average, bool isContemporaryGroup) averageFor(Animal animal) {
    final key = _keyFor(animal);
    if (key != null) {
      final bucket = _weaningByGroup[key];
      // Se exige al propio animal + al menos minPeersForGroupAverage más,
      // para que el promedio del grupo no sea solo "contra sí mismo".
      if (bucket != null && bucket.length >= minPeersForGroupAverage + 1) {
        final avg = bucket.reduce((a, b) => a + b) / bucket.length;
        return (avg, true);
      }
    }
    return (overallWeaningAverage, false);
  }
}
