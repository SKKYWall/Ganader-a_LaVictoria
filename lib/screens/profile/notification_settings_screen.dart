// lib/screens/principal/notification_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  bool _notificationsEnabled = true; // Valor predeterminado
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      _errorMessage = 'Usuario no autenticado.';
      _isLoading = false;
    } else {
      _loadNotificationSetting();
    }
  }

  Future<void> _loadNotificationSetting() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_currentUser == null) return;

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_currentUser!.uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        // Si el campo 'notificationsEnabled' existe, úsalo; de lo contrario, por defecto es true.
        _notificationsEnabled = userData['notificationsEnabled'] ?? true;
      } else {
        // Si el documento del usuario no existe, asumimos que las notificaciones están habilitadas por defecto.
        _notificationsEnabled = true;
      }
    } catch (e) {
      print('Error al cargar la configuración de notificaciones: $e');
      if (!mounted) return;
      _errorMessage = 'Error al cargar la configuración: ${e.toString()}';
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateNotificationSetting(bool value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_currentUser == null) return;

      // Actualizar el campo 'notificationsEnabled' en el documento del usuario
      await _firestore.collection('users').doc(_currentUser!.uid).set(
        {'notificationsEnabled': value},
        SetOptions(
            merge:
                true), // 'merge: true' fusiona los datos sin sobrescribir todo el documento
      );

      if (!mounted) return;
      setState(() {
        _notificationsEnabled = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Notificaciones ${value ? 'activadas' : 'desactivadas'} exitosamente.')),
      );
    } catch (e) {
      print('Error al actualizar la configuración de notificaciones: $e');
      if (!mounted) return;
      _errorMessage = 'Error al guardar la configuración: ${e.toString()}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Error al guardar la configuración: ${e.toString()}')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Configuración de Notificaciones',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5e3a1c),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6b4226)),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 16.0),
                          child: SwitchListTile(
                            title: const Text(
                              'Habilitar Notificaciones',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5e3a1c),
                              ),
                            ),
                            value: _notificationsEnabled,
                            onChanged: _updateNotificationSetting,
                            activeColor: const Color(
                                0xFF6b4226), // Color cuando está activo
                            inactiveTrackColor: Colors.grey[
                                300], // Color de la pista cuando está inactivo
                            inactiveThumbColor: Colors.grey[
                                500], // Color del pulgar cuando está inactivo
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          _notificationsEnabled
                              ? 'Recibirás alertas sobre eventos importantes, como vacunaciones, partos y recordatorios.'
                              : 'No recibirás alertas ni recordatorios. Puedes activar las notificaciones en cualquier momento.',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[700]),
                          textAlign: TextAlign.justify,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
