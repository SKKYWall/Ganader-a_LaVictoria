// lib/screens/bovino_screen.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:manual_ganadero_flutter/screens/bovino/register_animal_screen.dart';
import 'package:manual_ganadero_flutter/screens/bovino/animal_detail_screen.dart';
import 'package:manual_ganadero_flutter/screens/bovino/edit_animal_screen.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:intl/intl.dart'; // Para formatear fechas

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

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _authStateChanges = FirebaseAuth.instance.authStateChanges();
    _authStateChanges.listen((user) {
      setState(() {
        _currentUser = user;
        print('Usuario logueado UID: ${_currentUser?.uid}');
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

  // --- Lógica de Consulta de Firestore ---
  Stream<QuerySnapshot> _getAnimalsStream() {
    if (_currentUser == null) {
      print(
          'Advertencia: No hay usuario autenticado. No se pueden cargar animales.');
      return Stream.empty();
    }

    // CAMBIO CLAVE: Acceder a la subcolección 'animals' dentro del documento del usuario
    Query query = _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('animals');

    print('Consultando animales para userId: ${_currentUser!.uid}');

    if (_searchText.isNotEmpty) {
      String searchEnd = '$_searchText\uf8ff';
      query = query
          .where('name', isGreaterThanOrEqualTo: _searchText)
          .where('name', isLessThanOrEqualTo: searchEnd);
      print('Filtro de búsqueda: "$_searchText"');
    }

    if (_selectedFilter == 'Macho' || _selectedFilter == 'Hembra') {
      query = query.where('sex', isEqualTo: _selectedFilter);
      print('Filtro por sexo: $_selectedFilter');
    }

    // Nota: El campo 'age' no se guarda directamente en Firestore en RegisterAnimalScreen.
    // Necesitarás calcularlo a partir de 'birthDate' si quieres filtrar por edad.
    // Por ahora, estos filtros de edad podrían no funcionar como esperas a menos que 'age'
    // sea un campo que calculas y guardas explícitamente en Firestore.
    // Mantengo la lógica si tienes planes de implementarlo.
    if (_selectedFilter == 'Joven') {
      // Idealmente, aquí deberías calcular la edad en base a birthDate
      // y filtrar, o tener un campo 'age' en Firestore.
      // query = query.where('birthDate', isGreaterThanOrEqualTo: '...');
      print(
          'Filtro por edad: Joven (<= 2 años) - Requiere campo "age" o cálculo de "birthDate"');
    } else if (_selectedFilter == 'Adulto') {
      // Idealmente, aquí deberías calcular la edad en base a birthDate
      // y filtrar, o tener un campo 'age' en Firestore.
      // query = query.where('birthDate', isLessThan: '...');
      print(
          'Filtro por edad: Adulto (> 2 años) - Requiere campo "age" o cálculo de "birthDate"');
    }

    switch (_selectedOrder) {
      case 'name_asc':
        query = query.orderBy('name', descending: false);
        break;
      case 'name_desc':
        query = query.orderBy('name', descending: true);
        break;
      // Los ordenamientos por 'age' también dependerán de tener un campo 'age' numérico
      // o un birthDate formateado para ordenar correctamente.
      case 'age_asc':
        // Podrías ordenar por birthDate si está en formatoYYYY-MM-DD
        query = query.orderBy('birthDate', descending: false);
        break;
      case 'age_desc':
        // Podrías ordenar por birthDate si está en formatoYYYY-MM-DD
        query = query.orderBy('birthDate', descending: true);
        break;
      default:
        query = query.orderBy('name', descending: false);
        break;
    }
    print('Ordenamiento: $_selectedOrder');

    return query.snapshots();
  }

  // --- Manejo de Acciones ---
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleNavigateToRegisterAnimal() {
    print('Abrir pantalla para nuevo registro de animal');
    // RegisterAnimalScreen se encargará internamente de obtener el UID al guardar.
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RegisterAnimalScreen()));
  }

  // Navegación para "Detalle del Animal"
  void _handleAnimalPress(String animalId) {
    print('Navegando a detalle de animal con ID: $animalId');
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
    print('Navegando a edición de animal con ID: $animalId');
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

  // Eliminar Animal
  Future<void> _handleDeleteAnimal(String animalId) async {
    if (_currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario no autenticado.')),
      );
      return;
    }

    // --- NUEVA LÓGICA: Verificar si el animal está publicado en el Marketplace ---
    String? marketplaceListingId;
    try {
      final marketplaceQuery = await _firestore
          .collection('marketplace_listings')
          .where('ownerId', isEqualTo: _currentUser!.uid)
          .where('originalAnimalId', isEqualTo: animalId)
          .limit(1)
          .get();

      if (marketplaceQuery.docs.isNotEmpty) {
        marketplaceListingId = marketplaceQuery.docs.first.id;
      }
    } catch (e) {
      print(
          'Error al verificar publicación en Marketplace desde BovinoScreen: ${e.toString()}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al verificar publicación: ${e.toString()}')),
      );
      return; // Salir si hay un error al verificar
    }

    String confirmationMessage =
        '¿Estás seguro de que quieres eliminar este animal? Esta acción no se puede deshacer.';
    if (marketplaceListingId != null) {
      confirmationMessage +=
          '\n\n¡Advertencia! Este animal también está publicado en el Marketplace y su publicación será eliminada.';
    }

    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Animal',
              style: TextStyle(color: Color(0xFF5e3a1c))),
          content: Text(
            confirmationMessage,
            style: const TextStyle(color: Colors.black87),
          ),
          backgroundColor: const Color(0xFFfbf6ec),
          surfaceTintColor: const Color(0xFFfbf6ec),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF6b4226))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        // Eliminar la publicación del Marketplace si existe
        if (marketplaceListingId != null) {
          try {
            await _firestore
                .collection('marketplace_listings')
                .doc(marketplaceListingId)
                .delete();
            print('Publicación de Marketplace eliminada desde BovinoScreen.');
          } catch (e) {
            print(
                'Advertencia: No se pudo eliminar la publicación del Marketplace desde BovinoScreen: ${e.toString()}');
            // No lanzar el error, solo advertir
          }
        }
        // Eliminar el documento del animal
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('animals')
            .doc(animalId)
            .delete();
        _showSnackBar(
            'Animal y publicaciones asociadas eliminadas exitosamente.');
      } catch (e) {
        print(
            'Error al eliminar animal o publicación desde BovinoScreen: ${e.toString()}');
        _showSnackBar('Error al eliminar animal: ${e.toString()}');
      }
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
          Expanded(
            child: _currentUser == null
                ? const Center(
                    child: Text('Inicia sesión para ver tus animales.'),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: _getAnimalsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF6b4226)),
                        ));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Text('No hay animales registrados.'));
                      }

                      final animals = snapshot.data!.docs.map((doc) {
                        return Animal.fromFirestore(
                            doc.data() as Map<String, dynamic>, doc.id);
                      }).toList();

                      return ListView.builder(
                        itemCount: animals.length,
                        itemBuilder: (context, index) {
                          final animal = animals[index];
                          return _buildAnimalCard(animal);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleNavigateToRegisterAnimal,
        backgroundColor: const Color(0xFF6b4226),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
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
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _handleDeleteAnimal(animal.id),
                    tooltip: 'Eliminar Animal',
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
