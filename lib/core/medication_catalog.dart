// lib/core/medication_catalog.dart
//
// Catálogo de referencia para sugerir un periodo de retiro al aplicar un
// tratamiento en sanidad_screen.dart. NO son valores definitivos: el periodo
// de retiro real depende de la formulación exacta del producto (ej. la
// ivermectina inyectable va de 28 a 122 días en carne según el fabricante),
// así que esto solo rellena un punto de partida razonable y SIEMPRE editable
// — nunca debe tratarse como la verdad del producto que el usuario realmente
// está aplicando.
class MedicationReference {
  final String name;
  final int suggestedWithdrawalDaysMeat;
  final int? suggestedWithdrawalDaysMilk;
  final String note;

  const MedicationReference({
    required this.name,
    required this.suggestedWithdrawalDaysMeat,
    this.suggestedWithdrawalDaysMilk,
    required this.note,
  });
}

/// Agrupado por el mismo `_medTypes` que ya usa sanidad_screen.dart
/// (Vacuna, Desparasitante, Antibiótico, Vitamina, Tratamiento).
const Map<String, List<MedicationReference>> medicationCatalog = {
  'Vacuna': [
    MedicationReference(
      name: 'Vacuna viral/bacteriana común (ej. triple, clostridial)',
      suggestedWithdrawalDaysMeat: 21,
      suggestedWithdrawalDaysMilk: 0,
      note: 'Varía por fabricante — revisa la etiqueta de tu producto.',
    ),
  ],
  'Desparasitante': [
    MedicationReference(
      name: 'Ivermectina inyectable',
      suggestedWithdrawalDaysMeat: 45,
      note:
          'El rango real reportado va de 28 a 122 días en carne según la formulación — '
          'confirma el periodo exacto en la etiqueta. No se recomienda en vacas '
          'lactando para consumo humano salvo que el producto lo indique.',
    ),
    MedicationReference(
      name: 'Desparasitante interno (albendazol/levamisol y similares)',
      suggestedWithdrawalDaysMeat: 14,
      suggestedWithdrawalDaysMilk: 3,
      note: 'Valor de referencia general — verifica tu producto específico.',
    ),
  ],
  'Antibiótico': [
    MedicationReference(
      name: 'Oxitetraciclina',
      suggestedWithdrawalDaysMeat: 21,
      suggestedWithdrawalDaysMilk: 6,
      note: 'Valor típico reportado para bovinos.',
    ),
    MedicationReference(
      name: 'Enrofloxacina',
      suggestedWithdrawalDaysMeat: 30,
      suggestedWithdrawalDaysMilk: 3,
      note: 'Algunos productos reportan 7 días en carne — depende del fabricante.',
    ),
    MedicationReference(
      name: 'Penicilina (acción corta)',
      suggestedWithdrawalDaysMeat: 6,
      suggestedWithdrawalDaysMilk: 1,
      note: 'Valor típico de referencia para acción corta.',
    ),
    MedicationReference(
      name: 'Antibiótico de acción larga (genérico)',
      suggestedWithdrawalDaysMeat: 21,
      suggestedWithdrawalDaysMilk: 45,
      note: 'El retiro en leche puede ser más largo que en carne para esta familia.',
    ),
  ],
  'Vitamina': [
    MedicationReference(
      name: 'Vitaminas/minerales',
      suggestedWithdrawalDaysMeat: 0,
      suggestedWithdrawalDaysMilk: 0,
      note: 'Generalmente sin periodo de retiro, salvo que el producto indique otra cosa.',
    ),
  ],
};

const String medicationCatalogDisclaimer =
    'Periodo de referencia general — siempre confirma el periodo de retiro '
    'impreso en la etiqueta de tu producto específico, puede variar mucho '
    'según el fabricante y la formulación.';
