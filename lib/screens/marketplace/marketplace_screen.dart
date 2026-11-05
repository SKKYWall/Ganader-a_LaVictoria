// lib/screens/marketplace/marketplace_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // <-- NUEVA IMPORTACIÓN
import 'package:manual_ganadero_flutter/screens/marketplace/marketplace_product_detail_screen.dart';
import 'package:manual_ganadero_flutter/screens/marketplace/select_animal_to_publish_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String _selectedState = 'Todos';
  final List<String> _states = [
    'Todos',
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
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFfbf6ec),
        appBar: AppBar(
          backgroundColor: const Color(0xFFf5f0e1),
          title: const Text('Marketplace',
              style: TextStyle(
                  color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Color(0xFF5e3a1c)),
          bottom: const TabBar(
            indicatorColor: Color(0xFFc99450),
            labelColor: Color(0xFF5e3a1c),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.explore), text: 'Explorar'),
              Tab(icon: Icon(Icons.store), text: 'Mis Publicaciones'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTabContent(isMyListings: false), // Explorar
            _buildTabContent(isMyListings: true), // Mis Publicaciones
          ],
        ),
        // --- BOTÓN FLOTANTE PARA PUBLICAR ANIMAL ---
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SelectAnimalToPublishScreen()),
            );
          },
          backgroundColor: const Color(0xFF6b4226),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Publicar Animal',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildTabContent({required bool isMyListings}) {
    return Column(
      children: [
        if (!isMyListings)
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar raza o animal...',
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF5e3a1c)),
                    filled: true,
                    fillColor: const Color(0xFFfbf6ec),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedState,
                          items: _states
                              .map((s) =>
                                  DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedState = val!),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildQuery(isMyListings).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFc99450)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                    child: Text(isMyListings
                        ? 'No tienes publicaciones activas.'
                        : 'No hay animales en esta zona.'));
              }

              final searchTerm = _searchController.text.toLowerCase();
              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (isMyListings) return true;
                // En Explorar solo se muestran publicaciones activas — lo
                // vendido/pausado desaparece sin necesidad de borrarlo.
                if ((data['status'] as String? ?? 'activo') != 'activo') {
                  return false;
                }
                final name = (data['animalName'] ?? '').toString().toLowerCase();
                final breed = (data['breed'] ?? '').toString().toLowerCase();
                return name.contains(searchTerm) || breed.contains(searchTerm);
              }).toList();

              // Más recientes primero, tope de 50 para no cargar un catálogo
              // ilimitado en memoria (sin depender de un índice compuesto de
              // Firestore para orderBy + where).
              docs.sort((a, b) {
                final da = (a.data() as Map)['publishDate'];
                final db = (b.data() as Map)['publishDate'];
                if (da is! Timestamp || db is! Timestamp) return 0;
                return db.compareTo(da);
              });
              final visibleDocs = docs.take(50).toList();

              if (visibleDocs.isEmpty) {
                return const Center(
                    child: Text('No se encontraron resultados.'));
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth > 600 ? 3 : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.70,
                    ),
                    itemCount: visibleDocs.length,
                    itemBuilder: (context, index) {
                      final data =
                          visibleDocs[index].data() as Map<String, dynamic>;
                      return _buildProductCard(visibleDocs[index].id, data);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Query _buildQuery(bool isMyListings) {
    Query query = FirebaseFirestore.instance.collection('marketplace_listings');
    if (isMyListings) {
      query = query.where('ownerId', isEqualTo: _currentUser?.uid);
    } else {
      if (_selectedState != 'Todos') {
        query = query.where('locationState', isEqualTo: _selectedState);
      }
    }
    return query;
  }

  Widget _buildProductCard(String id, Map<String, dynamic> data) {
    final animalName = data['animalName'] ?? 'Sin nombre';
    final price = data['price']?.toString() ?? '0.00';
    final state = data['locationState'] ?? 'Ubicación desconocida';
    final municipality = data['locationMunicipality'] ?? '';
    final fullLocation =
        municipality.isNotEmpty ? '$municipality, $state' : state;
    final imageUrls = data['imageUrls'] is List
        ? List<String>.from(data['imageUrls'])
        : (data['imageUrl'] != null
            ? [data['imageUrl'] as String]
            : const <String>[]);
    final imageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;
    final isSold = data['status'] == 'vendido';

    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => MarketplaceProductDetailScreen(listingId: id)));
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        clipBehavior: Clip.antiAlias,
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: imageUrl != null
                        ? Image.network(imageUrl, fit: BoxFit.cover)
                        // --- CAMBIO DE ICONO AQUÍ ---
                        : const Icon(FontAwesomeIcons.cow,
                            size: 50, color: Colors.grey),
                  ),
                  if (isSold)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red[700],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('VENDIDO',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('\$$price',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6b4226)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(animalName,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 3),
                      Expanded(
                          child: Text(fullLocation,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis)),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
