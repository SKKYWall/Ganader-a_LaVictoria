// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Registro por Correo y Contraseña
  Future<Map<String, dynamic>> registerUser(
      String email, String password) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      return {'user': userCredential.user, 'error': null};
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error al registrar';
      if (e.code == 'weak-password') {
        errorMessage = 'La contraseña es muy débil. Usa al menos 6 caracteres.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Este correo ya está registrado en otra cuenta.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo no es válido.';
      }
      return {'user': null, 'error': errorMessage};
    } catch (e) {
      return {'user': null, 'error': 'Error inesperado: $e'};
    }
  }

  // 2. Login por Correo y Contraseña
  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return {'user': userCredential.user, 'error': null};
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error al iniciar sesión';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        errorMessage = 'Correo o contraseña incorrectos.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Esta cuenta ha sido deshabilitada.';
      }
      return {'user': null, 'error': errorMessage};
    } catch (e) {
      return {'user': null, 'error': 'Error inesperado: $e'};
    }
  }

  // 3. Recuperación de Contraseña (LA FUNCIÓN QUE FALTABA)
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Retorna null si todo salió bien (sin errores)
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found')
        return 'No hay ningún usuario registrado con este correo.';
      if (e.code == 'invalid-email')
        return 'El correo no tiene un formato válido.';
      return 'Error al enviar el correo de recuperación.';
    } catch (e) {
      return 'Ocurrió un error inesperado al intentar recuperar la cuenta.';
    }
  }

  // 4. Cerrar Sesión (Mejorado para limpiar también Google)
  Future<Map<String, dynamic>> logoutUser() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut(); // Limpia la sesión de Google si la hay
      return {'success': true};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
