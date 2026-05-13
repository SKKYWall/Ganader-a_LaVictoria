// lib/screens/profile/terms_screen.dart

import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const Color _brown = Color(0xFF5e3a1c);
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
        title: const Text('Términos y Condiciones',
            style: TextStyle(color: _brown, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Términos y Condiciones de Uso',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: _brown)),
          SizedBox(height: 4),
          Text('Vigentes desde enero 2025',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          SizedBox(height: 20),
          _Section(
              title: '1. Aceptación de términos',
              content:
                  'Al descargar, instalar o usar Manual Ganadero Pro ("la App"), '
                  'aceptas estos términos. Si no estás de acuerdo, no uses la App.'),
          _Section(
              title: '2. Descripción del servicio',
              content:
                  'Manual Ganadero Pro es una herramienta de gestión ganadera que '
                  'permite registrar animales, controlar inventario, gestionar finanzas '
                  'y acceder a consultas de inteligencia artificial sobre ganadería.'),
          _Section(
              title: '3. Cuenta de usuario',
              content:
                  'Eres responsable de mantener la confidencialidad de tu cuenta '
                  'y contraseña. Notifícanos inmediatamente si sospechas acceso no '
                  'autorizado. No compartas tu cuenta con terceros.'),
          _Section(
              title: '4. Uso aceptable',
              content: 'Puedes usar la App para:\n'
                  '• Gestionar información de tu rancho y animales.\n'
                  '• Consultar a la IA sobre temas ganaderos.\n'
                  '• Publicar animales en el marketplace.\n\n'
                  'No puedes:\n'
                  '• Usar la App para actividades ilegales.\n'
                  '• Publicar información falsa en el marketplace.\n'
                  '• Intentar acceder a datos de otros usuarios.'),
          _Section(
              title: '5. Inteligencia Artificial',
              content:
                  'Las respuestas de la IA son orientativas y no sustituyen '
                  'el criterio de un médico veterinario certificado, nutricionista '
                  'o genetista profesional. Siempre consulta a un profesional '
                  'para decisiones críticas sobre la salud de tus animales.'),
          _Section(
              title: '6. Marketplace',
              content:
                  'El marketplace es una plataforma de conexión entre vendedores '
                  'y compradores. No somos parte de las transacciones comerciales entre '
                  'usuarios. El comprador y vendedor son responsables de verificar '
                  'la información y acordar los términos de compraventa.'),
          _Section(
              title: '7. Pagos y donaciones',
              content: 'Los pagos realizados por tokens de IA o donaciones son '
                  'voluntarios y no reembolsables. Los tokens adquiridos tienen '
                  'vigencia de 12 meses desde la fecha de compra.'),
          _Section(
              title: '8. Limitación de responsabilidad',
              content: 'La App se proporciona "tal como está". No garantizamos '
                  'disponibilidad continua ni ausencia de errores. No somos '
                  'responsables por pérdidas económicas derivadas del uso de la App.'),
          _Section(
              title: '9. Propiedad intelectual',
              content:
                  'Todo el contenido de la App (código, diseño, textos, íconos) '
                  'es propiedad de Manual Ganadero Pro. Los datos de tu rancho '
                  'son de tu propiedad y puedes solicitarlos en cualquier momento.'),
          _Section(
              title: '10. Modificaciones',
              content: 'Nos reservamos el derecho de modificar estos términos. '
                  'Te notificaremos con al menos 30 días de anticipación ante '
                  'cambios significativos.'),
          _Section(
              title: '11. Ley aplicable',
              content:
                  'Estos términos se rigen por las leyes de los Estados Unidos '
                  'Mexicanos. Cualquier disputa se resolverá en los tribunales '
                  'competentes de México.'),
          _Section(
              title: '12. Contacto',
              content:
                  'Para dudas sobre estos términos:\nsoporte@manualganadera.com'),
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
                fontSize: 15,
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
