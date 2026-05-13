// lib/screens/profile/terms_acceptance_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:manual_ganadero_flutter/screens/profile/privacy_policy_screen.dart';
import 'package:manual_ganadero_flutter/screens/profile/terms_screen.dart';

class TermsAcceptanceScreen extends StatefulWidget {
  final VoidCallback onAccepted;
  const TermsAcceptanceScreen({super.key, required this.onAccepted});

  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen> {
  static const Color _brown = Color(0xFF5e3a1c);
  static const Color _gold = Color(0xFFc99450);
  static const Color _cream = Color(0xFFfbf6ec);

  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _isSaving = false;

  Future<void> _accept() async {
    if (!_acceptedTerms || !_acceptedPrivacy) return;
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'termsAccepted': true,
          'termsAcceptedAt': FieldValue.serverTimestamp(),
          'termsVersion': '1.0',
        }, SetOptions(merge: true));
      }
      widget.onAccepted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            const Icon(Icons.gavel, color: _gold, size: 60),
            const SizedBox(height: 20),
            const Text('Antes de continuar',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: _brown)),
            const SizedBox(height: 12),
            const Text(
                'Para usar Manual Ganadero Pro necesitas aceptar nuestros '
                'términos y política de privacidad.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 14, color: Colors.grey, height: 1.5)),
            const Spacer(),
            _checkRow(
              label: 'Acepto los ',
              linkLabel: 'Términos y Condiciones',
              value: _acceptedTerms,
              onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
              onLinkTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TermsScreen())),
            ),
            const SizedBox(height: 12),
            _checkRow(
              label: 'Acepto la ',
              linkLabel: 'Política de Privacidad',
              value: _acceptedPrivacy,
              onChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
              onLinkTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen())),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_acceptedTerms && _acceptedPrivacy)
                      ? _brown
                      : Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (_acceptedTerms && _acceptedPrivacy && !_isSaving)
                    ? _accept
                    : null,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Continuar',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _checkRow({
    required String label,
    required String linkLabel,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onLinkTap,
  }) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Checkbox(value: value, onChanged: onChanged, activeColor: _gold),
      Expanded(
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: label,
                    style:
                        const TextStyle(color: Colors.black87, fontSize: 14)),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: onLinkTap,
                    child: Text(linkLabel,
                        style: const TextStyle(
                            color: _gold,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}
