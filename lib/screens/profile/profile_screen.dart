// lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:manual_ganadero_flutter/screens/profile/personal_info_screen.dart';
import 'package:manual_ganadero_flutter/screens/profile/notification_settings_screen.dart';
import 'package:manual_ganadero_flutter/screens/profile/privacy_policy_screen.dart';
import 'package:manual_ganadero_flutter/screens/profile/terms_screen.dart';
import 'package:manual_ganadero_flutter/screens/profile/help_center_screen.dart';
import 'package:manual_ganadero_flutter/screens/profile/donations_screen.dart';
import 'package:manual_ganadero_flutter/screens/profile/delete_account_screen.dart';
import 'package:manual_ganadero_flutter/screens/profile/notification_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _brown = Color(0xFF5e3a1c);
  static const Color _gold = Color(0xFFc99450);
  static const Color _cream = Color(0xFFfbf6ec);

  User? _user;
  String _username = 'Cargando...';
  String _userEmail = 'Cargando...';
  String? _ranchName;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _user = FirebaseAuth.instance.currentUser;
      if (_user != null) {
        _userEmail = _user!.email ?? 'Email no disponible';
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          _username = data['name'] ?? _user!.displayName ?? 'Usuario';
          final ranchId = data['currentRanchId'] as String?;
          if (ranchId != null) {
            final ranchDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(_user!.uid)
                .collection('ranches')
                .doc(ranchId)
                .get();
            _ranchName = ranchDoc.data()?['name'] as String?;
          }
        } else {
          _username = _user!.displayName ?? 'Usuario';
        }
      } else {
        _errorMessage = 'No hay usuario autenticado.';
      }
    } catch (e) {
      _errorMessage = 'Error al cargar el perfil: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    if (_userEmail == 'Cargando...' || _userEmail == 'Email no disponible')
      return;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const Center(child: CircularProgressIndicator(color: _gold)));
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _userEmail);
      if (mounted) Navigator.pop(context);
      if (mounted) {
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                  backgroundColor: _cream,
                  title: const Text('Correo Enviado',
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold)),
                  content: Text(
                      'Enviamos un enlace a $_userEmail para cambiar tu contraseña.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Entendido',
                            style: TextStyle(color: _gold)))
                  ],
                ));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cream,
        title: const Text('Cerrar sesión', style: TextStyle(color: _brown)),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cerrar sesión',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al cerrar sesión: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: _cream,
          body: Center(child: CircularProgressIndicator(color: _gold)));
    }
    if (_errorMessage != null) {
      return Scaffold(
          backgroundColor: _cream,
          appBar: AppBar(
              backgroundColor: _cream,
              elevation: 0,
              title: const Text('Perfil', style: TextStyle(color: _brown))),
          body: Center(
              child: Text(_errorMessage!,
                  style: const TextStyle(color: Colors.red))));
    }

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: _brown),
            onPressed: () => Navigator.of(context).pop()),
        title: const Text('Perfil',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: _brown)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // ── Avatar + info ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(children: [
              Stack(alignment: Alignment.bottomRight, children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: _gold.withOpacity(0.2),
                  backgroundImage: _user?.photoURL != null
                      ? NetworkImage(_user!.photoURL!)
                      : null,
                  child: _user?.photoURL == null
                      ? Icon(Icons.person,
                          size: 56, color: _brown.withOpacity(0.7))
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration:
                      const BoxDecoration(color: _gold, shape: BoxShape.circle),
                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              ]),
              const SizedBox(height: 12),
              Text(_username,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _brown)),
              const SizedBox(height: 4),
              Text(_userEmail,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              if (_ranchName != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                      color: _gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('🏠 $_ranchName',
                      style: const TextStyle(
                          fontSize: 12,
                          color: _brown,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 24),

          // ── MI CUENTA ────────────────────────────────────────────────────
          _sectionLabel('Mi Cuenta'),
          _buildCard([
            _option(
                icon: Icons.account_circle,
                label: 'Información Personal',
                onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PersonalInfoScreen()))
                    .then((_) => _loadUserProfile())),
            _divider(),
            _option(
                icon: Icons.notifications,
                label: 'Notificaciones',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen()))),
            _divider(),
            _option(
                icon: Icons.lock_reset,
                label: 'Cambiar Contraseña',
                subtitle: 'Se enviará un enlace a tu correo',
                onTap: _sendPasswordResetEmail),
          ]),

          const SizedBox(height: 16),

          // ── APOYA EL PROYECTO ─────────────────────────────────────────────
          _sectionLabel('Apoya el Proyecto'),
          _buildCard([
            _option(
              icon: Icons.favorite,
              label: 'Donar / Tokens de IA',
              subtitle: 'Ayuda a mantener la IA activa',
              iconColor: Colors.pink,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DonationsScreen())),
            ),
          ]),

          const SizedBox(height: 16),

          // ── LEGAL Y PRIVACIDAD ────────────────────────────────────────────
          _sectionLabel('Legal y Privacidad'),
          _buildCard([
            _option(
                icon: Icons.privacy_tip,
                label: 'Política de Privacidad',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen()))),
            _divider(),
            _option(
                icon: Icons.description,
                label: 'Términos y Condiciones',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TermsScreen()))),
            _divider(),
            _option(
                icon: Icons.delete_forever,
                label: 'Eliminar mi cuenta',
                subtitle: 'Borra todos tus datos permanentemente',
                iconColor: Colors.red.shade400,
                labelColor: Colors.red.shade700,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DeleteAccountScreen()))),
          ]),

          const SizedBox(height: 16),

          // ── SOPORTE ───────────────────────────────────────────────────────
          _sectionLabel('Soporte'),
          _buildCard([
            _option(
                icon: Icons.help_outline,
                label: 'Centro de Ayuda',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HelpCenterScreen()))),
            _divider(),
            _option(
                icon: Icons.star_outline,
                label: 'Calificar la app',
                subtitle: 'Tu opinión nos ayuda mucho',
                onTap: () {
                  // TODO: url_launcher → Play Store link
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Próximamente disponible en Play Store')));
                }),
            _divider(),
            _option(
                icon: Icons.info_outline,
                label: 'Versión de la app',
                subtitle: '1.0.0',
                showArrow: false,
                onTap: () {}),
          ]),

          const SizedBox(height: 20),

          // ── CERRAR SESIÓN ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar Sesión',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              onPressed: _signOut,
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Align(
            alignment: Alignment.centerLeft,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey))),
      );

  Widget _buildCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ]),
        child: Column(children: children),
      );

  Widget _option({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? subtitle,
    Color iconColor = const Color(0xFF5e3a1c),
    Color? labelColor,
    bool showArrow = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: labelColor ?? const Color(0xFF5e3a1c))),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ])),
          if (showArrow)
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 56, color: Colors.black12);
}
