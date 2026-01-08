import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:manual_ganadero_flutter/screens/profile/personal_info_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  String _username = 'Cargando...';
  String _userEmail = 'Cargando...';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _user = FirebaseAuth.instance.currentUser;
      if (_user != null) {
        _userEmail = _user!.email ?? 'Email no disponible';

        // Attempt to fetch username from Firestore
        // This assumes you might store a custom username in a 'users' collection
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();

        if (userDoc.exists && userDoc.data()!.containsKey('name')) {
          // Usar 'name' en lugar de 'username'
          _username = userDoc.data()!['name'];
        } else {
          // Fallback to display name from Firebase Auth if username not in Firestore
          _username = _user!.displayName ?? 'Usuario';
        }
      } else {
        // If no user is logged in, you might want to redirect to login
        // For now, set a message and keep defaults
        _errorMessage = 'No hay usuario autenticado.';
        _username = 'Invitado';
        _userEmail = 'Inicia sesión para ver tu perfil';
      }
    } catch (e) {
      _errorMessage = 'Error al cargar el perfil: $e';
      print('Error al cargar el perfil: $e');
      _username = 'Error';
      _userEmail = 'Error al cargar';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      // After signing out, navigate to the login screen and prevent going back
      if (!mounted) return; // Add mounted check
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
    } catch (e) {
      print('Error al cerrar sesión: $e');
      if (!mounted) return; // Add mounted check
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e')),
      );
    }
  }

  // --- FUNCIÓN PARA CAMBIAR CONTRASEÑA ---
  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay usuario autenticado.')),
      );
      return;
    }

    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmNewPasswordController =
        TextEditingController();

    final dialogFormKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // Usar un BuildContext diferente para el diálogo
        return AlertDialog(
          title: const Text('Cambiar Contraseña',
              style: TextStyle(
                  color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFFfbf6ec),
          surfaceTintColor: const Color(0xFFfbf6ec),
          content: Form(
            key: dialogFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña Actual',
                      prefixIcon:
                          Icon(Icons.lock_outline, color: Color(0xFF5e3a1c)),
                      border:
                          OutlineInputBorder(), // Añadir borde para mejor visualización
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu contraseña actual';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: newPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Nueva Contraseña',
                      prefixIcon: Icon(Icons.lock, color: Color(0xFF5e3a1c)),
                      border: OutlineInputBorder(), // Añadir borde
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa una nueva contraseña';
                      }
                      if (value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: confirmNewPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar Nueva Contraseña',
                      prefixIcon: Icon(Icons.lock, color: Color(0xFF5e3a1c)),
                      border: OutlineInputBorder(), // Añadir borde
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirma tu nueva contraseña';
                      }
                      if (value != newPasswordController.text) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!dialogContext.mounted) {
                  return; // Usar el context del diálogo
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF6b4226))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (dialogFormKey.currentState!.validate()) {
                  if (!dialogContext.mounted) {
                    return; // Usar el context del diálogo
                  }
                  Navigator.of(dialogContext).pop(); // Cierra el diálogo
                  setState(() {
                    _isLoading =
                        true; // Muestra el loading en la pantalla principal
                  });

                  try {
                    // Re-autenticar al usuario
                    AuthCredential credential = EmailAuthProvider.credential(
                      email: user.email!,
                      password: currentPasswordController.text,
                    );
                    await user.reauthenticateWithCredential(credential);

                    // Actualizar la contraseña
                    await user.updatePassword(newPasswordController.text);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Contraseña actualizada exitosamente!')),
                    );
                  } on FirebaseAuthException catch (e) {
                    String message;
                    if (e.code == 'wrong-password') {
                      message = 'Contraseña actual incorrecta.';
                    } else if (e.code == 'too-many-requests') {
                      message =
                          'Demasiados intentos fallidos. Intenta de nuevo más tarde.';
                    } else if (e.code == 'requires-recent-login') {
                      message =
                          'Esta operación requiere una autenticación reciente. Inicia sesión de nuevo y reintenta.';
                    } else if (e.code == 'weak-password') {
                      message =
                          'La nueva contraseña es demasiado débil. Usa una más segura.';
                    } else {
                      message = 'Error al cambiar contraseña: ${e.message}';
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error inesperado: $e')),
                    );
                  } finally {
                    // Limpia los controladores del diálogo independientemente del éxito o fracaso
                    currentPasswordController.dispose();
                    newPasswordController.dispose();
                    confirmNewPasswordController.dispose();

                    if (!mounted) return;
                    setState(() {
                      _isLoading = false; // Oculta el loading
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6b4226),
                foregroundColor: Colors.white,
              ),
              child: const Text('Cambiar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFfbf6ec),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6b4226)),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFfbf6ec),
        appBar: AppBar(
          title:
              const Text('Perfil', style: TextStyle(color: Color(0xFF5e3a1c))),
          backgroundColor: const Color(0xFFfbf6ec),
          iconTheme: const IconThemeData(color: Color(0xFF5e3a1c)),
          elevation: 0,
        ),
        body: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Color(0xFFE53935), fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec), // Color de fondo claro
      appBar: AppBar(
        backgroundColor: const Color(0xFFfbf6ec),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF5e3a1c)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Perfil',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5e3a1c),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Sección de la imagen de perfil y nombre (Mejor formato)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFc99450).withOpacity(0.3),
                    // Display user's photoURL if available, otherwise a generic icon
                    backgroundImage: _user?.photoURL != null
                        ? NetworkImage(_user!.photoURL!)
                        : null,
                    child: _user?.photoURL == null
                        ? Icon(
                            Icons.person,
                            size: 60,
                            color: const Color(0xFF5e3a1c).withOpacity(0.8),
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _username, // Display fetched username
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5e3a1c),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _userEmail, // Display fetched email
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors
                          .grey[700], // Darker grey for better readability
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Sección de Configuración de la cuenta
            _buildSectionHeader('Configuración de la cuenta'),
            _buildCardContainer([
              _buildProfileOption(
                context,
                icon: Icons.account_circle,
                text: 'Información de la Cuenta',
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (context) => const PersonalInfoScreen(),
                        ),
                      )
                      .then((_) =>
                          _loadUserProfile()); // Recargar perfil al regresar de PersonalInfo
                },
              ),
              _buildDivider(),
              _buildProfileOption(
                context,
                icon: Icons.lock,
                text: 'Cambiar Contraseña',
                onTap: _changePassword, // Llama a la nueva función
              ),
              _buildDivider(),
              _buildProfileOption(
                context,
                icon: Icons.notifications,
                text: 'Notificaciones',
                onTap: () {
                  print('Notificaciones Presionado');
                  // Aquí iría la navegación a la pantalla de notificaciones
                },
              ),
              _buildDivider(),
              _buildProfileOption(
                context,
                icon: Icons.privacy_tip,
                text: 'Privacidad',
                onTap: () {
                  print('Privacidad Presionado');
                  // Aquí iría la navegación a la pantalla de privacidad
                },
              ),
            ]),

            const SizedBox(height: 20),

            // Sección de Más Opciones
            _buildSectionHeader('Más Opciones'),
            _buildCardContainer([
              _buildProfileOption(
                context,
                icon: Icons.credit_card,
                text: 'Métodos de Pago',
                onTap: () {
                  print('Métodos de Pago Presionado');
                  // Aquí iría la navegación a la pantalla de métodos de pago
                },
              ),
              _buildDivider(),
              _buildProfileOption(
                context,
                icon: Icons.star,
                text: 'Mis Beneficios', // Cambiado de "Your Promos"
                onTap: () {
                  print('Mis Beneficios Presionado');
                  // Aquí iría la navegación a la pantalla de beneficios
                },
              ),
              _buildDivider(),
              _buildProfileOption(
                context,
                icon: Icons.help,
                text: 'Centro de Ayuda',
                onTap: () {
                  print('Centro de Ayuda Presionado');
                  // Aquí iría la navegación a la pantalla de centro de ayuda
                },
              ),
              _buildDivider(),
              _buildProfileOption(
                context,
                icon: Icons.info,
                text: 'Acerca de',
                onTap: () {
                  print('Acerca de Presionado');
                  // Aquí iría la navegación a la pantalla "Acerca de"
                },
              ),
            ]),

            const SizedBox(height: 30),

            // Botón de Cerrar Sesión (Mejor formato, integrado con _buildProfileOption)
            _buildCardContainer([
              // Wrap logout in a card for consistent styling
              _buildProfileOption(
                context,
                icon: Icons.logout,
                text: 'Cerrar Sesión',
                onTap: _signOut, // Call the signOut method
                isDestructive: true, // Mark as destructive for red color
              ),
            ]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- Widgets de utilidad para construir la pantalla ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5e3a1c),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isDestructive = false, // Added for logout button styling
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? Colors.red
                  : const Color(0xFF5e3a1c), // Apply red color for destructive
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: isDestructive ? Colors.red : const Color(0xFF5e3a1c),
                  fontWeight:
                      FontWeight.w500, // Slightly bolder for better readability
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Colors.grey,
    );
  }
}
