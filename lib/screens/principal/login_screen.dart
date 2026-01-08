import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _obscureText = true; // Para alternar la visibilidad de la contraseña

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmailAndPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Si el inicio de sesión es exitoso, navega al dashboard
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Error al iniciar sesión. Inténtalo de nuevo.';
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          errorMessage = 'Correo electrónico o contraseña incorrectos.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'El correo electrónico no es válido.';
        }
        _showErrorDialog(errorMessage);
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return; // El usuario canceló el inicio de sesión de Google.
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      // Aquí podrías crear/actualizar el documento de usuario en Firestore si es necesario
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            {
              'uid': user.uid,
              'email': user.email ?? '',
              'displayName': user.displayName ?? 'Usuario Google',
              'photoURL': user.photoURL,
            },
            SetOptions(
                merge:
                    true)); // Usa merge para no sobrescribir datos existentes
      }
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      print('Error signing in with Google: $error');
      _showErrorDialog('Error al iniciar sesión con Google: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error de Inicio de Sesión'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      body: SafeArea(
        // Usando SafeArea para evitar superposición con barras del sistema
        child: Center(
          child: SingleChildScrollView(
            // Permite hacer scroll si el contenido es demasiado largo
            padding:
                const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Logo más grande y centrado
                  Image.asset(
                    'assets/LogoModificado.jpg', // Reemplaza con la ruta correcta
                    width: 180, // Aumentado el tamaño del logo (de 150 a 180)
                    height: 180, // Aumentado el tamaño del logo (de 150 a 180)
                  ),
                  const SizedBox(height: 30), // Más espacio después del logo
                  // Título "Iniciar Sesión"
                  const Text(
                    'Iniciar Sesión',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5e3a1c),
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
                            // Ya estamos en Sign In
                          },
                          child: Column(
                            children: [
                              const Text(
                                'Sign in',
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
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context)
                                .pushReplacementNamed('/register');
                          },
                          child: Column(
                            children: [
                              const Text(
                                'Sign up',
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
                    ],
                  ),
                  const SizedBox(height: 30), // Más espacio antes de los campos

                  // Campos de texto
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
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingresa tu correo electrónico';
                      }
                      if (!value.contains('@')) {
                        return 'Por favor, ingresa un correo electrónico válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
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
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingresa tu contraseña';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.end, // Alineado a la derecha
                    children: [
                      TextButton(
                        onPressed: () {
                          // Navegar a la pantalla de recuperación de contraseña
                          // Navigator.of(context).pushNamed('ForgotPassword');
                        },
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(color: Color(0xFF6b4226)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment
                        .center, // Centrar los botones sociales
                    children: [
                      _buildSocialButton('assets/google_logo.png',
                          _signInWithGoogle), // Google
                      const SizedBox(width: 20), // Espacio entre botones
                      _buildSocialButton('assets/facebook_logo.png', () {
                        _showErrorDialog('Facebook Login no implementado aún.');
                      }), // Facebook
                    ],
                  ),
                  const SizedBox(height: 20),
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
