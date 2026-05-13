import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:manual_ganadero_flutter/services/firestore_service.dart'; // Ajusta la ruta si es diferente

class ModuleService {
  static Future<Set<String>> getUnlockedPurposes() async {
    // Usamos tu nuevo FirestoreService para obtener la colección de animales del rancho activo
    final animalsRef = await FirestoreService.animals();

    if (animalsRef == null) return {}; // Si no hay rancho activo, retorna vacío

    final snapshot = await animalsRef.get();

    // Recolecta todos los propósitos únicos registrados (ej: {'Leche', 'Carne'})
    return snapshot.docs
        .map(
            (doc) => (doc.data() as Map<String, dynamic>)['purpose'] as String?)
        .where((p) => p != null)
        .cast<String>()
        .toSet();
  }
}
