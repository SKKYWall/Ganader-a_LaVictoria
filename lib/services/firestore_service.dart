import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 🔹 Usuario actual
  static User? get currentUser => _auth.currentUser;

  /// 🔹 Obtener user doc
  static Future<DocumentSnapshot?> getUserDoc() async {
    final user = currentUser;
    if (user == null) return null;

    return await _db.collection('users').doc(user.uid).get();
  }

  /// 🔹 Obtener currentRanchId (Corregido para evitar crasheos)
  static Future<String?> getCurrentRanchId() async {
    final doc = await getUserDoc();
    if (doc == null || !doc.exists) return null;

    // Extraemos la información como un mapa para evitar el error "BAD STATE FIELD"
    final data = doc.data() as Map<String, dynamic>?;
    return data?['currentRanchId'] as String?;
  }

  /// 🔹 Referencia al usuario
  static DocumentReference? userRef() {
    final user = currentUser;
    if (user == null) return null;

    return _db.collection('users').doc(user.uid);
  }

  /// 🔹 Referencia al rancho actual
  static Future<DocumentReference?> ranchRef() async {
    final user = currentUser;
    if (user == null) return null;

    final ranchId = await getCurrentRanchId();
    if (ranchId == null) return null;

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('ranches')
        .doc(ranchId);
  }

  /// 🔹 PRODUCTS
  static Future<CollectionReference?> products() async {
    final ranch = await ranchRef();
    return ranch?.collection('products');
  }

  /// 🔹 ANIMALS
  static Future<CollectionReference?> animals() async {
    final ranch = await ranchRef();
    return ranch?.collection('animals');
  }

  /// 🔹 EVENTS
  static Future<CollectionReference?> events() async {
    final ranch = await ranchRef();
    return ranch?.collection('calendarEvents');
  }
}
