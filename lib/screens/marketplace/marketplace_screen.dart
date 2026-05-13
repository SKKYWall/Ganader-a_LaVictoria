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
                if (isMyListings) return true;
                final name = ((doc.data() as Map)['animalName'] ?? '')
                    .toString()
                    .toLowerCase();
                final breed = ((doc.data() as Map)['breed'] ?? '')
                    .toString()
                    .toLowerCase();
                return name.contains(searchTerm) || breed.contains(searchTerm);
              }).toList();

              if (docs.isEmpty) {
                return const Center(
                    child: Text('No se encontraron resultados.'));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.70, // Ajustado para que quepa la ciudad
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return _buildProductCard(docs[index].id, data);
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
    final imageUrl = data['imageUrl'];

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
              child: Container(
                width: double.infinity,
                color: Colors.grey[300],
                child: imageUrl != null
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    // --- CAMBIO DE ICONO AQUÍ ---
                    : const Icon(FontAwesomeIcons.cow,
                        size: 50, color: Colors.grey),
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
                          color: Color(0xFF6b4226))),
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
