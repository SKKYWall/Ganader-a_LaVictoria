// lib/core/withdrawal_utils.dart
//
// Una sola fuente de verdad para "¿cuántos días faltan de retiro?", usada en
// sanidad_screen.dart y animal_detail_screen.dart. Compara solo la fecha de
// calendario (sin hora) para no sesgar el resultado según la hora del día en
// que se aplicó el tratamiento.
int daysUntilRelease(DateTime releaseDate, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final release = _dateOnly(releaseDate);
  return release.difference(today).inDays;
}

bool isInWithdrawal(DateTime releaseDate, {DateTime? now}) {
  return daysUntilRelease(releaseDate, now: now) > 0;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
