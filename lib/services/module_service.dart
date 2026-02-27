import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModuleService {
  static Future<Set<String>> getUnlockedPurposes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('animals')
        .get();

    // Recolecta todos los propósitos únicos registrados (ej: {'Leche', 'Carne'})
    return snapshot.docs
        .map((doc) => doc.data()['purpose'] as String?)
        .where((p) => p != null)
        .cast<String>()
        .toSet();
  }
}
