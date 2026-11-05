// lib/core/reproductive_utils.dart
//
// Gestación bovina promedio, usada para estimar la fecha de parto a partir
// de la fecha de servicio (monta natural o inseminación). Antes este valor
// estaba repetido en 3 lugares distintos (animal_detail_screen.dart,
// reproductora_screen.dart, edit_animal_screen.dart) y uno de ellos usaba
// 276 días en vez de 283 — una sola fuente evita que vuelvan a divergir.
const int kGestationDays = 283;

DateTime expectedCalvingDate(DateTime serviceDate) {
  return serviceDate.add(const Duration(days: kGestationDays));
}
