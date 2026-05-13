// lib/screens/profile/delete_account_screen.dart
//
// ⚠️  OBLIGATORIO PARA PLAY STORE desde agosto 2023:
// Google exige que apps con cuentas de usuario ofrezcan la opción de
// ELIMINAR CUENTA y DATOS dentro de la propia app.
// Ref: https://support.google.com/googleplay/android-developer/answer/13327111

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const Color _brown = Color(0xFF5e3a1c);
  static const Color _cream = Color(0xFFfbf6ec);

  final _confirmController = TextEditingController();
  bool _isDeleting = false;
  bool _understood = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_confirmController.text.trim().toLowerCase() != 'eliminar') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Escribe "eliminar" para confirmar'),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isDeleting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;
      final firestore = FirebaseFirestore.instance;

      // 1. Obtener todos los ranchos del usuario
      final ranchesSnap = await firestore
          .collection('users')
          .doc(uid)
          .collection('ranches')
          .get();

      // 2. Eliminar subcolecciones de cada rancho
      for (final ranch in ranchesSnap.docs) {
        final ranchRef = ranch.reference;
        final colecciones = [
          'animals',
          'products',
          'transactions',
          'calendarEvents'
        ];
        for (final col in colecciones) {
          final snap = await ranchRef.collection(col).get();
          for (final doc in snap.docs) {
            await doc.reference.delete();
          }
        }
        await ranchRef.delete();
      }

      // 3. Eliminar otras subcolecciones del usuario
      final otrasColecciones = [
        'ai_usage',
        'analysis_records',
        'inAppNotifications'
      ];
      for (final col in otrasColecciones) {
        final snap =
            await firestore.collection('users').doc(uid).collection(col).get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      }

      // 4. Eliminar documento del usuario
      await firestore.collection('users').doc(uid).delete();

      // 5. Eliminar archivos de Storage (imágenes)
      try {
        final storageRef = FirebaseStorage.instance.ref().child('users/$uid');
        final listResult = await storageRef.listAll();
        for (final item in listResult.items) {
          await item.delete();
        }
      } catch (_) {
        // Storage puede estar vacío, no es error crítico
      }

      // 6. Eliminar cuenta de Firebase Auth
      // Nota: si el usuario lleva mucho tiempo sin iniciar sesión, Firebase
      // puede requerir re-autenticación. En ese caso mostramos el error.
      await user.delete();

      // 7. Cerrar sesión de Google
      await GoogleSignIn().signOut();

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cuenta eliminada exitosamente'),
          backgroundColor: Colors.green));
    } on FirebaseAuthException catch (e) {
      setState(() => _isDeleting = false);
      String msg = 'Error al eliminar la cuenta.';
      if (e.code == 'requires-recent-login') {
        msg =
            'Por seguridad, cierra sesión y vuelve a iniciar antes de eliminar tu cuenta.';
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: _brown),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Eliminar Cuenta',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Advertencia
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200)),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.warning_amber, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Acción irreversible',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 16)),
                  ]),
                  SizedBox(height: 10),
                  Text('Al eliminar tu cuenta se borrarán permanentemente:',
                      style: TextStyle(color: Colors.red, fontSize: 13)),
                ]),
          ),
          const SizedBox(height: 12),

          _bulletItem('Todos tus animales y su historial'),
          _bulletItem('Registros de vacunas, pesos y eventos'),
          _bulletItem('Tu inventario de productos'),
          _bulletItem('Tus transacciones financieras'),
          _bulletItem('Imágenes y fotografías subidas'),
          _bulletItem('Tu cuenta y datos de acceso'),
          _bulletItem('Publicaciones en el marketplace'),

          const SizedBox(height: 24),

          // Checkbox de confirmación
          CheckboxListTile(
            value: _understood,
            onChanged: (v) => setState(() => _understood = v ?? false),
            activeColor: Colors.red,
            title: const Text(
                'Entiendo que esta acción es permanente y no se puede deshacer.',
                style: TextStyle(fontSize: 13)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 16),

          // Campo de confirmación
          const Text('Escribe "eliminar" para confirmar:',
              style: TextStyle(fontWeight: FontWeight.w600, color: _brown)),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            decoration: InputDecoration(
              hintText: 'eliminar',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),

          const SizedBox(height: 24),

          // Botón eliminar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (_understood && !_isDeleting) ? _deleteAccount : null,
              child: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Eliminar mi cuenta permanentemente',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
            ),
          ),

          const SizedBox(height: 12),

          Center(
              child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar, mantener mi cuenta',
                style: TextStyle(color: _brown)),
          )),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _bulletItem(String text) => Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ',
              style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13, color: Colors.black87))),
        ]),
      );
}
