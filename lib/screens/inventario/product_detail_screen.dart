// lib/screens/inventario/product_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:manual_ganadero_flutter/models/product.dart';
import 'package:manual_ganadero_flutter/screens/inventario/add_edit_product_screen.dart';
import 'package:intl/intl.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProductDetails();
  }

  Future<void> _loadProductDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Usuario no autenticado.';
        _isLoading = false;
      });
      return;
    }

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('products')
          .doc(widget.productId)
          .get();

      if (docSnapshot.exists) {
        setState(() {
          _product = Product.fromFirestore(
              docSnapshot.data() as Map<String, dynamic>, docSnapshot.id);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Producto no encontrado.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar los detalles del producto: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteProduct() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Usuario no autenticado.')),
      );
      return;
    }

    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content:
            const Text('¿Estás seguro de que quieres eliminar este producto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6b4226))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('products')
            .doc(widget.productId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto eliminado con éxito!')),
          );
          Navigator.pop(
              context, true); // Indicar que hubo un cambio (eliminación)
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar el producto: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        backgroundColor: const Color(0xFFf5f0e1),
        title: Text(
          _product?.name ?? 'Detalle del Producto',
          style: const TextStyle(
            color: Color(0xFF5e3a1c),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF5e3a1c)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF5e3a1c)),
            onPressed: _product == null
                ? null
                : () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddEditProductScreen(product: _product),
                      ),
                    );
                    if (result == true) {
                      _loadProductDetails(); // Recargar los detalles si se editó
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _product == null ? null : _deleteProduct,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6b4226)),
              ),
            )
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _product == null
                  ? const Center(child: Text('No se pudo cargar el producto.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sección de información principal
                          Card(
                            margin: const EdgeInsets.only(bottom: 20),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            elevation: 3,
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFf5f0e1),
                                        borderRadius:
                                            BorderRadius.circular(15.0),
                                      ),
                                      child: const Icon(Icons.inventory_2,
                                          size: 60, color: Color(0xFF6b4226)),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    _product!.name,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF5e3a1c),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildDetailRow(
                                    'Categoría:',
                                    _product!.category,
                                    Icons.category,
                                  ),
                                  _buildDetailRow(
                                    'Subcategoría:',
                                    _product!.subCategory,
                                    Icons.subtitles,
                                  ),
                                  _buildDetailRow(
                                    'Cantidad:',
                                    '${_product!.quantity} ${_product!.unit}',
                                    Icons.numbers,
                                  ),
                                  if (_product!.price != null)
                                    _buildDetailRow(
                                      'Precio:',
                                      '\$${_product!.price!.toStringAsFixed(2)}',
                                      Icons.attach_money,
                                    ),
                                  _buildDetailRow(
                                    'Fecha de Entrada:',
                                    DateFormat('dd/MM/yyyy')
                                        .format(_product!.entryDate),
                                    Icons.date_range,
                                  ),
                                  if (_product!.expirationDate != null)
                                    _buildDetailRow(
                                      'Fecha de Caducidad:',
                                      DateFormat('dd/MM/yyyy')
                                          .format(_product!.expirationDate!),
                                      Icons.calendar_today,
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // REMOVIDO: Sección de Descripción

                          // Sección de Notas Adicionales
                          if (_product!.notes != null &&
                              _product!.notes!.isNotEmpty)
                            Card(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              elevation: 3,
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Notas Adicionales:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF5e3a1c),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _product!.notes!,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF6b4226)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildDetailRow(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFc99450), size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6b4226),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF5e3a1c),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
