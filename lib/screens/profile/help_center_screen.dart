// lib/screens/profile/help_center_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const Color _brown = Color(0xFF5e3a1c);
  static const Color _gold = Color(0xFFc99450);
  static const Color _cream = Color(0xFFfbf6ec);

  static const String _supportEmail = 'soporte@manualganadera.com';
  static const String _whatsappUrl =
      'https://wa.me/521XXXXXXXXXX?text=Hola, necesito ayuda con Manual Ganadero Pro';

  static const List<Map<String, String>> _faqs = [
    {
      'q': '¿Cómo registro un nuevo animal?',
      'a': 'Ve a la sección "Bovinos" y toca el botón "+" en la esquina inferior derecha. '
          'También puedes usar el asistente de voz diciendo "Oye Rancho, registra un animal nuevo".',
    },
    {
      'q': '¿Cómo funciona la IA Ganadera?',
      'a': 'La IA usa los datos de tu rancho para darte respuestas personalizadas. '
          'Si quieres una consulta general (sin usar tus datos), pregunta sin mencionar '
          '"mis animales" o "mi hato". Para preguntas específicas, selecciona el animal '
          'usando el ícono de vaca en el chat.',
    },
    {
      'q': '¿Cómo funciona el registro por voz?',
      'a':
          'Di "Oye Rancho" para activar el asistente. Espera a que diga "Te escucho" '
              'y luego describe la acción que quieres realizar. Por ejemplo: '
              '"Registra un peso de 450 kilos a la vaca número 285". '
              'El sistema te pedirá confirmar antes de guardar.',
    },
    {
      'q': '¿Puedo tener varios ranchos?',
      'a':
          'Sí. Ve a Perfil → Información Personal y toca "Nuevo" en la sección '
              '"Mis Ranchos". Puedes cambiar el rancho activo desde ahí.',
    },
    {
      'q': '¿Mis datos están seguros?',
      'a': 'Sí. Tus datos se almacenan en Firebase (Google Cloud) con encriptación. '
          'Solo tú tienes acceso a tu información. Lee nuestra Política de Privacidad '
          'para más detalles.',
    },
    {
      'q': '¿Cómo elimino mi cuenta?',
      'a':
          'Ve a Perfil → Eliminar mi cuenta. Esta acción borra permanentemente '
              'todos tus datos. No se puede deshacer.',
    },
    {
      'q': '¿Cómo funciona el marketplace?',
      'a': 'En la sección Marketplace puedes publicar animales para venta. '
          'Otros usuarios pueden ver tu publicación y contactarte. '
          'La transacción se realiza directamente entre comprador y vendedor.',
    },
    {
      'q': '¿Qué pasa si pierdo mi contraseña?',
      'a': 'Ve a Perfil → Cambiar Contraseña. Te enviaremos un enlace a tu correo '
          'para restablecerla. También puedes hacerlo desde la pantalla de inicio de sesión.',
    },
  ];

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
        title: const Text('Centro de Ayuda',
            style: TextStyle(color: _brown, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Contacto directo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: _brown, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              const Icon(Icons.support_agent, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              const Text('¿Necesitas ayuda directa?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Estamos aquí para ayudarte',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: _contactBtn(
                        label: 'WhatsApp',
                        icon: Icons.chat,
                        color: Colors.green,
                        onTap: () async {
                          final uri = Uri.parse(_whatsappUrl);
                          if (await canLaunchUrl(uri))
                            launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                        })),
                const SizedBox(width: 10),
                Expanded(
                    child: _contactBtn(
                        label: 'Email',
                        icon: Icons.email,
                        color: Colors.blue,
                        onTap: () async {
                          final uri = Uri.parse(
                              'mailto:$_supportEmail?subject=Ayuda Manual Ganadero Pro');
                          if (await canLaunchUrl(uri)) launchUrl(uri);
                        })),
              ]),
            ]),
          ),

          const SizedBox(height: 24),

          // FAQs
          const Text('Preguntas frecuentes',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: _brown)),
          const SizedBox(height: 12),

          ..._faqs
              .map((faq) => _FaqTile(question: faq['q']!, answer: faq['a']!))
              .toList(),

          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _contactBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ]),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(question,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5e3a1c))),
        iconColor: const Color(0xFFc99450),
        collapsedIconColor: Colors.grey,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer,
                style: const TextStyle(
                    fontSize: 13, color: Colors.black87, height: 1.6)),
          ),
        ],
      ),
    );
  }
}
