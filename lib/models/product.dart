// lib/models/product.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String category;
  final String subCategory; // Nueva propiedad
  // REMOVIDO: final String description;
  final double quantity;
  final String unit; // e.g., "kg", "litros", "unidades"
  final double? price;
  final String? notes;
  final DateTime entryDate;
  final DateTime? expirationDate; // Nuevo: opcional para algunos productos

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.subCategory, // Obligatoria
    // REMOVIDO: required this.description,
    required this.quantity,
    required this.unit,
    this.price,
    this.notes,
    required this.entryDate,
    this.expirationDate, // Puede ser null
  });

  // Constructor para crear un Product desde un documento de Firestore
  factory Product.fromFirestore(Map<String, dynamic> data, String id) {
    return Product(
      id: id,
      name: data['name'] as String,
      category: data['category'] as String,
      subCategory: data['subCategory'] as String, // Cargar subCategory
      // REMOVIDO: description: data['description'] as String,
      quantity: (data['quantity'] as num).toDouble(),
      unit: data['unit'] as String,
      price: (data['price'] as num?)?.toDouble(),
      notes: data['notes'] as String?,
      entryDate: (data['entryDate'] as Timestamp).toDate(),
      expirationDate: (data['expirationDate'] as Timestamp?)
          ?.toDate(), // Cargar expirationDate
    );
  }

  // Método para convertir un Product a un mapa para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'subCategory': subCategory, // Guardar subCategory
      // REMOVIDO: 'description': description,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'notes': notes,
      'entryDate': Timestamp.fromDate(entryDate),
      'expirationDate': expirationDate != null
          ? Timestamp.fromDate(expirationDate!)
          : null, // Guardar expirationDate
    };
  }
}
