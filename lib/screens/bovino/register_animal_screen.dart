// lib/screens/register_animal_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:manual_ganadero_flutter/screens/bovino/import_animals_screen.dart'; // <-- AGREGA ESTO
import 'package:manual_ganadero_flutter/services/notification_service.dart'; // Ajusta la ruta si es necesario

class RegisterAnimalScreen extends StatefulWidget {
  const RegisterAnimalScreen({super.key});

  @override
  State<RegisterAnimalScreen> createState() => _RegisterAnimalScreenState();
}

class _RegisterAnimalScreenState extends State<RegisterAnimalScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _registrationNumberController =
      TextEditingController();
  final TextEditingController _earTagNumberController = TextEditingController();
  final TextEditingController _legNumberController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _birthWeightController = TextEditingController();
  final TextEditingController _weaningWeightController =
      TextEditingController();
  final TextEditingController _fatherController = TextEditingController();
  final TextEditingController _motherController = TextEditingController();
  final TextEditingController _diseaseResistanceController =
      TextEditingController();
  final TextEditingController _fertilityInfoController =
      TextEditingController();
  final TextEditingController _geneticMarkersController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isPregnant = false;
  final TextEditingController _pregnancyDateController =
      TextEditingController();

  String? _selectedSex;
  String? _selectedBreed;
  String? _selectedPurpose;

  final List<String> _bovineBreeds = [
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
    'Otro',
  ];

  final List<String> _purposes = [
    'Leche',
    'Carne',
    'Genética',
    'Engorda',
    'Reproductora'
  ];

  File? _profileImageFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _registrationNumberController.dispose();
    _earTagNumberController.dispose();
    _legNumberController.dispose();
    _birthDateController.dispose();
    _birthWeightController.dispose();
    _weaningWeightController.dispose();
    _fatherController.dispose();
    _motherController.dispose();
    _diseaseResistanceController.dispose();
    _fertilityInfoController.dispose();
    _geneticMarkersController.dispose();
    _descriptionController.dispose();
    _pregnancyDateController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate(BuildContext context) async {
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
                onSurface: Color(0xFF5e3a1c)),
            textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6b4226))),
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
                onSurface: Color(0xFF5e3a1c)),
            textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6b4226))),
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

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      if (!mounted) return;
      setState(() {
        _profileImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _registerAnimal() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Por favor, completa todos los campos requeridos.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showSnackBar('No hay usuario autenticado. Inicia sesión.');
        return;
      }

      String? profileImageUrl;
      if (_profileImageFile != null) {
        final String fileName =
            '${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${_profileImageFile!.path.split('/').last}';
        final Reference storageRef =
            _storage.ref().child('animal_profile_images/$fileName');
        final UploadTask uploadTask = storageRef.putFile(_profileImageFile!);
        final TaskSnapshot snapshot = await uploadTask;
        profileImageUrl = await snapshot.ref.getDownloadURL();
      }

      bool isPregnantData = false;
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

      final newAnimal = Animal(
        id: '',
        name: _nameController.text.trim().isEmpty
            ? 'Sin nombre'
            : _nameController.text.trim(),
        earTagNumber: _earTagNumberController.text.trim(),
        legNumber: _legNumberController.text.trim(),
        location: 'N/A',
        breed: _selectedBreed,
        sex: _selectedSex,
        birthDate: _birthDateController.text.trim().isEmpty
            ? null
            : DateFormat('dd/MM/yyyy').parse(_birthDateController.text.trim()),
        registrationNumber: _registrationNumberController.text.trim().isEmpty
            ? null
            : _registrationNumberController.text.trim(),
        birthWeight: _birthWeightController.text.trim().isEmpty
            ? null
            : double.tryParse(_birthWeightController.text.trim()),
        weaningWeight: _weaningWeightController.text.trim().isEmpty
            ? null
            : double.tryParse(_weaningWeightController.text.trim()),
        father: _fatherController.text.trim().isEmpty
            ? null
            : _fatherController.text.trim(),
        mother: _motherController.text.trim().isEmpty
            ? null
            : _motherController.text.trim(),
        diseaseResistance: _diseaseResistanceController.text.trim().isEmpty
            ? null
            : _diseaseResistanceController.text.trim(),
        fertilityInfo: _fertilityInfoController.text.trim().isEmpty
            ? null
            : _fertilityInfoController.text.trim(),
        geneticMarkers: _geneticMarkersController.text.trim().isEmpty
            ? null
            : _geneticMarkersController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        price: null,
        profileImageUrl: profileImageUrl,
        vaccinations: [], // AQUÍ QUEDA VACÍO PARA EL MÓDULO DE SANIDAD
        isPregnant: isPregnantData,
        pregnancyDate: pregnancyDateData,
        purpose: _selectedPurpose,
      );

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      String? currentRanchId =
          (userDoc.data() as Map<String, dynamic>?)?['currentRanchId'];

      // 2. Si no hay rancho seleccionado, mostramos error y detenemos el guardado
      if (currentRanchId == null) {
        if (!mounted) return;
        _showSnackBar(
            'No tienes un rancho seleccionado. Ve al inicio y selecciona uno.');
        setState(() => _isLoading = false);
        return;
      }

      // 3. Guardamos en la subcolección del rancho activo
      // 3. Guardamos en la subcolección del rancho activo y guardamos su Referencia (ID)
      DocumentReference newAnimalRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('ranches')
          .doc(currentRanchId)
          .collection('animals')
          .add(newAnimal.toFirestore());

      // --- NUEVO: PROGRAMAR ALERTA DE PARTO AUTOMÁTICA ---
      // Usamos las variables isPregnantData y pregnancyDateData que ya declaraste arriba
      if (isPregnantData && pregnancyDateData != null) {
        // Revisamos si el usuario quiere recibir notificaciones (leemos del userDoc que ya consultaste)
        bool notificationsEnabled = (userDoc.data()
                as Map<String, dynamic>?)?['notificationsEnabled'] ??
            true;

        if (notificationsEnabled) {
          // Calculamos la fecha: 283 días (gestación) - 7 días (aviso previo) = 276 días
          DateTime alertDate = pregnancyDateData.add(const Duration(days: 276));

          // Solo programamos si la alerta va a sonar en el futuro
          if (alertDate.isAfter(DateTime.now())) {
            await NotificationService().scheduleNotification(
              id: newAnimalRef
                  .id.hashCode, // Usamos el ID de Firebase convertido a número
              title: '¡Parto Cercano! 🐄',
              body:
                  'La vaca ${_nameController.text.trim()} está a aprox. una semana de su fecha de parto.',
              scheduledDate: alertDate,
            );
          }
        }
      }
      // --- FIN NUEVO CÓDIGO ---

      if (!mounted) return;
      _showSnackBar('Animal registrado exitosamente!');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error al registrar animal: ${e.toString()}');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildFancyInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
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
                offset: const Offset(0, 3))
          ]),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF5e3a1c)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          labelStyle: const TextStyle(color: Color(0xFF5e3a1c), fontSize: 16),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
        validator: validator,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
    );
  }

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
                offset: const Offset(0, 3))
          ]),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF5e3a1c)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          labelStyle: const TextStyle(color: Color(0xFF5e3a1c), fontSize: 16),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
        ),
        validator: validator,
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
    );
  }

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
                offset: const Offset(0, 3))
          ]),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF5e3a1c)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          labelStyle: const TextStyle(color: Color(0xFF5e3a1c), fontSize: 16),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
        items: items.map<DropdownMenuItem<String>>((String item) {
          return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(color: Colors.black87)));
        }).toList(),
        onChanged: onChanged,
        validator: validator,
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, top: 10.0),
      child: Text(title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5e3a1c))),
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
            onPressed: () {
              Navigator.of(context).pop();
            }),
        title: const Text('Registrar Animal',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5e3a1c))),
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
                // --- BANNER DE IMPORTACIÓN MASIVA CON EXCEL ---
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 25.0),
                  color: Colors.green.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: Colors.green.shade300, width: 2),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ImportAnimalsScreen()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 15.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(FontAwesomeIcons.fileExcel,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 15),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¿Registras más de un animal?',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Ahorra tiempo y súbelos desde Excel',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              color: Colors.green, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                // --- FIN DEL BANNER ---
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 80,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _profileImageFile != null
                            ? FileImage(_profileImageFile!) as ImageProvider
                            : null,
                        child: _profileImageFile == null
                            ? const Icon(FontAwesomeIcons.cow,
                                size: 80, color: Colors.grey)
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
                                          }),
                                      ListTile(
                                          leading: const Icon(Icons.camera_alt),
                                          title: const Text('Cámara'),
                                          onTap: () {
                                            _pickImage(ImageSource.camera);
                                            Navigator.of(context).pop();
                                          }),
                                      if (_profileImageFile != null)
                                        ListTile(
                                          leading: const Icon(
                                              Icons.delete_forever,
                                              color: Colors.red),
                                          title: const Text('Quitar Foto',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                          onTap: () {
                                            setState(() {
                                              _profileImageFile = null;
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
                                  shape: BoxShape.circle),
                              padding: const EdgeInsets.all(8),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 20)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
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
                            maxLength: 15,
                            icon: Icons.abc),
                        _buildFancyInputField(
                            controller: _earTagNumberController,
                            label: 'Número de arete',
                            maxLength: 15,
                            icon: FontAwesomeIcons.tag,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Por favor, ingresa el número de arete'
                                : null),
                        _buildFancyInputField(
                            controller: _legNumberController,
                            label: 'Número de pierna',
                            maxLength: 15,
                            icon: FontAwesomeIcons.hashtag,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Por favor, ingresa el número de pierna'
                                : null),
                        _buildFancyDropdownField(
                            label: 'Raza *',
                            icon: FontAwesomeIcons.cow,
                            value: _selectedBreed,
                            items: _bovineBreeds,
                            onChanged: (String? newValue) =>
                                setState(() => _selectedBreed = newValue),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Campo obligatorio'
                                : null),
                        _buildFancyDropdownField(
                          label: 'Sexo',
                          icon: FontAwesomeIcons.venusMars,
                          value: _selectedSex,
                          items: const ['Macho', 'Hembra'],
                          onChanged: (value) {
                            setState(() {
                              _selectedSex = value;
                              if (_selectedSex == 'Macho') {
                                _isPregnant = false;
                                _pregnancyDateController.clear();
                              }
                            });
                          },
                          validator: (value) => value == null || value.isEmpty
                              ? 'Por favor, selecciona el sexo'
                              : null,
                        ),
                        _buildFancyDropdownField(
                            label: 'Propósito *',
                            icon: FontAwesomeIcons.bullseye,
                            value: _selectedPurpose,
                            items: _purposes,
                            onChanged: (String? newValue) =>
                                setState(() => _selectedPurpose = newValue),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Selecciona el propósito'
                                : null),
                        _buildFancyDateFormField(
                            controller: _birthDateController,
                            label: 'Fecha de nacimiento',
                            icon: Icons.calendar_today,
                            onTap: () => _selectBirthDate(context),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Por favor, selecciona la fecha de nacimiento'
                                : null),
                        _buildFancyInputField(
                            controller: _registrationNumberController,
                            label: 'Número de registro',
                            maxLength: 15,
                            icon: Icons.app_registration),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                            maxLength: 15,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}'))
                            ],
                            validator: (value) => (value != null &&
                                    value.isNotEmpty &&
                                    double.tryParse(value) == null)
                                ? 'Ingresa un número válido'
                                : null),
                        _buildFancyInputField(
                            controller: _weaningWeightController,
                            label: 'Peso al destete (kg)',
                            icon: Icons.line_weight,
                            maxLength: 15,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}'))
                            ],
                            validator: (value) => (value != null &&
                                    value.isNotEmpty &&
                                    double.tryParse(value) == null)
                                ? 'Ingresa un número válido'
                                : null),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                            label: 'Arete del Padre',
                            maxLength: 15,
                            icon: FontAwesomeIcons.person),
                        _buildFancyInputField(
                            controller: _motherController,
                            label: 'Arete de la Madre',
                            maxLength: 15,
                            icon: FontAwesomeIcons.personDress),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                            maxLength: 250,
                            icon: Icons.health_and_safety,
                            maxLines: 3),
                        _buildFancyInputField(
                            controller: _fertilityInfoController,
                            label: 'Información de fertilidad',
                            maxLength: 250,
                            icon: FontAwesomeIcons.seedling,
                            maxLines: 3),
                        _buildFancyInputField(
                            controller: _geneticMarkersController,
                            label: 'Marcadores genéticos',
                            maxLength: 250,
                            icon: FontAwesomeIcons.dna,
                            maxLines: 3),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                                title: const Text('¿Está Preñada?',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF5e3a1c))),
                                value: _isPregnant,
                                onChanged: (bool value) {
                                  setState(() {
                                    _isPregnant = value;
                                    if (!value)
                                      _pregnancyDateController.clear();
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
                                  validator: (value) => (_isPregnant &&
                                          (value == null || value.isEmpty))
                                      ? 'Por favor, selecciona la fecha de preñez'
                                      : null,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
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
                            maxLength: 250,
                            icon: Icons.description,
                            maxLines: 5),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5e3a1c),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: _isLoading ? null : _registerAnimal,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white))
                      : const Text('Registrar Animal',
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
