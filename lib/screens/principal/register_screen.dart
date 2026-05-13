// lib/screens/principal/register_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:manual_ganadero_flutter/screens/profile/ranch_setup_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:manual_ganadero_flutter/services/auth_service.dart'; // <-- NUEVA IMPORTACIÓN

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- REFACTORIZADO: Seguridad Fuerte y uso de AuthService ---
  void _register() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showAlert('Atención',
          'Por favor, completa el correo electrónico y la contraseña.');
      return;
    }

    // --- NUEVAS REGLAS DE SEGURIDAD PARA LA CONTRASEÑA ---
    if (password.length < 8) {
      _showAlert('Contraseña débil',
          'La contraseña debe tener al menos 8 caracteres.');
      return;
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      _showAlert('Contraseña débil',
          'La contraseña debe contener al menos una letra mayúscula.');
      return;
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      _showAlert('Contraseña débil',
          'La contraseña debe contener al menos un número.');
      return;
    }
    // -----------------------------------------------------

    setState(() => _isLoading = true);

    // 1. Registrar usuario en Firebase Auth a través del Servicio
    final result = await AuthService().registerUser(email, password);

    if (result['error'] != null) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showAlert('Error al registrar', result['error']);
      }
      return;
    }

    // 2. Si tuvo éxito, creamos su documento base en Firestore
    try {
      User user = result['user'];
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'displayName': 'Usuario', // Nombre por defecto
        'photoURL': null,
        'createdAt': FieldValue.serverTimestamp(),
        'setupCompleted': false, // Aún no configura su rancho
      });

      if (mounted) {
        _showAlert('Registro exitoso', 'Tu cuenta ha sido creada. ¡Bienvenido!',
            () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const RanchSetupScreen()),
          );
        });
      }
    } catch (e) {
      if (mounted)
        _showAlert('Error', 'No se pudo crear el perfil del usuario: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Registro con Google ---
  Future<void> _registerWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut(); // Forzamos la selección de cuenta

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // Canceló
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userDoc =
            await _db.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          // Es su primera vez usando Google en la app, creamos su perfil
          await _db.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'displayName': user.displayName ?? 'Usuario',
            'photoURL': user.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
            'setupCompleted': false,
          });

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const RanchSetupScreen()),
            );
          }
        } else {
          // Si ya existía, actuamos como Login y validamos si tiene ranchos
          QuerySnapshot ranchesSnapshot = await _db
              .collection('users')
              .doc(user.uid)
              .collection('ranches')
              .limit(1)
              .get();

          if (mounted) {
            if (ranchesSnapshot.docs.isEmpty) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const RanchSetupScreen()),
              );
            } else {
              Navigator.pushReplacementNamed(context, '/dashboard');
            }
          }
        }
      }
    } catch (e) {
      if (mounted) _showAlert('Error de registro con Google', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Función de Alertas ---
  void _showAlert(String title, String content, [VoidCallback? onClose]) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xfffbf6ec),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xff5e3a1c))),
        content: Text(content, style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            child: const Text('Entendido',
                style: TextStyle(
                    color: Color(0xFFc99450), fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(context);
              if (onClose != null) {
                onClose();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffbf6ec),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image.asset(
                  'assets/LogoModificado.jpg',
                  width: 180,
                  height: 180,
                ),
                const SizedBox(height: 30),
                const Text(
                  'Registrarse',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff5e3a1c),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context)
                            .pushReplacementNamed('/login'),
                        child: Column(
                          children: [
                            const Text(
                              'Sign in',
                              style: TextStyle(
                                  fontSize: 18, color: Color(0xFFd9c7ae)),
                            ),
                            const SizedBox(height: 5),
                            Container(
                                height: 3,
                                width: 70,
                                color: Colors.transparent),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Sign up',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6b4226)),
                          ),
                          const SizedBox(height: 5),
                          Container(
                              height: 3,
                              width: 70,
                              color: const Color(0xFF6b4226)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    labelText: 'Email',
                    labelStyle: const TextStyle(color: Color(0xFFd9c7ae)),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFd9c7ae)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF6b4226)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: const Icon(Icons.email_outlined,
                        color: Color(0xFFd9c7ae)),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  decoration: InputDecoration(
                    hintText: '********',
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Color(0xFFd9c7ae)),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFd9c7ae)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF6b4226)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFFd9c7ae),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFc99450),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white))
                      : const Text(
                          'Sign up',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                ),
                const SizedBox(height: 30),
                const Text('OR', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSocialButton('assets/google_logo.png',
                        _isLoading ? () {} : _registerWithGoogle),
                    const SizedBox(width: 20),
                    _buildSocialButton('assets/facebook_logo.png', () {
                      _showAlert('Función no disponible',
                          'Por favor, regístrate con correo y contraseña o Google.');
                    }),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    const Text('By signing up, I agree with the ',
                        style: TextStyle(color: Colors.grey)),
                    GestureDetector(
                      onTap: () {
                        _showAlert('Términos y Condiciones',
                            'Aquí irán las políticas de privacidad y uso de la aplicación.');
                      },
                      child: const Text(
                        'T&C & Privacy Policy',
                        style: TextStyle(
                            color: Color(0xFF6b4226),
                            decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(String imagePath, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Image.asset(imagePath),
      ),
    );
  }
}
