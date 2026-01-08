// lib/screens/principal/news_screen.dart

import 'package:flutter/material.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

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
          'Noticias y Novedades',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5e3a1c),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNewsCard(
              title:
                  'Nueva Actualización de la App: ¡Gestión de Notificaciones!',
              date: '20 de Junio, 2025',
              content:
                  'Hemos lanzado una nueva función que te permite gestionar tus preferencias de notificación directamente desde la sección de perfil. ¡Mantente al día con las últimas novedades de tu ganado!',
              imageUrl:
                  'https://placehold.co/600x300/c99450/FFFFFF?text=Noticias+App',
            ),
            _buildNewsCard(
              title: 'Consejos para la Salud del Ganado en Verano',
              date: '15 de Junio, 2025',
              content:
                  'Con la llegada del verano, es crucial proteger a tu ganado del calor. Asegura suficiente agua fresca, sombra y considera ajustes en la alimentación para prevenir el estrés por calor.',
              imageUrl:
                  'https://placehold.co/600x300/6b4226/FFFFFF?text=Salud+Ganado',
            ),
            _buildNewsCard(
              title: 'Tendencias del Mercado Ganadero en Latinoamérica',
              date: '10 de Junio, 2025',
              content:
                  'Un análisis reciente muestra un crecimiento constante en el mercado de la carne de res en la región, impulsado por la demanda interna y las exportaciones. Conoce las últimas cifras y predicciones.',
              imageUrl:
                  'https://placehold.co/600x300/5e3a1c/FFFFFF?text=Mercado+Ganadero',
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Mantente atento a más noticias y actualizaciones.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard({
    required String title,
    required String date,
    required String content,
    String? imageUrl,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15.0)),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported,
                      size: 80, color: Colors.grey),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5e3a1c),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
