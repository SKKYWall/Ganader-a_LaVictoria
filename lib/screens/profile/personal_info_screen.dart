import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Para FontAwesomeIcons
// import 'package:url_launcher/url_launcher.dart'; // Si necesitas abrir URLs

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>(); // Clave para el formulario
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controladores para los campos de texto
  late TextEditingController _nameController; // Nuevo: Nombre del usuario
  late TextEditingController _phoneController; // Un solo teléfono
  late TextEditingController
      _emailController; // Email de autenticación (no editable)
  late TextEditingController
      _secondaryEmailController; // Nuevo: Correo electrónico secundario
  late TextEditingController _ranchAddressController; // Dirección del rancho
  late TextEditingController _facebookController; // Para cuentas sociales
  late TextEditingController _instagramController; // Para cuentas sociales
  late TextEditingController _twitterController; // Nuevo: Twitter
  late TextEditingController _whatsappController; // Nuevo: WhatsApp

  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _secondaryEmailController = TextEditingController(); // Inicializado
    _ranchAddressController = TextEditingController();
    _facebookController = TextEditingController();
    _instagramController = TextEditingController();
    _twitterController = TextEditingController();
    _whatsappController = TextEditingController();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _secondaryEmailController.dispose(); // Disposed
    _ranchAddressController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
    });
    try {
      _currentUserId = _auth.currentUser?.uid;
      if (_currentUserId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario no autenticado.')),
        );
        Navigator.of(context).pop();
        return;
      }

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_currentUserId).get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        _nameController.text = userData['name'] ?? '';
        _phoneController.text = userData['phone'] ?? '';
        _emailController.text =
            _auth.currentUser?.email ?? ''; // Siempre del auth
        _secondaryEmailController.text =
            userData['secondaryEmail'] ?? ''; // Cargar email secundario
        _ranchAddressController.text = userData['ranchAddress'] ?? '';

        // Cargar redes sociales desde el mapa anidado
        Map<String, dynamic> socialMediaLinks =
            (userData['socialMediaLinks'] is Map)
                ? Map<String, dynamic>.from(userData['socialMediaLinks'])
                : {};
        _facebookController.text = socialMediaLinks['facebook'] ?? '';
        _instagramController.text = socialMediaLinks['instagram'] ?? '';
        _twitterController.text = socialMediaLinks['twitter'] ?? '';
        _whatsappController.text = socialMediaLinks['whatsapp'] ?? '';
      } else {
        // Si el documento no existe o no tiene datos, inicializa con el email de auth y nombre si existe
        _emailController.text = _auth.currentUser?.email ?? '';
        _nameController.text = _auth.currentUser?.displayName ?? '';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
      print('Error al cargar datos del usuario: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserInfo() async {
    if (!_formKey.currentState!.validate()) {
      return; // No guardar si el formulario no es válido
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_currentUserId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No se pudo guardar: usuario no autenticado.')),
        );
        return;
      }

      // Construir el mapa de redes sociales para guardar
      Map<String, String> socialMediaLinks = {};
      if (_facebookController.text.trim().isNotEmpty) {
        socialMediaLinks['facebook'] = _facebookController.text.trim();
      }
      if (_instagramController.text.trim().isNotEmpty) {
        socialMediaLinks['instagram'] = _instagramController.text.trim();
      }
      if (_twitterController.text.trim().isNotEmpty) {
        socialMediaLinks['twitter'] = _twitterController.text.trim();
      }
      if (_whatsappController.text.trim().isNotEmpty) {
        socialMediaLinks['whatsapp'] = _whatsappController.text.trim();
      }

      await _firestore.collection('users').doc(_currentUserId).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(), // Un solo teléfono
        'email': _emailController.text.trim(), // Este es el de auth
        'secondaryEmail':
            _secondaryEmailController.text.trim(), // Nuevo email secundario
        'ranchAddress': _ranchAddressController.text.trim(),
        'socialMediaLinks': socialMediaLinks,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Información guardada exitosamente!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar datos: $e')),
      );
      print('Error al guardar datos del usuario: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
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
          'Información personal',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5e3a1c),
          ),
        ),
        centerTitle: true,
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF6b4226)),
                    strokeWidth: 2,
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save, color: Color(0xFF5e3a1c)),
                  onPressed: _saveUserInfo,
                ),
        ],
      ),
      body: _isLoading &&
              _nameController.text.isEmpty &&
              _emailController.text.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6b4226)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Datos Personales'),
                    _buildSectionCard(
                      children: [
                        _buildEditableInfoRow(
                          icon: Icons.person,
                          controller: _nameController,
                          labelText: 'Nombre Completo',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El nombre es requerido';
                            }
                            return null;
                          },
                        ),
                        _buildDivider(),
                        _buildEditableInfoRow(
                          icon: Icons.alternate_email,
                          controller: _emailController,
                          labelText:
                              'Correo Electrónico (Principal)', // Etiqueta para el email de Auth
                          keyboardType: TextInputType.emailAddress,
                          readOnly: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El correo electrónico es requerido';
                            }
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                .hasMatch(value)) {
                              return 'Introduce un correo válido';
                            }
                            return null;
                          },
                        ),
                        _buildDivider(),
                        _buildEditableInfoRow(
                          icon: Icons
                              .mail_outline, // Nuevo icono para email secundario
                          controller: _secondaryEmailController,
                          labelText:
                              'Correo Electrónico (Secundario, Opcional)',
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value != null &&
                                value.isNotEmpty &&
                                !RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                    .hasMatch(value)) {
                              return 'Introduce un correo válido';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('Información de Contacto'),
                    _buildSectionCard(
                      children: [
                        _buildEditableInfoRow(
                          icon: Icons.phone,
                          controller: _phoneController,
                          labelText: 'Teléfono de Contacto', // Un solo teléfono
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value != null &&
                                value.isNotEmpty &&
                                !RegExp(r'^\+?[0-9]{7,15}$').hasMatch(value)) {
                              return 'Formato de teléfono inválido';
                            }
                            return null;
                          },
                        ),
                        _buildDivider(),
                        _buildEditableInfoRow(
                          icon: Icons.bungalow,
                          controller: _ranchAddressController,
                          labelText: 'Dirección del Rancho',
                          maxLines: 2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('Cuentas Sociales'),
                    _buildSectionCard(
                      children: [
                        _buildEditableInfoRow(
                          icon: FontAwesomeIcons.facebook,
                          controller: _facebookController,
                          labelText: 'Perfil de Facebook (URL)',
                          suffixIcon: Icons.chevron_right,
                          onSuffixIconTap: () {
                            if (_facebookController.text.isNotEmpty) {
                              _showSnackBar('Abriendo Facebook...');
                              // launchUrl(Uri.parse(_facebookController.text));
                            } else {
                              _showSnackBar(
                                  'No hay URL de Facebook para abrir.');
                            }
                          },
                        ),
                        _buildDivider(),
                        _buildEditableInfoRow(
                          icon: FontAwesomeIcons.instagram,
                          controller: _instagramController,
                          labelText: 'Perfil de Instagram (URL)',
                          suffixIcon: Icons.chevron_right,
                          onSuffixIconTap: () {
                            if (_instagramController.text.isNotEmpty) {
                              _showSnackBar('Abriendo Instagram...');
                              // launchUrl(Uri.parse(_instagramController.text));
                            } else {
                              _showSnackBar(
                                  'No hay URL de Instagram para abrir.');
                            }
                          },
                        ),
                        _buildDivider(),
                        _buildEditableInfoRow(
                          icon: FontAwesomeIcons.twitter,
                          controller: _twitterController,
                          labelText: 'Perfil de Twitter (URL)',
                          suffixIcon: Icons.chevron_right,
                          onSuffixIconTap: () {
                            if (_twitterController.text.isNotEmpty) {
                              _showSnackBar('Abriendo Twitter...');
                              // launchUrl(Uri.parse(_twitterController.text));
                            } else {
                              _showSnackBar(
                                  'No hay URL de Twitter para abrir.');
                            }
                          },
                        ),
                        _buildDivider(),
                        _buildEditableInfoRow(
                          icon: FontAwesomeIcons.whatsapp,
                          controller: _whatsappController,
                          labelText: 'Número de WhatsApp',
                          keyboardType: TextInputType.phone,
                          suffixIcon: Icons.chevron_right,
                          onSuffixIconTap: () {
                            if (_whatsappController.text.isNotEmpty) {
                              _showSnackBar('Abriendo WhatsApp...');
                              // Puedes construir una URL de WhatsApp aquí
                              // launchUrl(Uri.parse('https://wa.me/${_whatsappController.text}'));
                            } else {
                              _showSnackBar(
                                  'No hay número de WhatsApp para abrir.');
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // Widget auxiliar para títulos de sección
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF5e3a1c),
        ),
      ),
    );
  }

  // Widget para construir una fila de información editable
  Widget _buildEditableInfoRow({
    required IconData icon,
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    int? maxLines = 1,
    IconData? suffixIcon,
    VoidCallback? onSuffixIconTap,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Icon(icon, color: const Color(0xFF5e3a1c), size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: labelText,
                labelStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none, // Eliminar el borde del TextField
                contentPadding: EdgeInsets.zero, // Ajustar el padding
              ),
              keyboardType: keyboardType,
              readOnly: readOnly,
              maxLines: maxLines,
              style: const TextStyle(color: Color(0xFF5e3a1c), fontSize: 16),
              validator: validator, // Asignar el validador
            ),
          ),
          if (suffixIcon != null)
            IconButton(
              icon: Icon(suffixIcon, color: Colors.grey),
              onPressed: onSuffixIconTap,
            ),
        ],
      ),
    );
  }

  // Widget para la tarjeta contenedora de secciones
  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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

  // Divisor para las filas
  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 40, // Alinea el indent con el texto del TextField
      endIndent: 0,
      color: Colors.grey,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
