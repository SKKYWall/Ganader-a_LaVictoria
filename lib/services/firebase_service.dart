import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; // Asegúrate de generar este archivo con flutterfire configure

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() => _instance;

  FirebaseService._internal();

  late final FirebaseAuth auth;
  late final FirebaseFirestore db;

  Future<void> init() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    auth = FirebaseAuth.instance;
    db = FirebaseFirestore.instance;
  }

  FirebaseAuth getAuth() => auth;
  FirebaseFirestore getFirestore() => db;
}
