import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:manual_ganadero_flutter/screens/profile/ranch_setup_screen.dart'; // Asegúrate de que la ruta coincida donde guardaste el archivo

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true; // Para alternar la visibilidad de la contraseña

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _register() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showAlert('Error',
          'Por favor, completa el correo electrónico y la contraseña.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': 'Usuario', // Puedes pedir un nombre al usuario
          'photoURL': null,
        });

        _showAlert('Registro exitoso', 'Tu cuenta ha sido creada. ¡Bienvenido!',
            () {
          // Cambiamos el pushReplacementNamed por pushReplacement directo a la pantalla
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const RanchSetupScreen()),
          );
        });
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error al registrar.';
      if (e.code == 'weak-password') {
        errorMessage = 'La contraseña es demasiado débil.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'La cuenta ya existe para ese correo electrónico.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El correo electrónico no es válido.';
      }
      _showAlert('Error al registrar', errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAlert(String title, String content, [VoidCallback? onClose]) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            child: const Text('OK'),
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
        // Usando SafeArea para evitar superposición con barras del sistema
        child: Center(
          child: SingleChildScrollView(
            // Permite hacer scroll si el contenido es demasiado largo
            padding:
                const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo más grande y centrado
                Image.asset(
                  'assets/LogoModificado.jpg',
                  width: 180, // Aumentado el tamaño del logo (de 150 a 180)
                  height: 180, // Aumentado el tamaño del logo (de 150 a 180)
                ),
                const SizedBox(height: 30), // Más espacio después del logo
                const Text(
                  'Registrarse',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff5e3a1c),
                  ),
                ),
                const SizedBox(height: 30),

                // Pestañas "Sign in" y "Sign up"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushReplacementNamed('/login');
                        },
                        child: Column(
                          children: [
                            const Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFFd9c7ae),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              height: 3,
                              width: 70,
                              color: Colors.transparent,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // Ya estamos en Sign Up
                        },
                        child: Column(
                          children: [
                            const Text(
                              'Sign up',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6b4226),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              height: 3,
                              width: 70,
                              color: const Color(0xFF6b4226),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30), // Más espacio antes de los campos

                TextField(
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
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
                  mainAxisAlignment:
                      MainAxisAlignment.center, // Centrar los botones sociales
                  children: [
                    _buildSocialButton('assets/google_logo.png', () {
                      _showAlert('Función no disponible',
                          'Por favor, regístrate con correo y contraseña.');
                    }),
                    const SizedBox(width: 20), // Espacio entre botones
                    _buildSocialButton('assets/facebook_logo.png', () {
                      _showAlert('Función no disponible',
                          'Por favor, regístrate con correo y contraseña.');
                    }),
                  ],
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text(
                    'By signing up, I agree with the',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // Lógica para mostrar términos y condiciones / política de privacidad
                  },
                  child: const Text(
                    'T&C & Privacy Policy',
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
    );
  }

  // Widget para construir los botones sociales
  Widget _buildSocialButton(String imagePath, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(
          30), // Hacer el borde redondeado (para un círculo perfecto, la mitad del tamaño)
      child: Container(
        width: 50, // Tamaño más pequeño para los botones sociales
        height: 50, // Tamaño más pequeño para los botones sociales
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle, // Forma circular
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
        padding: const EdgeInsets.all(
            10), // Padding interno para la imagen (ajustado para el nuevo tamaño)
        child: Image.asset(imagePath),
      ),
    );
  }
}
