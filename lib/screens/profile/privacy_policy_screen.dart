// lib/screens/profile/privacy_policy_screen.dart
//
// ⚠️  IMPORTANTE PARA PLAY STORE:
// Google exige que la Política de Privacidad sea una URL pública accesible.
// Opciones gratuitas para hospedarla:
//   1. Google Sites  → sites.google.com  (más fácil)
//   2. GitHub Pages  → pages.github.com
//   3. Notion pública
//
// Una vez que tengas la URL, agrégala en Play Console:
//   Configuración del app → Política de privacidad → [TU URL]
//
// Esta pantalla muestra el contenido dentro de la app como respaldo.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // agrega url_launcher en pubspec.yaml

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  // ⬇ Cambia esto por tu URL real una vez que la hospedesón
  static const String _policyUrl =
      'https://sites.google.com/tu-sitio/privacidad';

  static const Color _brown = Color(0xFF5e3a1c);
  static const Color _gold = Color(0xFFc99450);
  static const Color _cream = Color(0xFFfbf6ec);

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
        title: const Text('Política de Privacidad',
            style: TextStyle(color: _brown, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser, color: _gold),
            tooltip: 'Abrir en navegador',
            onPressed: () async {
              final uri = Uri.parse(_policyUrl);
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
          ),
        ],
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Política de Privacidad',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: _brown)),
          SizedBox(height: 4),
          Text('Última actualización: enero 2025',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          SizedBox(height: 20),
          _Section(
              title: '1. Información que recopilamos',
              content:
                  'Recopilamos la información que tú nos proporcionas directamente:\n\n'
                  '• Nombre, correo electrónico y contraseña para crear tu cuenta.\n'
                  '• Datos de tu rancho: nombre, ubicación, tamaño en hectáreas.\n'
                  '• Datos de tus animales: nombre, arete, raza, peso, vacunas, estado reproductivo.\n'
                  '• Registros de inventario, transacciones económicas y eventos del calendario.\n'
                  '• Imágenes que subas de tus animales.\n'
                  '• Datos de uso de la función de Inteligencia Artificial (consultas realizadas).'),
          _Section(
              title: '2. Cómo usamos tu información',
              content: 'Usamos tu información para:\n\n'
                  '• Proporcionarte el servicio de gestión ganadera.\n'
                  '• Personalizar las respuestas de la IA con el contexto de tu rancho.\n'
                  '• Enviarte notificaciones sobre eventos y recordatorios que tú configures.\n'
                  '• Mejorar la experiencia de la aplicación.\n\n'
                  'No vendemos ni compartimos tu información personal con terceros '
                  'con fines comerciales.'),
          _Section(
              title: '3. Almacenamiento y seguridad',
              content: 'Tu información se almacena de forma segura en Firebase '
                  '(Google Cloud), bajo los estándares de seguridad de Google. '
                  'Usamos Firebase Authentication para proteger el acceso a tu cuenta. '
                  'Las imágenes se almacenan en Firebase Storage con acceso restringido.'),
          _Section(
              title: '4. Servicios de terceros',
              content:
                  'La aplicación utiliza los siguientes servicios de terceros:\n\n'
                  '• Firebase (Google): almacenamiento de datos y autenticación.\n'
                  '• Google Gemini API: procesamiento de consultas de IA.\n'
                  '• Google Sign-In: inicio de sesión opcional con cuenta Google.\n\n'
                  'Cada servicio tiene su propia política de privacidad.'),
          _Section(
              title: '5. Tus derechos',
              content: 'Tienes derecho a:\n\n'
                  '• Acceder a todos los datos que hemos almacenado sobre ti.\n'
                  '• Corregir información incorrecta desde la pantalla de perfil.\n'
                  '• Eliminar tu cuenta y todos tus datos desde Perfil → Eliminar mi cuenta.\n'
                  '• Exportar tus datos (próximamente).'),
          _Section(
              title: '6. Datos de menores',
              content: 'Esta aplicación no está dirigida a menores de 13 años. '
                  'No recopilamos intencionalmente datos de menores. Si eres padre o '
                  'tutor y crees que un menor nos proporcionó datos, contáctanos para '
                  'eliminarlos.'),
          _Section(
              title: '7. Cambios a esta política',
              content: 'Podemos actualizar esta política ocasionalmente. '
                  'Te notificaremos dentro de la app cuando haya cambios importantes. '
                  'El uso continuo de la app después de los cambios implica tu aceptación.'),
          _Section(
              title: '8. Contacto',
              content:
                  'Si tienes preguntas sobre esta política, contáctanos en:\n'
                  'soporte@manualganadera.com'),
          SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String content;
  const _Section({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5e3a1c))),
        const SizedBox(height: 8),
        Text(content,
            style: const TextStyle(
                fontSize: 14, color: Colors.black87, height: 1.6)),
        const SizedBox(height: 8),
        const Divider(color: Colors.black12),
      ]),
    );
  }
}
