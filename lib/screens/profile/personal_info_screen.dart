import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Para FontAwesomeIcons

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
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _secondaryEmailController;
  late TextEditingController _ranchAddressController;
  late TextEditingController
      _hectaresController; // <--- NUEVO CONTROLADOR DE HECTÁREAS
  late TextEditingController _facebookController;
  late TextEditingController _instagramController;
  late TextEditingController _twitterController;
  late TextEditingController _whatsappController;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _secondaryEmailController = TextEditingController();
    _ranchAddressController = TextEditingController();
    _hectaresController = TextEditingController(); // <--- INICIALIZADO
    _facebookController = TextEditingController();
    _instagramController = TextEditingController();
    _twitterController = TextEditingController();
    _whatsappController = TextEditingController();

    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _secondaryEmailController.dispose();
    _ranchAddressController.dispose();
    _hectaresController.dispose(); // <--- DISPUESTO
    _facebookController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        _emailController.text = user.email ?? '';

        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic>? userData =
              userDoc.data() as Map<String, dynamic>?;
          if (userData != null) {
            _nameController.text = userData['name'] ?? '';
            _phoneController.text = userData['phone'] ?? '';
            _secondaryEmailController.text = userData['secondaryEmail'] ?? '';

            // <--- AQUÍ LEEMOS LOS DATOS DEL RANCHO --->
            _ranchAddressController.text = userData['ranchName'] ?? '';
            _hectaresController.text = userData['hectares'] != null
                ? userData['hectares'].toString()
                : '';

            // Cargar redes sociales si existen
            if (userData['socialMedia'] != null) {
              Map<String, dynamic> social = userData['socialMedia'];
              _facebookController.text = social['facebook'] ?? '';
              _instagramController.text = social['instagram'] ?? '';
              _twitterController.text = social['twitter'] ?? '';
              _whatsappController.text = social['whatsapp'] ?? '';
            }
          }
        }
      } else {
        _errorMessage = 'No hay usuario autenticado.';
      }
    } catch (e) {
      _errorMessage = 'Error al cargar los datos: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) {
      return; // Detener si el formulario no es válido
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // <--- AQUÍ GUARDAMOS LOS DATOS DEL RANCHO --->
        Map<String, dynamic> dataToUpdate = {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'secondaryEmail': _secondaryEmailController.text.trim(),
          'ranchName': _ranchAddressController.text.trim(),
          'hectares': double.tryParse(_hectaresController.text.trim()) ?? 0.0,
          'socialMedia': {
            'facebook': _facebookController.text.trim(),
            'instagram': _instagramController.text.trim(),
            'twitter': _twitterController.text.trim(),
            'whatsapp': _whatsappController.text.trim(),
          }
        };

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(dataToUpdate, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Información guardada correctamente.'),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al guardar los datos: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Resto de métodos de UI (_buildTextField, _buildSectionCard, etc) se mantienen igual...
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    IconData? suffixIcon,
    VoidCallback? onSuffixIconTap,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(prefixIcon, color: const Color(0xFFc99450), size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: labelText,
                labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              keyboardType: keyboardType,
              readOnly: readOnly,
              maxLines: maxLines,
              style: const TextStyle(color: Color(0xFF5e3a1c), fontSize: 16),
              validator: validator,
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

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 40,
      color: Colors.black12,
    );
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Información Personal',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5e3a1c),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFFc99450), size: 28),
            onPressed: _isLoading ? null : _saveData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFc99450)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                      child: Text(
                        'Datos Básicos',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey),
                      ),
                    ),
                    _buildSectionCard(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          labelText: 'Nombre Completo',
                          prefixIcon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Por favor, ingresa tu nombre.';
                            }
                            return null;
                          },
                        ),
                        _buildDivider(),
                        _buildTextField(
                          controller: _emailController,
                          labelText: 'Correo Electrónico (Login)',
                          prefixIcon: Icons.email_outlined,
                          readOnly: true, // No editable
                          suffixIcon: Icons.lock_outline,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                      child: Text(
                        'Información del Rancho',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey),
                      ),
                    ),
                    _buildSectionCard(
                      children: [
                        _buildTextField(
                          controller: _ranchAddressController,
                          labelText: 'Nombre del Rancho / Finca',
                          prefixIcon: Icons.landscape,
                          maxLines: 2,
                        ),
                        _buildDivider(),
                        // <--- AQUÍ AGREGAMOS EL CAMPO DE HECTÁREAS --->
                        _buildTextField(
                          controller: _hectaresController,
                          labelText: 'Tamaño (Hectáreas)',
                          prefixIcon: Icons.map,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                        _buildDivider(),
                        _buildTextField(
                          controller: _phoneController,
                          labelText: 'Teléfono Principal',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        _buildDivider(),
                        _buildTextField(
                          controller: _secondaryEmailController,
                          labelText: 'Correo Secundario (Contacto)',
                          prefixIcon: Icons.alternate_email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                      child: Text(
                        'Redes Sociales y Contacto',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey),
                      ),
                    ),
                    _buildSectionCard(
                      children: [
                        _buildTextField(
                          controller: _whatsappController,
                          labelText: 'WhatsApp (Link o Número)',
                          prefixIcon: FontAwesomeIcons.whatsapp,
                        ),
                        _buildDivider(),
                        _buildTextField(
                          controller: _facebookController,
                          labelText: 'Facebook (Usuario o Enlace)',
                          prefixIcon: FontAwesomeIcons.facebookF,
                        ),
                        _buildDivider(),
                        _buildTextField(
                          controller: _instagramController,
                          labelText: 'Instagram (Usuario o Enlace)',
                          prefixIcon: FontAwesomeIcons.instagram,
                        ),
                        _buildDivider(),
                        _buildTextField(
                          controller: _twitterController,
                          labelText: 'X / Twitter (Usuario o Enlace)',
                          prefixIcon: FontAwesomeIcons.xTwitter,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
