// lib/screens/bovino_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:manual_ganadero_flutter/screens/bovino/register_animal_screen.dart';
import 'package:manual_ganadero_flutter/screens/bovino/animal_detail_screen.dart';
import 'package:manual_ganadero_flutter/screens/bovino/edit_animal_screen.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:intl/intl.dart'; // Para formatear fechas
import 'package:manual_ganadero_flutter/services/notification_service.dart';
import 'package:manual_ganadero_flutter/widgets/live_voice_dialog.dart'; // <-- AGREGAR ESTO
import 'package:manual_ganadero_flutter/widgets/animal_exit_dialog.dart';

class BovinoScreen extends StatefulWidget {
  const BovinoScreen({super.key});

  @override
  State<BovinoScreen> createState() => _BovinoScreenState();
}

class _BovinoScreenState extends State<BovinoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  late final Stream<User?> _authStateChanges;

  String _searchText = '';
  String _selectedFilter = 'Todos';
  String _selectedOrder = 'name_asc';
  bool _showArchived = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _authStateChanges = FirebaseAuth.instance.authStateChanges();
    _authStateChanges.listen((user) {
      setState(() {
        _currentUser = user;
        debugPrint('Usuario logueado UID: ${_currentUser?.uid}');
      });
    });
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper para formatear fechas de tipo DateTime
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime != null) {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
    return 'N/A';
  }

