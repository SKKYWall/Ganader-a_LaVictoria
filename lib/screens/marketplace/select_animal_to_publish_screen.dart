// lib/screens/marketplace/select_animal_to_publish_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class SelectAnimalToPublishScreen extends StatefulWidget {
  const SelectAnimalToPublishScreen({super.key});

  @override
  State<SelectAnimalToPublishScreen> createState() =>
      _SelectAnimalToPublishScreenState();
}

class _SelectAnimalToPublishScreenState
    extends State<SelectAnimalToPublishScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final Map<String, Map<String, dynamic>> _selectedAnimalDetails = {};
  final Map<String, TextEditingController> _priceControllers = {};

  final Map<String, File> _newAnimalImages = {};

  final TextEditingController _certificationsController =
      TextEditingController();
  final TextEditingController _municipalityController = TextEditingController();

  String? _currentRanchId;
  bool _isLoadingRanch = true;
  bool _isPublishing = false;

  final TextEditingController _phoneController = TextEditingController();
  String _selectedState = 'Chihuahua';
  final List<String> _states = [
    'Aguascalientes',
    'Baja California',
    'Chiapas',
    'Chihuahua',
    'Coahuila',
    'Durango',
    'Guanajuato',
    'Jalisco',
    'Michoacán',
    'Nuevo León',
    'Oaxaca',
    'Puebla',
    'Sinaloa',
    'Sonora',
    'Tabasco',
    'Veracruz',
    'Zacatecas'
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentRanchId();
  }

  @override
  void dispose() {
    _priceControllers.forEach((_, controller) => controller.dispose());
    _phoneController.dispose();
    _certificationsController.dispose();
    _municipalityController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentRanchId() async {
    if (_currentUser == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .get();
    if (mounted) {
      setState(() {
        _currentRanchId =
            (doc.data() as Map<String, dynamic>?)?['currentRanchId'];
        _isLoadingRanch = false;
      });
    }
  }

  Stream<QuerySnapshot> _getAnimalsStream() {
    if (_currentRanchId == null || _currentUser == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('ranches')
        .doc(_currentRanchId)
        .collection('animals')
        .snapshots();
  }

  Future<void> _pickImageForAnimal(String animalId) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image != null) {
      setState(() {
        _newAnimalImages[animalId] = File(image.path);
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(imageFile.path)}';
      Reference ref = _storage.ref().child('marketplace_images/$fileName');
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  Future<void> _publishSelectedAnimals() async {
    if (_selectedAnimalDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona al menos un animal.')));
      return;
    }

    // --- NUEVA VALIDACIÓN: PRECIO OBLIGATORIO ---
    for (String animalId in _selectedAnimalDetails.keys) {
      final priceText = _priceControllers[animalId]?.text ?? '';
      if (priceText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'El precio es obligatorio para los animales seleccionados.')));
        return;
      }
      final price = double.tryParse(priceText) ?? 0.0;
      if (price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ingresa un precio válido mayor a \$0.')));
        return;
      }
    }

    if (_phoneController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Por favor, ingresa un teléfono válido (10 dígitos).')));
      return;
    }
    if (_municipalityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Por favor, ingresa tu ciudad o municipio.')));
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      final marketplaceRef =
          FirebaseFirestore.instance.collection('marketplace_listings');

      for (String animalId in _selectedAnimalDetails.keys) {
        final data = _selectedAnimalDetails[animalId]!;
        final priceText = _priceControllers[animalId]?.text ?? '0';
        final price = double.tryParse(priceText) ?? 0.0;

        String? finalImageUrl;

        if (_newAnimalImages.containsKey(animalId)) {
          finalImageUrl = await _uploadImage(_newAnimalImages[animalId]!);
        } else {
          List<dynamic> imageUrls = data['imageUrls'] ?? [];
          if (imageUrls.isNotEmpty) {
            finalImageUrl = imageUrls[0];
          }
        }

        final newListing = marketplaceRef.doc();
        batch.set(newListing, {
          'listingId': newListing.id,
          'animalId': animalId,
          'ranchId': _currentRanchId,
          'ownerId': _currentUser!.uid,
          'animalName': data['name'] ?? 'Sin nombre',
          'price': price,
          'description': data['description'] ?? '',
          'locationState': _selectedState,
          'locationMunicipality': _municipalityController.text.trim(),
          'contactPhone': _phoneController.text.trim(),
          'imageUrl': finalImageUrl,
          'breed': data['breed'] ?? 'Desconocida',
          'certifications': _certificationsController.text.trim(),
          'status': 'activo',
          'publishDate': FieldValue.serverTimestamp(),
          'sex': data['sex'] ?? 'Desconocido',
          'purpose': data['purpose'] ?? 'Desconocido',
          'birthDate': data['birthDate'],
          'birthWeight': data['birthWeight'],
          'weaningWeight': data['weaningWeight'],
          'vaccinations': data['vaccinations'] ?? [],
        });

        // --- NUEVO: BLOQUEAR EL ANIMAL ACTUALIZANDO SU ESTADO ---
        final animalRef = FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('ranches')
            .doc(_currentRanchId)
            .collection('animals')
            .doc(animalId);

        batch.update(animalRef, {'isPublished': true});
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Animales publicados con éxito!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al publicar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRanch) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        title: const Text('Publicar Animales',
            style: TextStyle(color: Color(0xFF5e3a1c))),
        backgroundColor: const Color(0xFFf5f0e1),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getAnimalsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text(
                          'No tienes animales registrados en este rancho.'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final animalId = doc.id;
                    final isSelected =
                        _selectedAnimalDetails.containsKey(animalId);

                    // --- NUEVO: Detectar si ya está publicado ---
                    final bool isPublished = data['isPublished'] == true;

                    Widget imageWidget;
                    if (_newAnimalImages.containsKey(animalId)) {
                      imageWidget = Image.file(_newAnimalImages[animalId]!,
                          fit: BoxFit.cover);
                    } else if (data['imageUrls'] != null &&
                        (data['imageUrls'] as List).isNotEmpty) {
                      imageWidget = Image.network(data['imageUrls'][0],
                          fit: BoxFit.cover);
                    } else {
                      imageWidget = const Icon(FontAwesomeIcons.cow,
                          color: Colors.grey, size: 25);
                    }

                    return Card(
                      color: isPublished ? Colors.grey.shade200 : Colors.white,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              enabled:
                                  !isPublished, // Evita que lo seleccionen si ya está publicado
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(data['name'] ?? 'Sin nombre',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isPublished
                                                ? Colors.grey
                                                : Colors.black87)),
                                  ),
                                  if (isPublished)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: const Text('Publicado',
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    )
                                ],
                              ),
                              subtitle: Text('Raza: ${data['breed'] ?? 'N/A'}'),
                              secondary: GestureDetector(
                                onTap: isPublished
                                    ? null
                                    : () => _pickImageForAnimal(animalId),
                                child: Opacity(
                                  opacity: isPublished ? 0.5 : 1.0,
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          Border.all(color: Colors.grey[400]!),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      children: [
                                        SizedBox.expand(child: imageWidget),
                                        Positioned(
                                          bottom: 2,
                                          right: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.white70,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.camera_alt,
                                                size: 12,
                                                color: Color(0xFF6b4226)),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              value: isSelected,
                              onChanged: (bool? val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedAnimalDetails[animalId] = data;
                                    _priceControllers[animalId] =
                                        TextEditingController();
                                  } else {
                                    _selectedAnimalDetails.remove(animalId);
                                    _priceControllers[animalId]?.dispose();
                                    _priceControllers.remove(animalId);
                                    _newAnimalImages.remove(animalId);
                                  }
                                });
                              },
                            ),
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 0),
                                child: TextField(
                                  controller: _priceControllers[animalId],
                                  keyboardType: TextInputType.number,
                                  maxLength:
                                      10, // --- NUEVO: LÍMITE DE 10 DÍGITOS ---
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Precio de venta (\$)*', // Asterisco indicando que es obligatorio
                                    prefixIcon: Icon(Icons.attach_money),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    counterText:
                                        '', // Oculta el contador "0/10" para no afear el diseño
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // --- NUEVO: Flexible y SingleChildScrollView EVITAN EL OVERFLOW DEL TECLADO ---
          Flexible(
            flex: 0,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -5))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Datos y Ubicación',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5e3a1c))),
                    const SizedBox(height: 15),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Estado',
                              prefixIcon: const Icon(Icons.map,
                                  color: Color(0xFFc99450)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 15),
                            ),
                            isExpanded: true,
                            value: _selectedState,
                            items: _states
                                .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedState = val!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: TextField(
                            controller: _municipalityController,
                            maxLength: 50,
                            decoration: InputDecoration(
                              labelText: 'Ciudad/Municipio',
                              prefixIcon: const Icon(Icons.location_city,
                                  color: Color(0xFFc99450)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 15),
                              counterText: '',
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: InputDecoration(
                        labelText: 'WhatsApp (10 dígitos)',
                        prefixIcon: const Icon(FontAwesomeIcons.whatsapp,
                            color: Colors.green),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _certificationsController,
                      maxLength: 500,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText:
                            'Certificaciones, Registros o Premios (Opcional)',
                        hintText: 'Ej. Registro Cebú, Campeón de Feria...',
                        prefixIcon: const Icon(FontAwesomeIcons.award,
                            color: Color(0xFFc99450)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            _isPublishing ? null : _publishSelectedAnimals,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6b4226),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isPublishing
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Publicar en el Marketplace',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
