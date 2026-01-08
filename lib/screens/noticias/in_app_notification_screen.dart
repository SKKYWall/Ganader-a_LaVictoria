// lib/screens/principal/in_app_notification_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Modelo para una notificación in-app
class InAppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  bool read; // Campo mutable

  InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
  });

  factory InAppNotification.fromFirestore(
      Map<String, dynamic> data, String id) {
    return InAppNotification(
      id: id,
      title: data['title'] as String? ?? 'Sin título',
      body: data['body'] as String? ?? 'Sin contenido',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      read: data['read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'timestamp': Timestamp.fromDate(timestamp),
      'read': read,
    };
  }
}

class InAppNotificationScreen extends StatefulWidget {
  const InAppNotificationScreen({super.key});

  @override
  State<InAppNotificationScreen> createState() =>
      _InAppNotificationScreenState();
}

class _InAppNotificationScreenState extends State<InAppNotificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    if (_currentUser == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('inAppNotifications')
          .doc(notificationId)
          .update({'read': true});
      print('Notificación $notificationId marcada como leída.');
    } catch (e) {
      print('Error al marcar notificación como leída: $e');
    }
  }

  Future<void> _deleteAllReadNotifications() async {
    if (_currentUser == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Notificaciones Leídas',
              style: TextStyle(color: Color(0xFF5e3a1c))),
          content: const Text(
              '¿Estás seguro de que quieres eliminar todas las notificaciones leídas?'),
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

    if (confirm == true) {
      try {
        final QuerySnapshot readNotifications = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('inAppNotifications')
            .where('read', isEqualTo: true)
            .get();

        for (DocumentSnapshot doc in readNotifications.docs) {
          await doc.reference.delete();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificaciones leídas eliminadas.')),
        );
      } catch (e) {
        print('Error al eliminar notificaciones leídas: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar notificaciones: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFfbf6ec),
        appBar: AppBar(
          title: const Text('Notificaciones',
              style: TextStyle(color: Color(0xFF5e3a1c))),
          backgroundColor: const Color(0xFFfbf6ec),
        ),
        body: const Center(
          child: Text('Necesitas iniciar sesión para ver tus notificaciones.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF5e3a1c))),
        ),
      );
    }

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
          'Tus Notificaciones',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5e3a1c),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Color(0xFF5e3a1c)),
            onPressed: _deleteAllReadNotifications,
            tooltip: 'Eliminar todas las notificaciones leídas',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('inAppNotifications')
            .orderBy('timestamp',
                descending: true) // Ordenar por las más recientes primero
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6b4226))),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar notificaciones: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No tienes notificaciones por ahora.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF5e3a1c)),
              ),
            );
          }

          final notifications = snapshot.data!.docs
              .map((doc) => InAppNotification.fromFirestore(
                  doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              bool isSelected =
                  false; // Este isSelected se usaba para la comparación en IA, aquí no aplica
              // Se mantiene para evitar errores si la lógica de onTap es compleja
              return Card(
                margin: const EdgeInsets.only(bottom: 10.0),
                elevation:
                    notification.read ? 1 : 4, // Más elevación si no está leída
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                  side: notification.read
                      ? BorderSide.none
                      : const BorderSide(
                          color: Color(0xFFc99450),
                          width: 1.5), // Borde si no está leída
                ),
                color: notification.read
                    ? Colors.white70
                    : Colors
                        .white, // Ligeramente más transparente si está leída
                child: InkWell(
                  onTap: () {
                    _markNotificationAsRead(notification.id);
                    // Aquí podrías añadir lógica para mostrar un diálogo con el detalle completo o navegar a otra pantalla
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(notification.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5e3a1c))),
                        content: Text(notification.body,
                            style: const TextStyle(color: Colors.black87)),
                        backgroundColor: const Color(0xFFfbf6ec),
                        surfaceTintColor: const Color(0xFFfbf6ec),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cerrar',
                                style: TextStyle(color: Color(0xFF6b4226))),
                          ),
                        ],
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(15.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: notification.read
                                ? Colors.grey[700]
                                : const Color(0xFF5e3a1c),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          notification.body,
                          maxLines:
                              2, // Mostrar solo 2 líneas en la vista previa
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: notification.read
                                ? Colors.grey[500]
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            DateFormat('dd/MM/yyyy HH:mm')
                                .format(notification.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: notification.read
                                  ? Colors.grey[400]
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
