// lib/screens/edit_animal_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class EditAnimalScreen extends StatefulWidget {
  final String animalId;

  const EditAnimalScreen({super.key, required this.animalId});

  @override
  _EditAnimalScreenState createState() => _EditAnimalScreenState();
}

class _EditAnimalScreenState extends State<EditAnimalScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _earTagNumberController = TextEditingController();
  final TextEditingController _legNumberController = TextEditingController();
  final TextEditingController _registrationNumberController =
      TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _birthWeightController = TextEditingController();
  final TextEditingController _weaningWeightController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _fatherController = TextEditingController();
  final TextEditingController _motherController = TextEditingController();
  final TextEditingController _geneticMarkersController =
      TextEditingController();
  final TextEditingController _diseaseResistanceController =
      TextEditingController();
  final TextEditingController _fertilityInfoController =
      TextEditingController();

  String? _selectedSex;
  String? _selectedBreed;
  String? _selectedPurpose;
  bool _isPregnant = false;
  final TextEditingController _pregnancyDateController =
      TextEditingController();

  final List<String> _purposes = [
    'Leche',
    'Carne',
    'Genética',
    'Engorda',
    'Reproductora'
  ];
  final List<String> _breeds = [
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

  File? _imageFile;
  String? _existingImageUrl;
  bool _loading = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
    _registrationNumberController.dispose();
    _birthDateController.dispose();
    _birthWeightController.dispose();
    _weaningWeightController.dispose();
    _descriptionController.dispose();
    _fatherController.dispose();
    _motherController.dispose();
    _geneticMarkersController.dispose();
    _diseaseResistanceController.dispose();
    _fertilityInfoController.dispose();
    _pregnancyDateController.dispose();
    super.dispose();
  }

  Future<void> _loadAnimalData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('animals')
          .doc(widget.animalId)
          .get();
      if (doc.exists && mounted) {
        final animal = Animal.fromFirestore(doc.data()!, doc.id);
        setState(() {
          _nameController.text = animal.name;
          _earTagNumberController.text = animal.earTagNumber;
          _legNumberController.text = animal.legNumber ?? '';
          _registrationNumberController.text = animal.registrationNumber ?? '';
          _selectedSex = animal.sex;
          _selectedBreed = animal.breed;
          _selectedPurpose = animal.purpose;
          if (animal.birthDate != null)
            _birthDateController.text =
                DateFormat('dd/MM/yyyy').format(animal.birthDate!);
          _birthWeightController.text = animal.birthWeight?.toString() ?? '';
          _weaningWeightController.text =
              animal.weaningWeight?.toString() ?? '';
          _descriptionController.text = animal.description ?? '';
          _fatherController.text = animal.father ?? '';
          _motherController.text = animal.mother ?? '';
          _geneticMarkersController.text = animal.geneticMarkers ?? '';
          _diseaseResistanceController.text = animal.diseaseResistance ?? '';
          _fertilityInfoController.text = animal.fertilityInfo ?? '';

          _existingImageUrl = animal.profileImageUrl;
          _isPregnant = animal.isPregnant ?? false;
          if (animal.pregnancyDate != null) {
            _pregnancyDateController.text =
                DateFormat('dd/MM/yyyy').format(animal.pregnancyDate!);
          }
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null && mounted) {
      setState(() => _imageFile = File(pickedFile.path));
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

  Future<String?> _uploadImage(File image) async {
    try {
      final ref = _storage.ref().child('animal_images').child(
          '${widget.animalId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  void _handleEdit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);
      try {
        final user = _auth.currentUser;
        if (user != null) {
          String? imageUrl = _existingImageUrl;
          if (_imageFile != null) {
            imageUrl = await _uploadImage(_imageFile!);
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

          // NOTA: No actualizamos el campo 'vaccinations' ni 'vaccines' para no borrar el historial existente
          final updateData = {
            'name': _nameController.text.trim(),
            'earTagNumber': _earTagNumberController.text.trim(),
            'legNumber': _legNumberController.text.trim(),
            'registrationNumber': _registrationNumberController.text.trim(),
            'sex': _selectedSex,
            'breed': _selectedBreed,
            'purpose': _selectedPurpose,
            'birthDate': _birthDateController.text.isNotEmpty
                ? Timestamp.fromDate(
                    DateFormat('dd/MM/yyyy').parse(_birthDateController.text))
                : null,
            'birthWeight': double.tryParse(_birthWeightController.text),
            'weaningWeight': double.tryParse(_weaningWeightController.text),
            'description': _descriptionController.text.trim(),
            'profileImageUrl': imageUrl,
            'father': _fatherController.text.trim(),
            'mother': _motherController.text.trim(),
            'geneticMarkers': _geneticMarkersController.text.trim(),
            'diseaseResistance': _diseaseResistanceController.text.trim(),
            'fertilityInfo': _fertilityInfoController.text.trim(),
            'isPregnant': isPregnantData,
            'pregnancyDate': pregnancyDateData != null
                ? Timestamp.fromDate(pregnancyDateData)
                : null,
          };

          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('animals')
              .doc(widget.animalId)
              .update(updateData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Animal actualizado correctamente'),
                backgroundColor: Colors.green));
            Navigator.pop(context, true);
          }
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error al actualizar: $e'),
              backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
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

  Widget _buildFancyInputField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      TextInputType keyboardType = TextInputType.text,
      bool readOnly = false,
      VoidCallback? onTap,
      int maxLines = 1,
      String? Function(String?)? validator,
      List<TextInputFormatter>? inputFormatters}) {
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
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
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
      ),
    );
  }

  Widget _buildFancyDateFormField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      required VoidCallback onTap,
      String? Function(String?)? validator}) {
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
      ),
    );
  }

  Widget _buildFancyDropdownField(
      {required String label,
      required IconData icon,
      required String? value,
      required List<String> items,
      required void Function(String?) onChanged,
      String? Function(String?)? validator}) {
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
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(
          backgroundColor: Color(0xFFfbf6ec),
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFF6b4226))));

    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        title: const Text('Editar Animal',
            style: TextStyle(
                color: Color(0xFF5e3a1c),
                fontWeight: FontWeight.bold,
                fontSize: 24)),
        backgroundColor: const Color(0xFFfbf6ec),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF5e3a1c)),
            onPressed: () => Navigator.of(context).pop()),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 80,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : (_existingImageUrl != null
                                ? NetworkImage(_existingImageUrl!)
                                : null) as ImageProvider?,
                        child: (_imageFile == null && _existingImageUrl == null)
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
                              builder: (context) => SafeArea(
                                child: Wrap(
                                  children: [
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
                                    if (_imageFile != null ||
                                        _existingImageUrl != null)
                                      ListTile(
                                        leading: const Icon(
                                            Icons.delete_forever,
                                            color: Colors.red),
                                        title: const Text('Quitar Foto',
                                            style:
                                                TextStyle(color: Colors.red)),
                                        onTap: () {
                                          setState(() {
                                            _imageFile = null;
                                            _existingImageUrl = null;
                                          });
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                  ],
                                ),
                              ),
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
                            label: 'Nombre o Alias',
                            icon: Icons.abc,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Requerido'
                                : null),
                        _buildFancyInputField(
                            controller: _earTagNumberController,
                            label: 'Número de Arete',
                            icon: FontAwesomeIcons.tag,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Requerido'
                                : null),
                        _buildFancyInputField(
                            controller: _legNumberController,
                            label: 'Número de Pierna',
                            icon: FontAwesomeIcons.hashtag),
                        _buildFancyDropdownField(
                            value: _selectedBreed,
                            label: 'Raza',
                            icon: FontAwesomeIcons.cow,
                            items: _breeds,
                            onChanged: (val) =>
                                setState(() => _selectedBreed = val),
                            validator: (value) =>
                                value == null ? 'Requerido' : null),
                        _buildFancyDropdownField(
                            value: _selectedSex,
                            label: 'Sexo',
                            icon: FontAwesomeIcons.venusMars,
                            items: const ['Macho', 'Hembra'],
                            onChanged: (val) {
                              setState(() {
                                _selectedSex = val;
                                if (_selectedSex == 'Macho')
                                  _isPregnant = false;
                              });
                            },
                            validator: (value) =>
                                value == null ? 'Requerido' : null),
                        _buildFancyDateFormField(
                            controller: _birthDateController,
                            label: 'Fecha de Nacimiento',
                            icon: Icons.calendar_today,
                            onTap: () => _selectBirthDate(context)),
                        _buildFancyInputField(
                            controller: _registrationNumberController,
                            label: 'Número de Registro',
                            icon: Icons.app_registration),
                        _buildFancyDropdownField(
                            value: _selectedPurpose,
                            label: 'Propósito',
                            icon: FontAwesomeIcons.bullseye,
                            items: _purposes,
                            onChanged: (val) =>
                                setState(() => _selectedPurpose = val),
                            validator: (value) =>
                                value == null ? 'Requerido' : null),
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
                            label: 'Peso Nacer (kg)',
                            icon: Icons.line_weight,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}'))
                            ]),
                        _buildFancyInputField(
                            controller: _weaningWeightController,
                            label: 'Peso Destete (kg)',
                            icon: Icons.line_weight,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}'))
                            ]),
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
                            icon: FontAwesomeIcons.person),
                        _buildFancyInputField(
                            controller: _motherController,
                            label: 'Arete de la Madre',
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
                            icon: Icons.health_and_safety,
                            maxLines: 3),
                        _buildFancyInputField(
                            controller: _fertilityInfoController,
                            label: 'Información de fertilidad',
                            icon: FontAwesomeIcons.seedling,
                            maxLines: 3),
                        _buildFancyInputField(
                            controller: _geneticMarkersController,
                            label: 'Marcadores genéticos',
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
                      _buildSectionTitle('Estado Reproductivo'),
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
                                title: const Text('¿Está preñada?',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF5e3a1c))),
                                value: _isPregnant,
                                activeColor: const Color(0xFF6b4226),
                                onChanged: (val) =>
                                    setState(() => _isPregnant = val),
                              ),
                              if (_isPregnant)
                                _buildFancyDateFormField(
                                    controller: _pregnancyDateController,
                                    label: 'Fecha estimada de preñez',
                                    icon: Icons.date_range,
                                    onTap: () => _selectPregnancyDate(context)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                _buildSectionTitle('Información Adicional'),
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
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _loading ? null : _handleEdit,
                  child: _loading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white))
                      : const Text('Confirmar Edición',
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
