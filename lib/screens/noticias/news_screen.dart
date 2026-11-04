// lib/screens/noticias/news_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<Map<String, dynamic>> _newsList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // No usamos orderBy('date') en la consulta: si una noticia no tiene el
      // campo 'date' (o no es timestamp), Firestore la EXCLUIRÍA. Mejor traemos
      // todas y ordenamos aquí, así SIEMPRE se muestran.
      final snapshot = await FirebaseFirestore.instance
          .collection('global_news')
          .limit(30)
          .get();

      final list = snapshot.docs.map((doc) => doc.data()).toList();

      // Ordena por fecha descendente; las que no tengan fecha van al final.
      list.sort((a, b) {
        final da = a['date'] is Timestamp
            ? (a['date'] as Timestamp).toDate()
            : DateTime(1970);
        final db = b['date'] is Timestamp
            ? (b['date'] as Timestamp).toDate()
            : DateTime(1970);
        return db.compareTo(da);
      });

      if (mounted) {
        setState(() {
          _newsList = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar las noticias: $e';
          _isLoading = false;
        });
      }
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
          onPressed: () => Navigator.of(context).pop(),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF5e3a1c)),
            onPressed: _loadNews,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFc99450)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 16),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5e3a1c)),
                          onPressed: _loadNews,
                          child: const Text('Reintentar',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : _newsList.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay noticias publicadas por el momento.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNews,
                      color: const Color(0xFFc99450),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _newsList.length,
                        itemBuilder: (context, index) {
                          final data = _newsList[index];
                          final String title = data['title'] ?? 'Sin título';
                          final String content = data['content'] ?? '';
                          final String? imageUrl = data['imageUrl'];

                          DateTime date = DateTime.now();
                          if (data['date'] != null) {
                            date = (data['date'] as Timestamp).toDate();
                          }
                          final String formattedDate = DateFormat(
                                  'dd \'de\' MMMM, yyyy', 'es_MX')
                              .format(date);

                          return _buildNewsCard(
                            title: title,
                            date: formattedDate,
                            content: content,
                            imageUrl: imageUrl,
                          );
                        },
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
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 180,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 80, color: Colors.grey),
              ),
            )
          else
            Container(
              height: 100,
              width: double.infinity,
              color: const Color(0xFFc99450).withValues(alpha: 0.2),
              child:
                  const Icon(Icons.newspaper, size: 50, color: Color(0xFF5e3a1c)),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5e3a1c))),
                const SizedBox(height: 5),
                Text(date,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic)),
                const SizedBox(height: 12),
                Text(content,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black87, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
