// lib/widgets/animal_exit_dialog.dart
//
// Flujo compartido de "dar de baja" a un animal — lo usan animal_detail_screen.dart
// y bovino_screen.dart para no duplicar la misma lógica. Reemplaza el botón de
// "eliminar" directo: vendido/muerto marcan el animal como inactivo (sin
// borrarlo, vía AnimalLifecycleService); "error de captura" sigue siendo un
// borrado total real, como acción explícita y separada.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:manual_ganadero_flutter/services/animal_lifecycle_service.dart';

/// Muestra el flujo completo. Devuelve `true` si el animal cambió de estado
/// o se borró (para que el caller refresque/cierre su pantalla), `false` si
/// se canceló en cualquier punto.
Future<bool> showAnimalExitDialog(BuildContext context, Animal animal) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usuario no autenticado.')),
    );
    return false;
  }

  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFFfbf6ec),
      title: const Text('Dar de baja',
          style:
              TextStyle(color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Qué pasó con ${animal.name}?'),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.sell, color: Color(0xFFc99450)),
            title: const Text('Se vendió'),
            onTap: () => Navigator.pop(ctx, 'vendido'),
          ),
          ListTile(
            leading: const Icon(Icons.heart_broken, color: Colors.grey),
            title: const Text('Murió'),
            onTap: () => Navigator.pop(ctx, 'muerto'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Fue un error de captura',
                style: TextStyle(color: Colors.red)),
            subtitle: const Text('Borra el registro por completo.'),
            onTap: () => Navigator.pop(ctx, 'error_captura'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
      ],
    ),
  );

  if (reason == null || !context.mounted) return false;

  if (reason == 'error_captura') {
    return _confirmHardDelete(context, animal, user.uid);
  }

  final details = await _showExitDetailsDialog(context, reason);
  if (details == null || !context.mounted) return false;

  try {
    final firestore = FirebaseFirestore.instance;
    final userDoc = await firestore.collection('users').doc(user.uid).get();
    final String? currentRanchId = userDoc.data()?['currentRanchId'];
    if (currentRanchId == null) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay rancho seleccionado.')),
      );
      return false;
    }

    await AnimalLifecycleService.recordExit(
      animal: animal,
      userId: user.uid,
      ranchId: currentRanchId,
      reason: reason,
      date: details['date'] as DateTime,
      price: details['price'] as double?,
      notes: details['notes'] as String?,
    );

    if (!context.mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(reason == 'vendido'
              ? 'Animal dado de baja como vendido.'
              : 'Animal dado de baja.')),
    );
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al dar de baja: ${e.toString()}')),
    );
    return false;
  }
}

Future<Map<String, dynamic>?> _showExitDetailsDialog(
    BuildContext context, String reason) async {
  DateTime selectedDate = DateTime.now();
  final priceController = TextEditingController();
  final notesController = TextEditingController();

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: const Color(0xFFfbf6ec),
        title: Text(reason == 'vendido' ? 'Datos de la venta' : 'Datos de la baja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, color: Color(0xFFc99450)),
              title: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setDialogState(() => selectedDate = picked);
                }
              },
            ),
            if (reason == 'vendido')
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Precio de venta (opcional)', prefixText: '\$ '),
              ),
            if (reason == 'muerto')
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Causa (opcional)'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6b4226)),
            onPressed: () {
              final price = double.tryParse(priceController.text.trim());
              Navigator.pop(ctx, {
                'date': selectedDate,
                if (reason == 'vendido' && price != null && price > 0) 'price': price,
                if (reason == 'muerto' && notesController.text.trim().isNotEmpty)
                  'notes': notesController.text.trim(),
              });
            },
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

/// Borrado total real — solo para "fue un error de captura".
Future<bool> _confirmHardDelete(
    BuildContext context, Animal animal, String userId) async {
  final firestore = FirebaseFirestore.instance;
  String? marketplaceListingId;
  try {
    final marketplaceQuery = await firestore
        .collection('marketplace_listings')
        .where('ownerId', isEqualTo: userId)
        .where('animalId', isEqualTo: animal.id)
        .limit(1)
        .get();
    if (marketplaceQuery.docs.isNotEmpty) {
      marketplaceListingId = marketplaceQuery.docs.first.id;
    }
  } catch (e) {
    debugPrint('Error al verificar publicación en Marketplace: $e');
  }

  if (!context.mounted) return false;

  String confirmationMessage =
      'Esto borra el registro por completo, incluyendo su historial. No se puede deshacer.';
  if (marketplaceListingId != null) {
    confirmationMessage +=
        '\n\n¡Advertencia! Este animal también está publicado en el Marketplace y su publicación será eliminada.';
  }

  final bool? confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Borrar definitivamente?',
          style: TextStyle(color: Color(0xFF5e3a1c))),
      content: Text(confirmationMessage, style: const TextStyle(color: Colors.black87)),
      backgroundColor: const Color(0xFFfbf6ec),
      surfaceTintColor: const Color(0xFFfbf6ec),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6b4226))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Borrar', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (confirm != true) return false;

  try {
    if (animal.profileImageUrl != null) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(animal.profileImageUrl!);
        await ref.delete();
      } catch (e) {
        debugPrint('Advertencia: no se pudo eliminar la imagen de perfil: $e');
      }
    }

    if (marketplaceListingId != null) {
      try {
        await firestore
            .collection('marketplace_listings')
            .doc(marketplaceListingId)
            .delete();
      } catch (e) {
        debugPrint('Advertencia: no se pudo eliminar la publicación del Marketplace: $e');
      }
    }

    final userDoc = await firestore.collection('users').doc(userId).get();
    final String? currentRanchId = userDoc.data()?['currentRanchId'];

    if (currentRanchId != null) {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('ranches')
          .doc(currentRanchId)
          .collection('animals')
          .doc(animal.id)
          .delete();
    }

    if (!context.mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Animal eliminado y su publicación de Marketplace (si existía) también.')),
    );
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al eliminar: ${e.toString()}')),
    );
    return false;
  }
}
