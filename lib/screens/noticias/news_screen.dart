// lib/screens/principal/news_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5e3a1c),
          ),
        ),
        centerTitle: true,
      ),
      // Escuchamos a Firebase en tiempo real
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('global_news')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // --- ESTO TE AVISARÁ SI TE FALTAN REGLAS EN FIREBASE ---
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Error de Firebase:\n${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFc99450)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No hay noticias publicadas por el momento.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // Construir la lista de noticias desde la base de datos
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;

              // Extraer datos de forma segura
              String title = data['title'] ?? 'Sin título';
              String content = data['content'] ?? '';
              String? imageUrl = data['imageUrl'];

              // Formatear la fecha
              DateTime date = DateTime.now();
              if (data['date'] != null) {
                date = (data['date'] as Timestamp).toDate();
              }
              String formattedDate =
                  DateFormat('dd \'de\' MMMM, yyyy', 'es_MX').format(date);

              return _buildNewsCard(
                title: title,
                date: formattedDate,
                content: content,
                imageUrl: imageUrl,
              );
            },
          );
        },
      ),
    );
  }

  // Tarjeta de diseño mejorada
  Widget _buildNewsCard({
    required String title,
    required String date,
    required String content,
    String? imageUrl,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Si subiste una imagen, se muestra. Si no, muestra un banner genérico elegante.
          if (imageUrl != null && imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 180,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image,
                    size: 80, color: Colors.grey),
              ),
            )
          else
            Container(
              height: 100,
              width: double.infinity,
              color: const Color(0xFFc99450).withOpacity(0.2),
              child: const Icon(Icons.newspaper,
                  size: 50, color: Color(0xFF5e3a1c)),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
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
                const SizedBox(height: 12),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.4,
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
