import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controladores Generales
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _secondaryEmailController;
  late TextEditingController _facebookController;
  late TextEditingController _instagramController;
  late TextEditingController _twitterController;
  late TextEditingController _whatsappController;

  // Controladores del Rancho
  late TextEditingController _ranchNameController;
  late TextEditingController _ranchAddressController;
  late TextEditingController _hectaresController;

  bool _isLoading = true;
  String? _errorMessage;

  // --- VARIABLES PARA MULTI-RANCHO ---
  List<Map<String, dynamic>> _ranches = [];
  String? _selectedRanchId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _secondaryEmailController = TextEditingController();
    _ranchNameController = TextEditingController();
    _ranchAddressController = TextEditingController();
    _hectaresController = TextEditingController();
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
    _ranchNameController.dispose();
    _ranchAddressController.dispose();
    _hectaresController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        final DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;

          if (data != null) {
            _nameController.text = data['name'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _emailController.text = user.email ?? '';
            _secondaryEmailController.text = data['secondaryEmail'] ?? '';
            _facebookController.text = data['facebook'] ?? '';
            _instagramController.text = data['instagram'] ?? '';
            _twitterController.text = data['twitter'] ?? '';
            _whatsappController.text = data['whatsapp'] ?? '';

            String? currentRanchId = data['currentRanchId'];

            final ranchesSnap = await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('ranches')
                .get();

            List<Map<String, dynamic>> loadedRanches = [];
            for (var doc in ranchesSnap.docs) {
              loadedRanches.add({'id': doc.id, ...doc.data()});
            }

            if (mounted) {
              setState(() {
                _ranches = loadedRanches;
                if (_ranches.isNotEmpty) {
                  bool ranchExists =
                      _ranches.any((r) => r['id'] == currentRanchId);
                  _selectedRanchId =
                      ranchExists ? currentRanchId : _ranches.first['id'];
                  _updateRanchControllers(_selectedRanchId!);
                }
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar los datos: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateRanchControllers(String ranchId) {
    final ranch =
        _ranches.firstWhere((r) => r['id'] == ranchId, orElse: () => {});
    if (ranch.isNotEmpty) {
      _ranchNameController.text = ranch['name'] ?? '';
      _ranchAddressController.text = ranch['location'] ?? '';
      _hectaresController.text = ranch['hectares']?.toString() ?? '';
    }
  }

  // --- ARREGLADO: Guardado de datos sin recargar de Firebase ---
  Future<void> _savePersonalInfo() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final User? user = _auth.currentUser;
        if (user != null) {
          // 1. Guardar info personal del usuario
          await _firestore.collection('users').doc(user.uid).set({
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'secondaryEmail': _secondaryEmailController.text.trim(),
            'facebook': _facebookController.text.trim(),
            'instagram': _instagramController.text.trim(),
            'twitter': _twitterController.text.trim(),
            'whatsapp': _whatsappController.text.trim(),
            if (_selectedRanchId != null) 'currentRanchId': _selectedRanchId,
          }, SetOptions(merge: true));

          // 2. Guardar info del rancho seleccionado actualmente
          if (_selectedRanchId != null) {
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('ranches')
                .doc(_selectedRanchId)
                .set({
              'name': _ranchNameController.text.trim(),
              'location': _ranchAddressController.text.trim(),
              'hectares':
                  double.tryParse(_hectaresController.text.trim()) ?? 0.0,
            }, SetOptions(merge: true));

            // Actualizamos la lista local en memoria para que el desplegable tenga el nombre correcto
            int index = _ranches.indexWhere((r) => r['id'] == _selectedRanchId);
            if (index != -1) {
              _ranches[index]['name'] = _ranchNameController.text.trim();
              _ranches[index]['location'] = _ranchAddressController.text.trim();
              _ranches[index]['hectares'] =
                  double.tryParse(_hectaresController.text.trim()) ?? 0.0;
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Información actualizada correctamente.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar la información: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _showAddRanchDialog() async {
    final TextEditingController newNameCtrl = TextEditingController();
    final TextEditingController newLocCtrl = TextEditingController();
    final TextEditingController newHectCtrl = TextEditingController();
    bool isSaving = false;

    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                backgroundColor: const Color(0xFFfbf6ec),
                title: const Text('Agregar Nuevo Rancho',
                    style: TextStyle(
                        color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: newNameCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Nombre del Rancho'),
                      ),
                      TextField(
                        controller: newLocCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Ubicación / Estado'),
                      ),
                      TextField(
                        controller: newHectCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Hectáreas'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar',
                        style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFc99450)),
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (newNameCtrl.text.trim().isEmpty) return;
                            setStateDialog(() => isSaving = true);
                            try {
                              final user = _auth.currentUser!;
                              final newRef = _firestore
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('ranches')
                                  .doc();

                              await newRef.set({
                                'name': newNameCtrl.text.trim(),
                                'location': newLocCtrl.text.trim(),
                                'hectares':
                                    double.tryParse(newHectCtrl.text.trim()) ??
                                        0.0,
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                              await _firestore
                                  .collection('users')
                                  .doc(user.uid)
                                  .set({'currentRanchId': newRef.id},
                                      SetOptions(merge: true));

                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Rancho agregado con éxito')));
                                setState(() => _isLoading = true);
                                await _loadUserData();
                              }
                            } catch (e) {
                              setStateDialog(() => isSaving = false);
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Guardar',
                            style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          );
        });
  }

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
            onPressed: _isLoading ? null : _savePersonalInfo,
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
                          readOnly: true,
                          suffixIcon: Icons.lock_outline,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(
                            'Mis Ranchos',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddRanchDialog,
                          icon: const Icon(Icons.add_circle,
                              color: Color(0xFFc99450), size: 18),
                          label: const Text('Nuevo',
                              style: TextStyle(
                                  color: Color(0xFFc99450),
                                  fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    _buildSectionCard(
                      children: [
                        if (_ranches.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            child: DropdownButtonFormField<String>(
                              value: _selectedRanchId,
                              decoration: const InputDecoration(
                                labelText: 'Selecciona el rancho a editar',
                                prefixIcon: Icon(Icons.home_work,
                                    color: Color(0xFFc99450)),
                                border: InputBorder.none,
                              ),
                              items: _ranches.map((r) {
                                return DropdownMenuItem<String>(
                                  value: r['id'],
                                  child: Text(r['name'] ?? 'Sin nombre',
                                      style: const TextStyle(
                                          color: Color(0xFF5e3a1c))),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedRanchId = val;
                                    _updateRanchControllers(val);
                                  });
                                }
                              },
                            ),
                          ),
                        _buildDivider(),
                        _buildTextField(
                          controller: _ranchNameController,
                          labelText: 'Nombre del Rancho / Finca',
                          prefixIcon: Icons.landscape,
                        ),
                        _buildDivider(),
                        _buildTextField(
                          controller: _ranchAddressController,
                          labelText: 'Ubicación / Estado',
                          prefixIcon: Icons.location_on,
                        ),
                        _buildDivider(),
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
                          labelText: 'Teléfono Principal del Rancho',
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
