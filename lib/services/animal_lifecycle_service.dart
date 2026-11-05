// lib/services/animal_lifecycle_service.dart
//
// Punto único para dar de baja a un animal (vendido, sacrificado o muerto)
// sin borrar su registro. Lo usan los 3 lugares donde un animal sale del
// hato activo: animal_detail_screen.dart (baja manual), el "marcar como
// vendido" del Marketplace, y el envío al rastro en engorda_screen.dart —
// para que la lógica de "qué pasa al dar de baja" viva en un solo lugar.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';

class AnimalLifecycleService {
  static final _db = FirebaseFirestore.instance;

  /// Marca al animal como inactivo y, si aplica, registra el ingreso en
  /// Finanzas y cierra cualquier publicación de Marketplace ligada a él.
  /// No borra nada — el animal y su historial siguen existiendo.
  static Future<void> recordExit({
    required Animal animal,
    required String userId,
    required String ranchId,
    required String reason, // 'vendido' | 'sacrificado' | 'muerto'
    required DateTime date,
    double? price,
    String? notes,
  }) async {
    final ranchRef =
        _db.collection('users').doc(userId).collection('ranches').doc(ranchId);
    final animalRef = ranchRef.collection('animals').doc(animal.id);

    final batch = _db.batch();

    batch.update(animalRef, {
      'status': 'inactivo',
      'exitReason': reason,
      'exitDate': Timestamp.fromDate(date),
      if (price != null) 'exitPrice': price,
      if (notes != null && notes.isNotEmpty) 'exitNotes': notes,
    });

    if (price != null && price > 0) {
      final transactionRef = ranchRef.collection('transactions').doc();
      batch.set(transactionRef, {
        'type': 'income',
        'amount': price,
        'category': 'Venta de Animales',
        'subCategory': 'Bovinos',
        'notes': 'Venta de ${animal.name} (arete ${animal.earTagNumber})'
            '${notes != null && notes.isNotEmpty ? ' — $notes' : ''}',
        'date': Timestamp.fromDate(date),
        'animalId': animal.id,
      });
    }

    // Si el animal tiene una publicación activa en el Marketplace, se marca
    // como vendida en vez de borrarla (el vendedor conserva el historial).
    final listingQuery = await _db
        .collection('marketplace_listings')
        .where('animalId', isEqualTo: animal.id)
        .where('ownerId', isEqualTo: userId)
        .where('status', isEqualTo: 'activo')
        .limit(1)
        .get();
    for (final doc in listingQuery.docs) {
      batch.update(doc.reference, {'status': 'vendido'});
    }

    await batch.commit();
  }
}
