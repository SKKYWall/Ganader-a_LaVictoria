// lib/screens/marketplace/select_animal_to_publish_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:manual_ganadero_flutter/models/animal.dart'; // Tu modelo Animal
import 'package:flutter/services.dart'; // Para FilteringTextInputFormatter

class SelectAnimalToPublishScreen extends StatefulWidget {
  const SelectAnimalToPublishScreen({super.key});

  @override
  State<SelectAnimalToPublishScreen> createState() =>
      _SelectAnimalToPublishScreenState();
}

class _SelectAnimalToPublishScreenState
    extends State<SelectAnimalToPublishScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  // Mapa para almacenar los controladores de texto de los precios de los animales seleccionados
  final Map<String, TextEditingController> _selectedAnimalPrices = {};
  // Mapa para almacenar los objetos Animal de los seleccionados para fácil acceso
  final Map<String, Animal> _selectedAnimalDetails = {};

  @override
  void dispose() {
    // Liberar todos los controladores de texto al destruir el widget
    _selectedAnimalPrices.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Usuario no autenticado.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        backgroundColor: const Color(0xFFf5f0e1),
        title: const Text(
          'Seleccionar Animales para Publicar',
          style: TextStyle(
            color: Color(0xFF5e3a1c),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF5e3a1c)),
        actions: [
          // Habilitar botón solo si hay selecciones con precios válidos
          if (_selectedAnimalPrices.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFF5e3a1c)),
              onPressed: _publishSelectedAnimals,
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('animals')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6b4226)),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('No tienes animales registrados para publicar.'));
          }

          final animals = snapshot.data!.docs.map((doc) {
            return Animal.fromFirestore(
                doc.data() as Map<String, dynamic>, doc.id);
          }).toList();

          return ListView.builder(
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final animal = animals[index];
              final isSelected = _selectedAnimalPrices.containsKey(animal.id);

              return FutureBuilder<QuerySnapshot>(
                // Check if this animal is already published
                future: FirebaseFirestore.instance
                    .collection('marketplace_listings')
                    .where('ownerId', isEqualTo: _currentUser!.uid)
                    .where('originalAnimalId', isEqualTo: animal.id)
                    .limit(1) // We only need to find one to know it exists
                    .get(),
                builder: (context, publishedSnapshot) {
                  bool isAlreadyPublished = false;
                  if (publishedSnapshot.connectionState ==
                          ConnectionState.done &&
                      publishedSnapshot.hasData) {
                    isAlreadyPublished =
                        publishedSnapshot.data!.docs.isNotEmpty;
                  }

                  return GestureDetector(
                    onTap: () {
                      if (!isAlreadyPublished) {
                        setState(() {
                          if (isSelected) {
                            // Si ya está seleccionado, lo deselecciona y libera el controlador
                            _selectedAnimalPrices[animal.id]?.dispose();
                            _selectedAnimalPrices.remove(animal.id);
                            _selectedAnimalDetails.remove(animal.id);
                          } else {
                            // Si no está seleccionado, lo selecciona y crea un nuevo controlador
                            _selectedAnimalPrices[animal.id] =
                                TextEditingController();
                            _selectedAnimalDetails[animal.id] = animal;
                          }
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Este animal ya está publicado en el Marketplace.'),
                          ),
                        );
                      }
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      color: isSelected
                          ? const Color(0xFFf5f0e1) // Color para seleccionado
                          : (isAlreadyPublished
                              ? Colors.grey[200] // Dim if already published
                              : Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(
                                  0xFF6b4226) // Borde para seleccionado
                              : (isAlreadyPublished
                                  ? Colors.grey // Borde para ya publicado
                                  : Colors.transparent),
                          width: 2.0,
                        ),
                      ),
                      elevation: 2, // Sombra suave
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Imagen/Icono del animal
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFfbf6ec),
                                    borderRadius: BorderRadius.circular(8.0),
                                    // Si hay profileImageUrl, la muestra. De lo contrario, usa el icono.
                                    image: animal.profileImageUrl != null &&
                                            animal.profileImageUrl!.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(
                                                animal.profileImageUrl!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: animal.profileImageUrl == null ||
                                          animal.profileImageUrl!.isEmpty
                                      ? const Icon(
                                          Icons.grass, // Ícono de bovino
                                          size: 30,
                                          color: Color(0xFF5e3a1c),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        animal.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isAlreadyPublished
                                              ? Colors.grey[600]
                                              : const Color(0xFF5e3a1c),
                                        ),
                                      ),
                                      Text(
                                        'Raza: ${animal.breed ?? 'N/A'}',
                                        style:
                                            TextStyle(color: Colors.grey[600]),
                                      ),
                                      Text(
                                        'Sexo: ${animal.sex ?? 'N/A'}',
                                        style:
                                            TextStyle(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF6b4226),
                                    size: 28,
                                  )
                                else if (isAlreadyPublished)
                                  const Icon(
                                    Icons
                                        .published_with_changes, // Ícono para ya publicado
                                    color: Colors.green,
                                    size: 28,
                                  ),
                              ],
                            ),
                            if (isSelected) // Mostrar campo de precio solo si está seleccionado
                              Padding(
                                padding: const EdgeInsets.only(top: 15.0),
                                child: TextFormField(
                                  controller: _selectedAnimalPrices[animal.id],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d+\.?\d{0,2}')),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Precio (MXN)',
                                    prefixIcon: const Icon(Icons.attach_money,
                                        color: Color(0xFF5e3a1c)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFc99450)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFc99450), width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF6b4226), width: 2.0),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    labelStyle: const TextStyle(
                                        color: Color(0xFF5e3a1c)),
                                  ),
                                  style: const TextStyle(color: Colors.black87),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Ingresa un precio';
                                    }
                                    if (double.tryParse(value) == null ||
                                        double.parse(value) <= 0) {
                                      return 'Precio inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _publishSelectedAnimals() async {
    if (_selectedAnimalPrices.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, selecciona al menos un animal.')),
      );
      return;
    }

    // Validar todos los precios antes de intentar publicar
    bool allPricesValid = true;
    for (var entry in _selectedAnimalPrices.entries) {
      final priceText = entry.value.text.trim();
      if (priceText.isEmpty ||
          double.tryParse(priceText) == null ||
          double.parse(priceText) <= 0) {
        allPricesValid = false;
        break;
      }
    }

    if (!allPricesValid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Por favor, ingresa precios válidos para todos los animales seleccionados.')),
      );
      return;
    }

    List<String> successfullyHandledAnimals = [];
    List<String> skippedAnimals = [];

    // Obtener información de contacto del publicador una sola vez
    Map<String, dynamic> publisherContactInfo = {};
    if (_currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          publisherContactInfo['email'] = userDoc.get('email') as String?;
          publisherContactInfo['phone'] = userDoc.get('phone') as String?;
          publisherContactInfo['ranchAddress'] =
              userDoc.get('ranchAddress') as String?;
          publisherContactInfo['socialMediaLinks'] =
              userDoc.get('socialMediaLinks') is Map
                  ? Map<String, dynamic>.from(userDoc.get('socialMediaLinks'))
                  : null;
        }
      } catch (e) {
        print('Error al cargar info de contacto del publicador: $e');
        // No interrumpir la publicación si falla la carga de contacto
      }
    }

    for (var entry in _selectedAnimalPrices.entries) {
      final animalId = entry.key;
      final priceController = entry.value;
      final price = double.parse(priceController.text.trim()); // Ya validado

      try {
        QuerySnapshot existingListings = await FirebaseFirestore.instance
            .collection('marketplace_listings')
            .where('ownerId', isEqualTo: _currentUser!.uid)
            .where('originalAnimalId', isEqualTo: animalId)
            .limit(1)
            .get();

        if (existingListings.docs.isNotEmpty) {
          final animalName = _selectedAnimalDetails[animalId]?.name ?? animalId;
          print('Animal $animalName ya está publicado. Saltando.');
          skippedAnimals.add(animalName);
          continue;
        }

        Animal? animal = _selectedAnimalDetails[animalId];
        if (animal == null) {
          print('Error: No se encontró el objeto Animal para ID $animalId.');
          skippedAnimals.add('ID $animalId');
          continue;
        }

        // Crear el documento en la colección global 'marketplace_listings'
        await FirebaseFirestore.instance
            .collection('marketplace_listings')
            .add({
          'ownerId': _currentUser!.uid,
          'originalAnimalId': animal.id,
          'title': animal.name, // Título del anuncio
          'description': animal.description ??
              'Sin descripción.', // Descripción del animal
          'price': price, // Precio del usuario
          'profileImageUrl':
              animal.profileImageUrl, // URL de imagen de perfil del animal
          'publishedAt': Timestamp.now(),
          'status': 'activo',
          // Copiar todos los demás campos relevantes del animal
          'breed': animal.breed,
          'sex': animal.sex,
          'birthDate': animal.birthDate != null
              ? Timestamp.fromDate(animal.birthDate!)
              : null,
          'earTagNumber': animal.earTagNumber,
          'legNumber': animal.legNumber,
          'location': animal.location,
          'registrationNumber': animal.registrationNumber,
          'birthWeight': animal.birthWeight,
          'weaningWeight': animal.weaningWeight,
          'father': animal.father,
          'mother': animal.mother,
          'diseaseResistance': animal.diseaseResistance,
          'fertilityInfo': animal.fertilityInfo,
          'geneticMarkers': animal.geneticMarkers,
          // Añadir información de contacto del publicador
          if (publisherContactInfo['email'] != null)
            'publisherEmail': publisherContactInfo['email'],
          if (publisherContactInfo['phone'] != null)
            'publisherPhone': publisherContactInfo['phone'],
          if (publisherContactInfo['ranchAddress'] != null)
            'publisherRanchAddress': publisherContactInfo['ranchAddress'],
          if (publisherContactInfo['socialMediaLinks'] != null)
            'publisherSocialMedia': publisherContactInfo['socialMediaLinks'],
        });
        successfullyHandledAnimals.add(animal.name);
        print('Animal ${animal.name} publicado en el marketplace.');
      } catch (e) {
        print('Error al publicar animal $animalId: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al publicar $animalId: ${e.toString()}')),
        );
      }
    }

    if (!mounted) return;

    String message = '';
    if (successfullyHandledAnimals.isNotEmpty) {
      message +=
          'Animales publicados: ${successfullyHandledAnimals.join(', ')}. ';
    }
    if (skippedAnimals.isNotEmpty) {
      message +=
          'Animales ya publicados (omitidos): ${skippedAnimals.join(', ')}. ';
    }

    if (message.isEmpty) {
      message = 'No se realizaron publicaciones.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

    // Clear selected animals and dispose controllers after attempt to publish
    setState(() {
      _selectedAnimalPrices.forEach((key, controller) => controller.dispose());
      _selectedAnimalPrices.clear();
      _selectedAnimalDetails.clear();
    });

    if (!mounted) return;
    Navigator.pop(context, true); // Go back to marketplace and refresh
  }
}
