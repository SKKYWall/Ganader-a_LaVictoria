// lib/screens/inventario/inventory_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:manual_ganadero_flutter/models/product.dart';
import 'package:manual_ganadero_flutter/screens/inventario/add_edit_product_screen.dart';
import 'package:manual_ganadero_flutter/screens/inventario/product_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String? _selectedCategory;
  String? _currentRanchId;
  bool _isLoadingRanch = true;

  // Define tus categorías
  final List<Map<String, dynamic>> _categories = const [
    {'name': 'Salud', 'icon': Icons.healing, 'color': Colors.pink},
    {
      'name': 'Alimentación',
      'icon': Icons.restaurant_menu,
      'color': Colors.lightGreen
    },
    {
      'name': 'Herramientas y equipo',
      'icon': Icons.build,
      'color': Colors.orange
    },
    {
      'name': 'Suministros y consumibles',
      'icon': Icons.local_mall,
      'color': Colors.blue
    },
    {
      'name': 'Documentación y registros',
      'icon': Icons.description,
      'color': Colors.purple
    },
    {
      'name': 'Tecnología y automatización',
      'icon': Icons.devices_other,
      'color': Colors.cyan
    },
    {'name': 'Maquinaria', 'icon': Icons.agriculture, 'color': Colors.brown},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentRanchId();
  }

  Future<void> _loadCurrentRanchId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _currentRanchId = doc.data()?['currentRanchId'];
          _isLoadingRanch = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRanch = false;
        });
      }
    }
  }

  // --- FUNCIÓN PARA OBTENER EL STREAM DE PRODUCTOS DE ESTE RANCHO ---
  Stream<QuerySnapshot> _getProductsStream() {
    if (_currentRanchId == null) return const Stream.empty();

    final user = FirebaseAuth.instance.currentUser; // <-- Obtener usuario
    if (user == null) return const Stream.empty();

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users') // <-- NUEVO
        .doc(user.uid) // <-- NUEVO
        .collection('ranches')
        .doc(_currentRanchId)
        .collection('products')
        .orderBy('name', descending: false);

    // Aplica el filtro de categoría SOLO si se ha seleccionado una
    if (_selectedCategory != null) {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return query.snapshots();
  }

  // Función para navegar a la pantalla de añadir/editar producto
  Future<void> _navigateToAddEditProductScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditProductScreen(),
      ),
    );
    if (result == true) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
              'Error: Usuario no autenticado. Por favor, reinicia la aplicación.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        backgroundColor: const Color(0xFFf5f0e1),
        title: const Text(
          'Inventario',
          style: TextStyle(
            color: Color(0xFF5e3a1c),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF5e3a1c)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo de búsqueda
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar producto',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF5e3a1c)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // --- FILTROS DE CATEGORÍA CON CHIPS DESLIZABLES ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildFilterChip(
                      label: 'Ver todo',
                      icon: Icons.grid_view,
                      color: Colors.grey[300],
                      isSelected: _selectedCategory == null,
                      onTap: () {
                        setState(() {
                          _selectedCategory = null;
                        });
                      },
                    );
                  }
                  final category = _categories[index - 1];
                  return _buildFilterChip(
                    label: category['name'],
                    icon: category['icon'],
                    color: (category['color'] as Color).withOpacity(0.1),
                    isSelected: _selectedCategory == category['name'],
                    onTap: () {
                      setState(() {
                        _selectedCategory = category['name'];
                      });
                    },
                  );
                },
              ),
            ),
          ),
          // --- FIN FILTROS DE CATEGORÍA ---

          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              _selectedCategory == null
                  ? 'Todo el Inventario'
                  : 'Inventario de $_selectedCategory',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5e3a1c),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // --- LISTA DE PRODUCTOS ---
          Expanded(
            child: _buildInventoryContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddEditProductScreen,
        backgroundColor: const Color(0xFF6b4226),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // Se encarga de mostrar la carga, error de rancho o el StreamBuilder
  Widget _buildInventoryContent() {
    if (_isLoadingRanch) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF6b4226)));
    }

    if (_currentRanchId == null) {
      return const Center(
          child: Text('No hay rancho seleccionado. Ve a tu perfil.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _getProductsStream(),
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
          return Center(
              child: Text(
            _selectedCategory == null
                ? 'No hay productos en tu inventario.'
                : 'No hay productos en la categoría "$_selectedCategory".',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ));
        }

        final products = snapshot.data!.docs.map((doc) {
          return Product.fromFirestore(
              doc.data() as Map<String, dynamic>, doc.id);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _buildProductCard(product);
          },
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required Color? color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        width: 80,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF6b4226) : color,
                border: Border.all(
                  color:
                      isSelected ? const Color(0xFF6b4226) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF5e3a1c),
                size: 30,
              ),
            ),
            const SizedBox(height: 5),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? const Color(0xFF6b4226)
                      : const Color(0xFF5e3a1c),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(productId: product.id),
          ),
        );
        if (result == true) {
          setState(() {});
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        elevation: 2,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFf5f0e1),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: const Icon(Icons.inventory_2,
                    size: 40, color: Color(0xFF6b4226)),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5e3a1c),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.subCategory,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cantidad: ${product.quantity} ${product.unit}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6b4226),
                      ),
                    ),
                    if (product.price != null)
                      Text(
                        'Precio: \$${product.price!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFc99450),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