// --- INICIO DE MODIFICACIÓN MULTI-RANCHO ---
  // Ahora recibe el ranchId como parámetro
  Stream<QuerySnapshot> _getAnimalsStream(String currentRanchId) {
    if (_currentUser == null) {
      debugPrint(
          'Advertencia: No hay usuario autenticado. No se pueden cargar animales.');
      return Stream.empty();
    }

    Query query = _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('ranches') // <-- NUEVO
        .doc(currentRanchId) // <-- NUEVO
        .collection('animals');

    debugPrint(
        'Consultando animales para userId: ${_currentUser!.uid} en rancho: $currentRanchId');

    if (_searchText.isNotEmpty) {
      String searchEnd = '$_searchText\uf8ff';
      query = query
          .where('name', isGreaterThanOrEqualTo: _searchText)
          .where('name', isLessThanOrEqualTo: searchEnd);
      debugPrint('Filtro de búsqueda: "$_searchText"');
    }

    if (_selectedFilter == 'Macho' || _selectedFilter == 'Hembra') {
      query = query.where('sex', isEqualTo: _selectedFilter);
      debugPrint('Filtro por sexo: $_selectedFilter');
    }

    if (_selectedFilter == 'Joven') {
      debugPrint('Filtro por edad: Joven');
    } else if (_selectedFilter == 'Adulto') {
      debugPrint('Filtro por edad: Adulto');
    }

    switch (_selectedOrder) {
      case 'name_asc':
        query = query.orderBy('name', descending: false);
        break;
      case 'name_desc':
        query = query.orderBy('name', descending: true);
        break;
      case 'age_asc':
        query = query.orderBy('birthDate', descending: false);
        break;
      case 'age_desc':
        query = query.orderBy('birthDate', descending: true);
        break;
      default:
        query = query.orderBy('name', descending: false);
        break;
    }
    debugPrint('Ordenamiento: $_selectedOrder');

    return query.snapshots();
  }
  // --- FIN DE MODIFICACIÓN ---

  // --- Manejo de Acciones ---
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleNavigateToRegisterAnimal() {
    debugPrint('Abrir pantalla para nuevo registro de animal');
    // RegisterAnimalScreen se encargará internamente de obtener el UID al guardar.
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RegisterAnimalScreen()));
  }

  // Navegación para "Detalle del Animal"
  void _handleAnimalPress(String animalId) {
    debugPrint('Navegando a detalle de animal con ID: $animalId');
    if (_currentUser != null) {
      // **** CAMBIO AQUÍ: YA NO PASAMOS userId A AnimalDetailScreen ****
      // AnimalDetailScreen debe obtener el UID internamente, como EditAnimalScreen.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AnimalDetailScreen(
            animalId: animalId,
            // userId: _currentUser!.uid, // ¡ELIMINADO!
          ),
        ),
      );
    } else {
      _showSnackBar('Error: Usuario no autenticado para ver detalles.');
    }
  }

  // Navegación para "Editar Animal"
  void _handleEditAnimal(String animalId) {
    debugPrint('Navegando a edición de animal con ID: $animalId');
    if (_currentUser != null) {
      // **** CAMBIO AQUÍ: YA NO PASAMOS userId A EditAnimalScreen ****
      // EditAnimalScreen ya obtiene el UID internamente.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EditAnimalScreen(
            animalId: animalId,
            // userId: _currentUser!.uid, // ¡ELIMINADO!
          ),
        ),
      );
    } else {
      _showSnackBar('Error: Usuario no autenticado para editar.');
    }
  }

  // Dar de baja (vendido/muerto/error de captura) — flujo compartido con
  // animal_detail_screen.dart, ver lib/widgets/animal_exit_dialog.dart.
  Future<void> _handleDeleteAnimal(Animal animal) async {
    final changed = await showAnimalExitDialog(context, animal);
    if (changed) {
      await NotificationService().cancelNotification(animal.id.hashCode);
    }
  }

  // --- Construcción de la UI ---
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
          'Mis Animales',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5e3a1c),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o # arete',
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF5e3a1c)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    style: const TextStyle(color: Color(0xFF5e3a1c)),
                  ),
                ),
                const SizedBox(width: 10),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list, color: Color(0xFF5e3a1c)),
                  onSelected: (String value) {
                    setState(() {
                      _selectedFilter = value;
                    });
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                        value: 'Todos', child: Text('Todos')),
                    const PopupMenuItem<String>(
                        value: 'Macho', child: Text('Machos')),
                    const PopupMenuItem<String>(
                        value: 'Hembra', child: Text('Hembras')),
                    // const PopupMenuItem<String>(value: 'Joven', child: Text('Jóvenes (<2 años)')),
                    // const PopupMenuItem<String>(value: 'Adulto', child: Text('Adultos (>=2 años)')),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort, color: Color(0xFF5e3a1c)),
                  onSelected: (String value) {
                    setState(() {
                      _selectedOrder = value;
                    });
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                        value: 'name_asc', child: Text('Nombre (A-Z)')),
                    const PopupMenuItem<String>(
                        value: 'name_desc', child: Text('Nombre (Z-A)')),
                    const PopupMenuItem<String>(
                        value: 'age_asc', child: Text('Edad (Menor a Mayor)')),
                    const PopupMenuItem<String>(
                        value: 'age_desc', child: Text('Edad (Mayor a Menor)')),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Activos'),
                  selected: !_showArchived,
                  onSelected: (_) => setState(() => _showArchived = false),
                  selectedColor: const Color(0xFFc99450),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Archivados'),
                  selected: _showArchived,
                  onSelected: (_) => setState(() => _showArchived = true),
                  selectedColor: const Color(0xFFc99450),
                ),
              ],
            ),
          ),
          // --- INICIO DE MODIFICACIÓN MULTI-RANCHO ---
          Expanded(
            child: _currentUser == null
                ? const Center(
                    child: Text('Inicia sesión para ver tus animales.'),
                  )
                : StreamBuilder<DocumentSnapshot>(
                    // 1. Primero escuchamos el documento del usuario para saber el rancho
                    stream: _firestore
                        .collection('users')
                        .doc(_currentUser!.uid)
                        .snapshots(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF6b4226))));
                      }

                      String? currentRanchId = (userSnapshot.data?.data()
                          as Map<String, dynamic>?)?['currentRanchId'];

                      if (currentRanchId == null) {
                        return const Center(
                            child: Text(
                                'Por favor selecciona o registra un rancho desde el Inicio.',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey)));
                      }

                      // 2. Ahora escuchamos los animales de ESE rancho
                      return StreamBuilder<QuerySnapshot>(
                        stream: _getAnimalsStream(
                            currentRanchId), // Le pasamos el ID del rancho
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF6b4226)),
                            ));
                          }
                          if (snapshot.hasError) {
                            return Center(
                                child: Text('Error: ${snapshot.error}'));
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                                child: Text('No hay animales registrados.'));
                          }

                          final wantedStatus =
                              _showArchived ? 'inactivo' : 'activo';
                          final animals = snapshot.data!.docs
                              .map((doc) => Animal.fromFirestore(
                                  doc.data() as Map<String, dynamic>, doc.id))
                              .where((a) => a.status == wantedStatus)
                              .toList();

                          if (animals.isEmpty) {
                            return Center(
                              child: Text(_showArchived
                                  ? 'No tienes animales archivados.'
                                  : 'No hay animales registrados.'),
                            );
                          }

                          return ListView.builder(
                            itemCount: animals.length,
                            itemBuilder: (context, index) {
                              final animal = animals[index];
                              return _buildAnimalCard(animal);
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
// --- FIN DE MODIFICACIÓN ---
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // BOLITA DEL MICRÓFONO
          FloatingActionButton(
            heroTag: "btn_voice",
            onPressed: () {
              LiveVoiceDialog.show(context); // <-- LLAMA A LA NUEVA PANTALLA
            },
            backgroundColor: const Color(0xFFc99450), // Color fijo
            foregroundColor: Colors.white,
            child: const Icon(Icons.mic),
          ),
          const SizedBox(width: 15), // Espacio entre las dos bolitas

          // BOLITA DE REGISTRO ORIGINAL
          FloatingActionButton(
            heroTag: "btn_add",
            onPressed: _handleNavigateToRegisterAnimal,
            backgroundColor: const Color(0xFF6b4226),
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  // Tarjeta de animal individual
  Widget _buildAnimalCard(Animal animal) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      elevation: 2,
      child: InkWell(
        onTap: () => _handleAnimalPress(animal.id),
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen o ícono de placeholder
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFf5f0e1),
                  borderRadius: BorderRadius.circular(8.0),
                  image: animal.profileImageUrl != null &&
                          animal.profileImageUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(animal.profileImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: animal.profileImageUrl == null ||
                        animal.profileImageUrl!.isEmpty
                    ? const Icon(
                        Icons.grass, // Ícono genérico de bovino
                        size: 40,
                        color: Color(0xFF5e3a1c),
                      )
                    : null,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      animal.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF5e3a1c),
                      ),
                    ),
                    _buildInfoRow('Raza', animal.breed),
                    _buildInfoRow('Sexo', animal.sex),
                    _buildInfoRow('Arete', animal.earTagNumber),
                    // MODIFICACIÓN: Mostrar Fecha de Nacimiento en lugar de Edad
                    _buildInfoRow('Fecha de Nacimiento',
                        _formatDateTime(animal.birthDate)),
                    _buildInfoRow('Propósito', animal.purpose),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Botones de Editar y Eliminar
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFFc99450)),
                    onPressed: () => _handleEditAnimal(animal.id),
                    tooltip: 'Editar Animal',
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    onPressed: () => _handleDeleteAnimal(animal),
                    tooltip: 'Dar de baja',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Función de utilidad para construir filas de información detallada (sin cambios)
  Widget _buildInfoRow(String label, String? value) {
    String displayValue =
        (value == null || value.isEmpty || value == 'null') ? 'N/A' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5e3a1c),
              ),
            ),
            TextSpan(
              text: displayValue,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
