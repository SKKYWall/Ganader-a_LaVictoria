// lib/screens/principal/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:manual_ganadero_flutter/screens/profile/ranch_setup_screen.dart'; // Ajusta la ruta
import 'package:manual_ganadero_flutter/services/auth_service.dart'; // <-- NUEVA IMPORTACIÓN

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
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

  // --- REFACTORIZADO: Usa AuthService ---
  Future<void> _signInWithEmailAndPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // 1. Llamamos a nuestro servicio centralizado
      final result = await AuthService().loginUser(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (result['error'] != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showAlert('Error', result['error']);
        }
        return; // Salimos si hubo error
      }

      // 2. Si el login fue exitoso, verificamos su perfil
      try {
        User user = result['user'];
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists &&
            (userDoc.data() as Map<String, dynamic>)['setupCompleted'] ==
                true) {
          // Ya configuró su rancho
          if (mounted) Navigator.of(context).pushReplacementNamed('/dashboard');
        } else {
          // A configurar el rancho
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const RanchSetupScreen()),
            );
          }
        }
      } catch (e) {
        if (mounted)
          _showAlert('Error', 'Ocurrió un error al cargar tus datos: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- REFACTORIZADO: Diálogo para recuperar contraseña ---
  Future<void> _showForgotPasswordDialog() async {
    // Si ya había escrito algo en el correo, lo pre-llenamos
    final TextEditingController resetEmailController =
        TextEditingController(text: _emailController.text.trim());

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFFfbf6ec),
            title: const Text('Recuperar contraseña',
                style: TextStyle(
                    color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold)),
            content: TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Ingresa tu correo',
                prefixIcon: const Icon(Icons.email, color: Color(0xFFc99450)),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF6b4226)),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar',
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final email = resetEmailController.text.trim();
                  if (email.isNotEmpty) {
                    Navigator.pop(context); // Cierra el diálogo
                    setState(() => _isLoading = true);

                    // Llama al servicio central
                    final error = await AuthService().resetPassword(email);

                    if (mounted) setState(() => _isLoading = false);

                    if (mounted) {
                      if (error == null) {
                        _showAlert('¡Correo enviado!',
                            'Revisa tu bandeja de entrada o spam para restablecer tu contraseña.');
                      } else {
                        _showAlert('Error', error);
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6b4226)),
                child: const Text('Enviar link',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // El usuario canceló
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists &&
          (userDoc.data() as Map<String, dynamic>)['setupCompleted'] == true) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/dashboard');
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const RanchSetupScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted)
        _showAlert('Error', 'No se pudo iniciar sesión con Google: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Alertas ---
  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFfbf6ec),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF5e3a1c))),
        content: Text(message, style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido',
                style: TextStyle(
                    color: Color(0xFFc99450), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Resto del código de UI...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
            child: Form(
              key: _formKey,
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
                    'Iniciar Sesión',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5e3a1c),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Pestañas (solo visuales)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'Sign in',
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
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context)
                              .pushReplacementNamed('/register'),
                          child: Column(
                            children: [
                              const Text(
                                'Sign up',
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
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Campo Correo
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
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Por favor, ingresa tu correo electrónico';
                      if (!value.contains('@'))
                        return 'Por favor, ingresa un correo electrónico válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Campo Contraseña
                  TextFormField(
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
                          _obscureText
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFFd9c7ae),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Por favor, ingresa tu contraseña';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Botón de recuperar contraseña (ACTUALIZADO)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            _isLoading ? null : _showForgotPasswordDialog,
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(color: Color(0xFF6b4226)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Botón Iniciar Sesión
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFc99450),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: const Size(double.infinity, 0),
                    ),
                    onPressed: _isLoading ? null : _signInWithEmailAndPassword,
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : const Text(
                            'Sign in',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                  ),
                  const SizedBox(height: 30),
                  const Text('OR', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),

                  // Botones Sociales
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(
                          'assets/google_logo.png', _signInWithGoogle),
                      const SizedBox(width: 20),
                      _buildSocialButton('assets/facebook_logo.png', () {
                        _showAlert('Información',
                            'El login con Facebook estará disponible pronto.');
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Link a Registro
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushReplacementNamed(context, '/register'),
                    child: const Text(
                      'Don\'t have an account? Sign up',
                      style: TextStyle(
                        color: Color(0xFF6b4226),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
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
