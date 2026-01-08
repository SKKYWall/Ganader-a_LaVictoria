// lib/screens/marketplace/marketplace_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Asegúrate de tener tu modelo Animal

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _searchController.dispose();
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
          'Marketplace Ganadero',
          style: TextStyle(
            color: Color(0xFF5e3a1c),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF5e3a1c)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar un vendedor o animal',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF5e3a1c)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
              ),
              onChanged: (value) {
                // Implementar lógica de búsqueda si es necesario
              },
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                // Sección "Tus animales publicados"
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Tus animales publicados',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5e3a1c),
                    ),
                  ),
                ),
                _buildPublishedAnimalsSection(_currentUser!.uid,
                    isUserAnimals: true),
                const SizedBox(height: 20),

                // Sección "Todos los animales en venta"
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Todos los animales en venta',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5e3a1c),
                    ),
                  ),
                ),
                _buildPublishedAnimalsSection(_currentUser!.uid,
                    isUserAnimals:
                        false), // isUserAnimals false para mostrar todos
                const SizedBox(
                    height: 80), // Espacio para el FloatingActionButton
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/selectAnimalToPublish');
        },
        label: const Text(
          'Publicar un animal',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF6b4226),
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildPublishedAnimalsSection(String currentUserId,
      {required bool isUserAnimals}) {
    // La colección 'marketplace_listings' es global, pero cada documento tendrá un 'ownerId'
    // que podremos usar para filtrar si son 'Tus animales publicados' o 'Todos los animales'
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('marketplace_listings');

    if (isUserAnimals) {
      // Si son "Tus animales publicados", filtramos por el ownerId del usuario actual
      query = query.where('ownerId', isEqualTo: currentUserId);
    }
    // Si no es isUserAnimals, no se añade ningún filtro, mostrando todos.

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                isUserAnimals
                    ? 'Aún no has publicado ningún animal.'
                    : 'No hay animales publicados en el marketplace.',
                style: const TextStyle(color: Color(0xFF5e3a1c)),
              ),
            ),
          );
        }

        final listings = snapshot.data!.docs;

        return SizedBox(
          height: 200, // Altura fija para el ListView horizontal
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final listing = listings[index].data() as Map<String, dynamic>;
              final String animalId = listings[index]
                  .id; // El ID del listing en marketplace_listings
              final String animalName =
                  listing['animalName'] ?? 'Animal Desconocido';
              final double price =
                  (listing['price'] as num?)?.toDouble() ?? 0.0;
              final String imageUrl = listing['imageUrl'] ??
                  'https://via.placeholder.com/150'; // Placeholder
              final String ownerId =
                  listing['ownerId']; // Obtener el ownerId del listing

              return GestureDetector(
                onTap: () {
                  // Al tocar un animal, navega a la pantalla de detalles del marketplace
                  // Pasa el ID del listing, no el ID del animal original si es diferente
                  Navigator.pushNamed(
                    context,
                    '/marketplaceProductDetail',
                    arguments: {
                      'listingId':
                          animalId, // Este es el ID del documento en 'marketplace_listings'
                      'ownerId':
                          ownerId, // Necesitamos el ownerId para ir a la colección original de animales
                      'originalAnimalId': listing[
                          'originalAnimalId'] // El ID original del animal del usuario
                    },
                  );
                },
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10.0)),
                        child: Image.network(
                          imageUrl,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            height: 100,
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: Icon(Icons.image, color: Colors.grey[600]),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              animalName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF5e3a1c),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFFc99450),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
