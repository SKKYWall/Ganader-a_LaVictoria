// lib/core/breed_groups.dart
//
// Clasifica cualquier raza bovina registrada en la app en un grupo racial
// amplio. Se usa donde una fórmula necesita un comportamiento distinto por
// tipo de ganado (rendimiento en canal, DEP por contemporáneos, heterosis en
// el simulador de cruzas) pero no tiene suficiente dato para ser más fino que
// esto sin inventar precisión que no existe.
//
// Las razas vienen de las listas ya usadas en register_animal_screen.dart y
// edit_animal_screen.dart. Beefmaster y Santa Gertrudis son composites con
// ascendencia Brahman, pero se comercializan y manejan como razas de carne
// especializadas en México, así que se agrupan con 'continental' en vez de
// crear una quinta categoría.
enum BreedGroup { continental, cebu, lechera, cruzaOtro }

const Map<String, BreedGroup> _breedGroupMap = {
  // Carne especializada (Bos taurus continental + composites de carne)
  'Angus': BreedGroup.continental,
  'Hereford': BreedGroup.continental,
  'Charolais': BreedGroup.continental,
  'Simmental': BreedGroup.continental,
  'Limousin': BreedGroup.continental,
  'Beefmaster': BreedGroup.continental,
  'Santa Gertrudis': BreedGroup.continental,
  'Texas Longhorn': BreedGroup.continental,

  // Cebú / Bos indicus
  'Nelore': BreedGroup.cebu,
  'Brahman': BreedGroup.cebu,
  'Brahman Rojo': BreedGroup.cebu,
  'Guzerat': BreedGroup.cebu,
  'Indubrasil': BreedGroup.cebu,
  'Cebú': BreedGroup.cebu,

  // Lecheras
  'Holstein': BreedGroup.lechera,
  'Jersey': BreedGroup.lechera,
  'Suizo Pardo': BreedGroup.lechera,

  // Cruzas explícitas / sin raza definida
  'Brangus': BreedGroup.cruzaOtro,
  'Otro': BreedGroup.cruzaOtro,
};

BreedGroup breedGroupOf(String? breed) {
  if (breed == null) return BreedGroup.cruzaOtro;
  return _breedGroupMap[breed.trim()] ?? BreedGroup.cruzaOtro;
}

String breedGroupLabel(BreedGroup group) {
  switch (group) {
    case BreedGroup.continental:
      return 'Carne especializada';
    case BreedGroup.cebu:
      return 'Cebú';
    case BreedGroup.lechera:
      return 'Lechera';
    case BreedGroup.cruzaOtro:
      return 'Cruza / otro';
  }
}
