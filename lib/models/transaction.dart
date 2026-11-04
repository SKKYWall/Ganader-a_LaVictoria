// lib/models/transaction.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Transaction {
  final String id;
  final String type; // 'income' o 'expense'
  final double amount;
  final String category;
  final String? subCategory; // Opcional, para egresos más detallados
  final String? notes; // Observaciones
  final DateTime date;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.subCategory,
    this.notes,
    required this.date,
  });

  // Factory constructor para crear una instancia de Transaction desde Firestore
  factory Transaction.fromFirestore(Map<String, dynamic> data, String id) {
    return Transaction(
      id: id,
      type: data['type'] as String,
      amount: (data['amount'] as num).toDouble(),
      category: data['category'] as String,
      subCategory: data['subCategory'] as String?,
      notes: data['notes'] as String?,
      date: (data['date'] as Timestamp).toDate(),
    );
  }

  // Método para convertir una instancia de Transaction a un mapa para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'amount': amount,
      'category': category,
      'subCategory': subCategory,
      'notes': notes,
      'date': Timestamp.fromDate(date),
    };
  }
}
