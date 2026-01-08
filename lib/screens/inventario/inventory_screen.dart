// lib/screens/inventario/inventory_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:manual_ganadero_flutter/models/product.dart'; // Importa tu modelo Product
import 'package:manual_ganadero_flutter/screens/inventario/add_edit_product_screen.dart'; // Crearemos esta pantalla
import 'package:manual_ganadero_flutter/screens/inventario/product_detail_screen.dart'; // Crearemos esta pantalla

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String? _selectedCategory; // Para el filtro de categoría

  // Define tus categorías (estas ya estaban en tu código)
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

  // Función para navegar a la pantalla de añadir/editar producto
  Future<void> _navigateToAddEditProductScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditProductScreen(),
      ),
    );
    // Si se añade o edita un producto, fuerza una reconstrucción del StreamBuilder
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
        // Eliminado el IconButton del AppBar, su funcionalidad se moverá al FAB
        // actions: [
        //   IconButton(
        //     icon:
        //         const Icon(Icons.add_circle_outline, color: Color(0xFF5e3a1c)),
        //     onPressed: _navigateToAddEditProductScreen,
        //   ),
        // ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo de búsqueda (se mantiene igual)
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

          // --- FILTROS DE CATEGORÍA CON "BOLITAS" (CHIPS DESLIZABLES) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              height: 100, // Altura para los chips deslizables
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length + 1, // +1 para el chip "Ver todo"
                itemBuilder: (context, index) {
                  // Primer chip: "Ver todo"
                  if (index == 0) {
                    return _buildFilterChip(
                      label: 'Ver todo',
                      icon: Icons.grid_view,
                      color: Colors.grey[300], // Color para el chip "Ver todo"
                      isSelected: _selectedCategory ==
                          null, // Seleccionado si no hay categoría específica
                      onTap: () {
                        setState(() {
                          _selectedCategory =
                              null; // Quita el filtro de categoría
                        });
                      },
                    );
                  }
                  // Chips para cada categoría definida
                  final category = _categories[index - 1]; // Ajusta el índice
                  return _buildFilterChip(
                    label: category['name'],
                    icon: category['icon'],
                    // Usa el color definido para el icono, y un fondo con opacidad
                    color: (category['color'] as Color).withOpacity(0.1),
                    isSelected: _selectedCategory ==
                        category[
                            'name'], // Seleccionado si coincide con la categoría
                    onTap: () {
                      setState(() {
                        _selectedCategory = category[
                            'name']; // Establece la categoría seleccionada
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
                  : 'Inventario de ${_selectedCategory!}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5e3a1c),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // La fuente de datos es ahora el Stream que aplica el filtro de Firestore
              stream: _getProductsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF6b4226)),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                      child: Text(_selectedCategory == null
                          ? 'No hay productos en el inventario.'
                          : 'No hay productos en la categoría "${_selectedCategory!}".'));
                }

                // Mapeamos los documentos a tu modelo Product
                final products = snapshot.data!.docs.map((doc) {
                  return Product.fromFirestore(
                      doc.data() as Map<String, dynamic>, doc.id);
                }).toList();

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                  itemCount: products.length, // Usamos 'products' directamente
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _buildProductCard(product);
                  },
                );
              },
            ),
          ),
        ],
      ),
      // FloatingActionButton ahora tiene la funcionalidad del "+" de la parte superior
      floatingActionButton: FloatingActionButton(
        onPressed:
            _navigateToAddEditProductScreen, // Llama a la función para añadir producto
        backgroundColor: const Color(0xFF6b4226),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- FUNCIÓN PARA OBTENER EL STREAM DE PRODUCTOS (CON FILTRO DE FIRESTORE) ---
  Stream<QuerySnapshot> _getProductsStream(String userId) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('products')
        .orderBy('name', descending: false); // Siempre ordenar por nombre

    // Aplica el filtro de categoría SOLO si se ha seleccionado una
    if (_selectedCategory != null) {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return query.snapshots();
  }
  // --- FIN FUNCIÓN DE STREAM ---

  // --- MÉTODO _buildFilterChip (Modificado para resolver overflow en el label) ---
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
            // Envuelto en Flexible y un Row para permitir que el texto se ajuste
            Flexible(
              // <--- Nuevo: Flexible para permitir que el texto se ajuste
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11, // Reducido ligeramente el tamaño de la fuente
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
  // --- FIN MÉTODO _buildFilterChip ---

  // Método _buildProductCard (Modificado para mostrar cantidad y precio en líneas separadas)
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
          setState(() {}); // Esto forzará una reconstrucción del StreamBuilder
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
                  // Eliminado: image: product.imageUrl...
                ),
                // Icono predeterminado ya que no hay imagen de URL
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
                    // Muestra la subcategoría en lugar de la descripción
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
                    // --- CAMBIO AQUÍ: CANTIDAD Y PRECIO EN LÍNEAS SEPARADAS ---
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
                        'Precio: \$${product.price!.toStringAsFixed(2)}', // Agregado "Precio:"
                        style: const TextStyle(
                          fontSize: 15, // Ligeramente más grande para el precio
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFc99450),
                        ),
                      ),
                    // --- FIN CAMBIO ---
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
