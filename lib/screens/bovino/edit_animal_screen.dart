// lib/screens/edit_animal_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Para formatear la fecha
import 'package:manual_ganadero_flutter/models/animal.dart'; // Asegúrate de importar tu modelo Animal
import 'package:image_picker/image_picker.dart'; // Importar para la selección de imágenes
import 'dart:io'; // Para File
import 'package:firebase_storage/firebase_storage.dart'; // Para Firebase Storage
import 'package:flutter/services.dart'; // Para FilteringTextInputFormatter
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Para FontAwesomeIcons

class EditAnimalScreen extends StatefulWidget {
  final String animalId;

  const EditAnimalScreen({super.key, required this.animalId});

  @override
  _EditAnimalScreenState createState() => _EditAnimalScreenState();
}

class _EditAnimalScreenState extends State<EditAnimalScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de texto
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _earTagNumberController =
      TextEditingController(); // Número de Arete
  final TextEditingController _legNumberController =
      TextEditingController(); // Número de Pierna
  String? _selectedSex; // 'Hembra' o 'Macho'
  String? _selectedBreed; // Variable para la raza seleccionada (para dropdown)
  String? _selectedPurpose;
  final List<String> _purposes = [
    'Leche',
    'Carne',
    'Genética',
    'Engorda',
    'Reproductora'
  ];
  final TextEditingController _fatherController = TextEditingController();
  final TextEditingController _motherController = TextEditingController();
  final TextEditingController _geneticMarkersController =
      TextEditingController();
  final TextEditingController _birthWeightController = TextEditingController();
  final TextEditingController _weaningWeightController =
      TextEditingController();
  final TextEditingController _diseaseResistanceController =
      TextEditingController();
  final TextEditingController _fertilityInfoController =
      TextEditingController();
  final TextEditingController _registrationNumberController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _birthDateController =
      TextEditingController(); // Controlador para fecha de nacimiento

  // Nuevas variables para Vacunas y Preñez
  final TextEditingController _vaccineNameController = TextEditingController();
  final TextEditingController _vaccineDateController = TextEditingController();
  List<VaccineRecord> _vaccineRecords = []; // Lista para almacenar las vacunas

  bool _isPregnant = false; // Estado del switch de preñez
  final TextEditingController _pregnancyDateController =
      TextEditingController(); // Fecha de preñez

  // Lista de razas comunes de bovinos
  static const List<String> _bovineBreeds = [
    'Nelore',
    'Angus',
    'Brangus',
    'Brahman',
    'Brahman Rojo',
    'Hereford',
    'Charolais',
    'Simmental',
    'Limousin',
    'Holstein',
    'Jersey',
    'Suizo Pardo',
    'Guzerat',
    'Indubrasil',
    'Beefmaster',
    'Santa Gertrudis',
    'Texas Longhorn',
    'Cebú',
    'Otro', // Opción para razas no listadas
  ];

  Animal? _animal;
  bool _isLoading = true;
  bool _loading = false; // Para el botón de guardar
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage =
      FirebaseStorage.instance; // Instancia de Firebase Storage

  File?
      _newProfileImageFile; // Nuevo archivo de imagen seleccionado (si se cambia)
  String? _existingProfileImageUrl; // URL de la imagen existente

  @override
  void initState() {
    super.initState();
    _loadAnimalData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _earTagNumberController.dispose();
    _legNumberController.dispose();
    _fatherController.dispose();
    _motherController.dispose();
    _geneticMarkersController.dispose();
    _birthWeightController.dispose();
    _weaningWeightController.dispose();
    _diseaseResistanceController.dispose();
    _fertilityInfoController.dispose();
    _registrationNumberController.dispose();
    _descriptionController.dispose();
    _birthDateController.dispose();

    _vaccineNameController.dispose();
    _vaccineDateController.dispose();
    _pregnancyDateController
        .dispose(); // Dispose del controlador de fecha de preñez

    super.dispose();
  }

  Future<void> _loadAnimalData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario no autenticado.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('animals')
          .doc(widget.animalId)
          .get();

      if (!mounted) return;
      if (docSnapshot.exists && docSnapshot.data() != null) {
        setState(() {
          _animal = Animal.fromFirestore(
              docSnapshot.data() as Map<String, dynamic>, docSnapshot.id);

          // Rellenar controladores con datos existentes
          _nameController.text = _animal!.name;
          _earTagNumberController.text = _animal!.earTagNumber;
          _legNumberController.text = _animal!.legNumber;
          _selectedBreed = _animal!
              .breed; // Cargar raza en la variable de estado para el dropdown
          _selectedSex = _animal!.sex;
          _selectedPurpose = _animal!.purpose;
          _fatherController.text = _animal!.father ?? '';
          _motherController.text = _animal!.mother ?? '';
          _geneticMarkersController.text = _animal!.geneticMarkers ?? '';
          _birthWeightController.text = _animal!.birthWeight?.toString() ?? '';
          _weaningWeightController.text =
              _animal!.weaningWeight?.toString() ?? '';
          _diseaseResistanceController.text = _animal!.diseaseResistance ?? '';
          _fertilityInfoController.text = _animal!.fertilityInfo ?? '';
          _registrationNumberController.text =
              _animal!.registrationNumber ?? '';
          _descriptionController.text = _animal!.description ?? '';

          if (_animal!.birthDate != null) {
            _birthDateController.text =
                DateFormat('dd/MM/yyyy').format(_animal!.birthDate!);
          }
          _existingProfileImageUrl = _animal!.profileImageUrl;

          // Cargar datos de vacunas
          _vaccineRecords = _animal!.vaccinations ?? [];

          // Cargar datos de preñez
          _isPregnant = _animal!.isPregnant ?? false;
          if (_animal!.pregnancyDate != null) {
            _pregnancyDateController.text =
                DateFormat('dd/MM/yyyy').format(_animal!.pregnancyDate!);
          }
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Animal no encontrado.')),
        );
        Navigator.of(context).pop(); // Volver si no se encuentra
      }
    } catch (e) {
      print('Error loading animal data: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos del animal: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _animal?.birthDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFc99450), // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Color(0xFF5e3a1c), // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6b4226), // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // Función para seleccionar fecha de vacuna
  Future<void> _selectVaccineDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFc99450),
              onPrimary: Colors.white,
              onSurface: Color(0xFF5e3a1c),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6b4226),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _vaccineDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // Función para seleccionar fecha de preñez
  Future<void> _selectPregnancyDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFc99450),
              onPrimary: Colors.white,
              onSurface: Color(0xFF5e3a1c),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6b4226),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _pregnancyDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // Función para añadir una vacuna a la lista
  void _addVaccine() {
    if (_vaccineNameController.text.isNotEmpty &&
        _vaccineDateController.text.isNotEmpty) {
      setState(() {
        _vaccineRecords.add(VaccineRecord(
          name: _vaccineNameController.text.trim(),
          date: DateFormat('dd/MM/yyyy')
              .parse(_vaccineDateController.text.trim()),
        ));
        _vaccineNameController.clear();
        _vaccineDateController.clear();
      });
    } else {
      _showSnackBar('Por favor, ingresa el nombre y la fecha de la vacuna.');
    }
  }

  // Función para eliminar una vacuna de la lista
  void _removeVaccine(int index) {
    setState(() {
      _vaccineRecords.removeAt(index);
    });
  }

  // Lógica para seleccionar/tomar foto
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      if (!mounted) return; // Mounted check
      setState(() {
        _newProfileImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _handleEdit() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Por favor, completa todos los campos requeridos.');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showSnackBar('No hay usuario autenticado. Inicia sesión.');
        return;
      }

      String? updatedProfileImageUrl = _existingProfileImageUrl;
      if (_newProfileImageFile != null) {
        // Subir nueva imagen a Firebase Storage
        final String fileName =
            '${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${_newProfileImageFile!.path.split('/').last}';
        final Reference storageRef =
            _storage.ref().child('animal_profile_images/$fileName');
        final UploadTask uploadTask = storageRef.putFile(_newProfileImageFile!);
        final TaskSnapshot snapshot = await uploadTask;
        updatedProfileImageUrl = await snapshot.ref.getDownloadURL();
        print('Nueva imagen de perfil subida: $updatedProfileImageUrl');
      } else if (_existingProfileImageUrl == null &&
          _newProfileImageFile == null) {
        // Si no había imagen y no se subió una nueva, o si la existente se eliminó
        updatedProfileImageUrl = null;
      }

      // Preparar datos de vacunas para guardar
      List<Map<String, dynamic>> vaccinationsData =
          _vaccineRecords.map((v) => v.toMap()).toList();

      // Preparar datos de preñez
      bool? isPregnantData;
      DateTime? pregnancyDateData;

      if (_selectedSex == 'Hembra') {
        isPregnantData = _isPregnant;
        if (_isPregnant) {
          pregnancyDateData = _pregnancyDateController.text.trim().isEmpty
              ? null
              : DateFormat('dd/MM/yyyy')
                  .parse(_pregnancyDateController.text.trim());
        }
      }

      final updatedAnimalData = {
        'name': _nameController.text.trim(),
        'earTagNumber': _earTagNumberController.text.trim(),
        'legNumber': _legNumberController.text.trim(),
        'breed': _selectedBreed,
        'sex': _selectedSex,
        'birthDate': _birthDateController.text.trim().isEmpty
            ? null
            : Timestamp.fromDate(DateFormat('dd/MM/yyyy')
                .parse(_birthDateController.text.trim())),
        'registrationNumber': _registrationNumberController.text.trim().isEmpty
            ? null
            : _registrationNumberController.text.trim(),
        'birthWeight': _birthWeightController.text.trim().isEmpty
            ? null
            : double.tryParse(_birthWeightController.text.trim()),
        'weaningWeight': _weaningWeightController.text.trim().isEmpty
            ? null
            : double.tryParse(_weaningWeightController.text.trim()),
        'father': _fatherController.text.trim().isEmpty
            ? null
            : _fatherController.text.trim(),
        'mother': _motherController.text.trim().isEmpty
            ? null
            : _motherController.text.trim(),
        'diseaseResistance': _diseaseResistanceController.text.trim().isEmpty
            ? null
            : _diseaseResistanceController.text.trim(),
        'fertilityInfo': _fertilityInfoController.text.trim().isEmpty
            ? null
            : _fertilityInfoController.text.trim(),
        'geneticMarkers': _geneticMarkersController.text.trim().isEmpty
            ? null
            : _geneticMarkersController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'profileImageUrl': updatedProfileImageUrl,
        'vaccinations': vaccinationsData,
        'isPregnant': isPregnantData,
        'pregnancyDate': pregnancyDateData != null
            ? Timestamp.fromDate(pregnancyDateData)
            : null,
        'purpose': _selectedPurpose,
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('animals')
          .doc(widget.animalId)
          .update(updatedAnimalData);

      if (!mounted) return;
      _showSnackBar('Animal editado exitosamente!');
      Navigator.of(context).pop(
          true); // Pasar 'true' para indicar éxito y recargar datos en la pantalla anterior
    } catch (e) {
      print('Error al editar animal: $e');
      if (!mounted) return;
      _showSnackBar('Error al editar animal: ${e.toString()}');
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Widget para un campo de entrada con un estilo estético mejorado
  Widget _buildFancyInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF5e3a1c)),
          border: InputBorder.none, // Eliminamos el borde del InputDecoration
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          labelStyle: const TextStyle(color: Color(0xFF5e3a1c), fontSize: 16),
          floatingLabelBehavior:
              FloatingLabelBehavior.auto, // Mantener el label flotante
        ),
        validator: validator,
        inputFormatters: inputFormatters, // Añadir inputFormatters
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
    );
  }

  // Widget para el selector de fecha con estilo estético mejorado
  Widget _buildFancyDateFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF5e3a1c)),
          border: InputBorder.none, // Eliminamos el borde del InputDecoration
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          labelStyle: const TextStyle(color: Color(0xFF5e3a1c), fontSize: 16),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          suffixIcon: const Icon(Icons.calendar_today,
              color: Colors.grey), // Icono de calendario
        ),
        validator: validator,
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
    );
  }

  // Widget para el DropdownFormField con un estilo estético mejorado
  Widget _buildFancyDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF5e3a1c)),
          border: InputBorder.none, // Eliminamos el borde del InputDecoration
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          labelStyle: const TextStyle(color: Color(0xFF5e3a1c), fontSize: 16),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
        items: items.map<DropdownMenuItem<String>>((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item, style: const TextStyle(color: Colors.black87)),
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator,
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
    );
  }

  // Widget auxiliar para títulos de sección
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, top: 10.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF5e3a1c),
        ),
      ),
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

    if (_animal == null) {
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
          title: const Text('Editar Animal',
              style: TextStyle(color: Color(0xFF5e3a1c))),
        ),
        body: const Center(
          child: Text(
            'Animal no encontrado.',
            style: TextStyle(fontSize: 16, color: Color(0xFF5e3a1c)),
          ),
        ),
      );
    }

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
        title: Text(
          'Editar ${_animal!.name}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5e3a1c),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sección de Foto de Perfil
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 80,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _newProfileImageFile != null
                            ? FileImage(_newProfileImageFile!) as ImageProvider
                            : (_existingProfileImageUrl != null
                                ? NetworkImage(_existingProfileImageUrl!)
                                    as ImageProvider
                                : null),
                        child: _newProfileImageFile == null &&
                                _existingProfileImageUrl == null
                            ? const Icon(FontAwesomeIcons.cow,
                                size: 80,
                                color: Colors.grey) // CAMBIO: Icono de vaca
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (BuildContext bc) {
                                return SafeArea(
                                  child: Wrap(
                                    children: <Widget>[
                                      ListTile(
                                        leading:
                                            const Icon(Icons.photo_library),
                                        title: const Text('Galería'),
                                        onTap: () {
                                          _pickImage(ImageSource.gallery);
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.camera_alt),
                                        title: const Text('Cámara'),
                                        onTap: () {
                                          _pickImage(ImageSource.camera);
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      if (_newProfileImageFile != null ||
                                          _existingProfileImageUrl !=
                                              null) // Opción para quitar foto si ya hay una
                                        ListTile(
                                          leading: const Icon(
                                              Icons.delete_forever,
                                              color: Colors.red),
                                          title: const Text('Quitar Foto',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                          onTap: () {
                                            setState(() {
                                              _newProfileImageFile = null;
                                              _existingProfileImageUrl = null;
                                            });
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Sección: Información Básica
                _buildSectionTitle('Información Básica'),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildFancyInputField(
                          controller: _nameController,
                          label: 'Nombre del animal',
                          icon: Icons.abc,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingresa el nombre';
                            }
                            return null;
                          },
                        ),
                        _buildFancyInputField(
                          controller: _earTagNumberController,
                          label: 'Número de arete',
                          icon: FontAwesomeIcons.tag,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingresa el número de arete';
                            }
                            return null;
                          },
                        ),
                        _buildFancyInputField(
                          controller: _legNumberController,
                          label: 'Número de pierna',
                          icon: FontAwesomeIcons.hashtag,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingresa el número de pierna';
                            }
                            return null;
                          },
                        ),
                        _buildFancyDropdownField(
                          label: 'Raza *',
                          icon: FontAwesomeIcons.cow,
                          value: _selectedBreed,
                          items: _bovineBreeds,
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedBreed = newValue;
                            });
                          },
                          validator: (value) => value == null || value.isEmpty
                              ? 'Campo obligatorio'
                              : null,
                        ),
                        _buildFancyDropdownField(
                          label: 'Sexo',
                          icon: FontAwesomeIcons.venusMars,
                          value: _selectedSex,
                          items: const ['Macho', 'Hembra'],
                          onChanged: (value) {
                            setState(() {
                              _selectedSex = value;
                              // Resetear estado de preñez si el sexo cambia a Macho
                              if (_selectedSex == 'Macho') {
                                _isPregnant = false;
                                _pregnancyDateController.clear();
                              }
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, selecciona el sexo';
                            }
                            return null;
                          },
                        ),
                        _buildFancyDateFormField(
                          controller: _birthDateController,
                          label: 'Fecha de nacimiento',
                          icon: Icons.calendar_today,
                          onTap: () => _selectBirthDate(context),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, selecciona la fecha de nacimiento';
                            }
                            return null;
                          },
                        ),
                        _buildFancyInputField(
                          controller: _registrationNumberController,
                          label: 'Número de registro',
                          icon: Icons.app_registration,
                        ),
                        _buildFancyDropdownField(
                          label: 'Propósito *',
                          icon: FontAwesomeIcons.bullseye,
                          value: _selectedPurpose,
                          items: _purposes,
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedPurpose = newValue;
                            });
                          },
                          validator: (value) => value == null || value.isEmpty
                              ? 'Selecciona el propósito'
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Sección: Pesos
                _buildSectionTitle('Pesos'),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildFancyInputField(
                          controller: _birthWeightController,
                          label: 'Peso al nacer (kg)',
                          icon: Icons.line_weight,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          validator: (value) {
                            if (value != null &&
                                value.isNotEmpty &&
                                double.tryParse(value) == null) {
                              return 'Ingresa un número válido';
                            }
                            return null;
                          },
                        ),
                        _buildFancyInputField(
                          controller: _weaningWeightController,
                          label: 'Peso al destete (kg)',
                          icon: Icons.line_weight,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          validator: (value) {
                            if (value != null &&
                                value.isNotEmpty &&
                                double.tryParse(value) == null) {
                              return 'Ingresa un número válido';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Sección: Parentesco
                _buildSectionTitle('Parentesco'),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildFancyInputField(
                          controller: _fatherController,
                          label: 'Padre',
                          icon: FontAwesomeIcons.person,
                        ),
                        _buildFancyInputField(
                          controller: _motherController,
                          label: 'Madre',
                          icon: FontAwesomeIcons.personDress,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Sección: Salud y Genética
                _buildSectionTitle('Salud y Genética'),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildFancyInputField(
                          controller: _diseaseResistanceController,
                          label: 'Resistencia a enfermedades',
                          icon: Icons.health_and_safety,
                          maxLines: 3,
                        ),
                        _buildFancyInputField(
                          controller: _fertilityInfoController,
                          label: 'Información de fertilidad',
                          icon: FontAwesomeIcons.seedling,
                          maxLines: 3,
                        ),
                        _buildFancyInputField(
                          controller: _geneticMarkersController,
                          label: 'Marcadores genéticos',
                          icon: FontAwesomeIcons.dna, // Icono de ADN
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Sección: Vacunación
                _buildSectionTitle('Vacunación'),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildFancyInputField(
                          controller: _vaccineNameController,
                          label: 'Nombre de la vacuna',
                          icon: Icons.vaccines,
                        ),
                        _buildFancyDateFormField(
                          controller: _vaccineDateController,
                          label: 'Fecha de vacunación',
                          icon: Icons.calendar_today,
                          onTap: () => _selectVaccineDate(context),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addVaccine,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Añadir Vacuna',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFc99450),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Lista de vacunas añadidas
                        _vaccineRecords.isEmpty
                            ? const Text('No hay vacunas registradas.',
                                style: TextStyle(color: Colors.grey))
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _vaccineRecords.length,
                                itemBuilder: (context, index) {
                                  final vaccine = _vaccineRecords[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    color: Colors.grey[100],
                                    child: ListTile(
                                      title: Text(vaccine.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      subtitle: Text(DateFormat('dd/MM/yyyy')
                                          .format(vaccine.date)),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.remove_circle,
                                            color: Colors.red),
                                        onPressed: () => _removeVaccine(index),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Sección: Información de Reproducción (Solo si es Hembra)
                if (_selectedSex == 'Hembra')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Información de Reproducción'),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: const Text(
                                  '¿Está Preñada?',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF5e3a1c)),
                                ),
                                value: _isPregnant,
                                onChanged: (bool value) {
                                  setState(() {
                                    _isPregnant = value;
                                    if (!value) {
                                      _pregnancyDateController
                                          .clear(); // Limpiar fecha si no está preñada
                                    }
                                  });
                                },
                                activeColor: const Color(0xFF6b4226),
                              ),
                              if (_isPregnant)
                                _buildFancyDateFormField(
                                  controller: _pregnancyDateController,
                                  label: 'Fecha de Preñez',
                                  icon: Icons.date_range,
                                  onTap: () => _selectPregnancyDate(context),
                                  validator: (value) {
                                    if (_isPregnant &&
                                        (value == null || value.isEmpty)) {
                                      return 'Por favor, selecciona la fecha de preñez';
                                    }
                                    return null;
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),

                // Sección: Otros Datos (solo Descripción)
                _buildSectionTitle('Otros Datos'),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildFancyInputField(
                          controller: _descriptionController,
                          label: 'Descripción',
                          icon: Icons.description,
                          maxLines: 5,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),
                // Botón de Confirmar Edición
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5e3a1c),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10), // Bordes más redondeados
                    ),
                  ),
                  onPressed: _loading
                      ? null
                      : _handleEdit, // Deshabilitar si está cargando
                  child: _loading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text(
                          'Confirmar Edición',
                          style: TextStyle(
                            fontSize: 18, // Tamaño de fuente más grande
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 40), // Espacio extra al final
              ],
            ),
          ),
        ),
      ),
    );
  }
}
