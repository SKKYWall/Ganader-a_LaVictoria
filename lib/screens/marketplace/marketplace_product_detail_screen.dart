// lib/screens/marketplace/marketplace_product_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class MarketplaceProductDetailScreen extends StatefulWidget {
  final String listingId;

  const MarketplaceProductDetailScreen({super.key, required this.listingId});

  @override
  State<MarketplaceProductDetailScreen> createState() =>
      _MarketplaceProductDetailScreenState();
}

class _MarketplaceProductDetailScreenState
    extends State<MarketplaceProductDetailScreen> {
  Map<String, dynamic>? _listing;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProductDetail();
  }

  Future<void> _loadProductDetail() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('marketplace_listings')
          .doc(widget.listingId)
          .get();
      if (doc.exists) {
        setState(() {
          _listing = doc.data();
          _isLoading = false;
        });
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      Navigator.pop(context);
    }
  }

  Future<void> _contactSellerViaWhatsApp() async {
    final phone = _listing?['contactPhone'] ?? '';
    final animalName = _listing?['animalName'] ?? 'animal';

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El vendedor no proporcionó un número.')));
      return;
    }

    final message =
        "Hola, vi tu publicación de '$animalName' en Manual Ganadero y me interesa tener más información.";
    final Uri whatsappUri =
        Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

    try {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No se pudo abrir WhatsApp. Intenta agregarlo manualmente.')));
    }
  }

  // Confirmación antes de borrar (Mejora de UX)
  Future<void> _confirmDelete() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFfbf6ec),
        title: const Text('Eliminar Publicación',
            style: TextStyle(
                color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold)),
        content: const Text(
            '¿Estás seguro de que deseas retirar este animal del Marketplace?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            // Sustituye tu bloque de código "NUEVO" por este:
            onPressed: () async {
              Navigator.pop(ctx);

              final animalId = _listing?['animalId'];
              final ownerId = _listing?['ownerId'];
              final ranchId =
                  _listing?['ranchId']; // El que agregamos en el paso anterior

              if (animalId != null && ownerId != null && ranchId != null) {
                try {
                  final animalRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(ownerId)
                      .collection('ranches')
                      .doc(ranchId)
                      .collection('animals')
                      .doc(animalId);

                  await animalRef.update({'isPublished': false});
                  print('Animal desbloqueado con éxito');
                } catch (e) {
                  print('Error al desbloquear animal: $e');
                }
              }
              await FirebaseFirestore.instance
                  .collection('marketplace_listings')
                  .doc(widget.listingId)
                  .delete();

              if (mounted) Navigator.pop(context);
            },
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFfbf6ec),
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFc99450))),
      );
    }

    final listing = _listing!;
    final bool isOwner =
        FirebaseAuth.instance.currentUser?.uid == listing['ownerId'];

    final animalName = listing['animalName'] ?? 'Sin nombre';
    final price = listing['price']?.toString() ?? '0.00';
    final state = listing['locationState'] ?? 'Desconocida';
    final municipality = listing['locationMunicipality'] ?? '';
    final fullLocation =
        municipality.isNotEmpty ? '$municipality, $state' : state;

    final description = listing['description'] ??
        'No hay detalles adicionales sobre este animal.';
    final breed = listing['breed'] ?? 'N/A';
    final sex = listing['sex'] ?? 'N/A';
    final purpose = listing['purpose'] ?? 'N/A';
    final birthWeight = listing['birthWeight'];
    final weaningWeight = listing['weaningWeight'];
    final imageUrl = listing['imageUrl'];
    final certifications = listing['certifications'] ?? '';
    List<dynamic> vaccinations = listing['vaccinations'] ?? [];

    // Calcular Edad
    String ageText = 'Desconocida';
    if (listing['birthDate'] != null) {
      DateTime birthDate = (listing['birthDate'] as Timestamp).toDate();
      int ageMonths = DateTime.now().difference(birthDate).inDays ~/ 30;
      if (ageMonths > 12) {
        ageText = '${ageMonths ~/ 12} años, ${ageMonths % 12} meses';
      } else {
        ageText = '$ageMonths meses';
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar:
          true, // Esto hace que la appbar flote sobre la imagen
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.8),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Color(0xFF5e3a1c), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          if (isOwner)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.8),
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                  onPressed: _confirmDelete,
                ),
              ),
            )
        ],
      ),
      body: Stack(
        children: [
          // --- 1. IMAGEN DE FONDO (Fija) ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                image: imageUrl != null && imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(imageUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: imageUrl == null || imageUrl.isEmpty
                  ? const Center(
                      child: Icon(FontAwesomeIcons.cow,
                          size: 100, color: Colors.grey))
                  : null,
            ),
          ),

          // --- 2. CONTENIDO DESLIZABLE (Efecto Bottom Sheet) ---
          SingleChildScrollView(
            child: Column(
              children: [
                // Espacio transparente para dejar ver la imagen
                SizedBox(height: MediaQuery.of(context).size.height * 0.38),

                // Contenedor principal con bordes redondeados
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(30)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, -5))
                      ]),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 25.0, vertical: 30.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre y Etiqueta "Tu Publicación"
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              animalName,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5e3a1c),
                                height: 1.1,
                              ),
                            ),
                          ),
                          if (isOwner)
                            Container(
                              margin: const EdgeInsets.only(left: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFc99450).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFFc99450)
                                          .withOpacity(0.5))),
                              child: const Text(
                                'Tu Publicación',
                                style: TextStyle(
                                  color: Color(0xFF8c5c32),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Ubicación
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(fullLocation,
                                style: const TextStyle(
                                    fontSize: 15, color: Colors.grey)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // Precio (Destacado)
                      Text(
                        '\$$price',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFc99450),
                        ),
                      ),
                      const SizedBox(height: 25),

                      // --- SECCIÓN: DATOS BIOLÓGICOS (GRID MEJORADO) ---
                      const Text('Datos del Animal',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5e3a1c))),
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 15,
                        runSpacing: 15,
                        children: [
                          _buildModernBadge(
                              'Raza', breed, FontAwesomeIcons.dna),
                          _buildModernBadge(
                              'Sexo', sex, FontAwesomeIcons.venusMars),
                          _buildModernBadge(
                              'Propósito', purpose, FontAwesomeIcons.bullseye),
                          _buildModernBadge(
                              'Edad', ageText, FontAwesomeIcons.calendarDays),
                          if (birthWeight != null)
                            _buildModernBadge('Peso Nacer', '$birthWeight kg',
                                FontAwesomeIcons.weightScale),
                          if (weaningWeight != null)
                            _buildModernBadge(
                                'Peso Destete',
                                '$weaningWeight kg',
                                FontAwesomeIcons.weightHanging),
                        ],
                      ),

                      // --- SECCIÓN: CERTIFICACIONES ---
                      if (certifications.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFc99450).withOpacity(0.15),
                                const Color(0xFFfbf6ec)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    const Color(0xFFc99450).withOpacity(0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(FontAwesomeIcons.award,
                                    color: Color(0xFFc99450), size: 24),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Certificaciones y Registros',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Color(0xFF5e3a1c))),
                                    const SizedBox(height: 5),
                                    Text(certifications,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                            height: 1.4)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // --- SECCIÓN: DESCRIPCIÓN ---
                      const SizedBox(height: 30),
                      const Text('Descripción',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5e3a1c))),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(description,
                            style: const TextStyle(
                                fontSize: 15,
                                height: 1.6,
                                color: Colors.black87)),
                      ),

                      // --- SECCIÓN: VACUNAS ---
                      if (vaccinations.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        const Text('Historial Médico Registrado',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5e3a1c))),
                        const SizedBox(height: 15),
                        Column(
                          children: vaccinations.map((vac) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.grey.shade100,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2))
                                ],
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(FontAwesomeIcons.syringe,
                                      color: Colors.green, size: 18),
                                ),
                                title: Text(vac['name'] ?? 'Vacuna',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                subtitle: Text(
                                    'Aplicada el: ${DateFormat('dd MMM yyyy', 'es_MX').format((vac['date'] as Timestamp).toDate())}'),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(
                          height: 100), // Espacio para el botón flotante
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // --- BOTÓN FLOTANTE INFERIOR (Solo si no es el dueño) ---
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: isOwner
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: FloatingActionButton.extended(
                  onPressed: _contactSellerViaWhatsApp,
                  elevation: 5,
                  backgroundColor:
                      const Color(0xFF25D366), // Color oficial de WhatsApp
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  icon: const Icon(FontAwesomeIcons.whatsapp,
                      size: 24, color: Colors.white),
                  label: const Text('Contactar al Vendedor',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5)),
                ),
              ),
            ),
    );
  }

  // --- NUEVO WIDGET PARA LAS TARJETAS BIOLÓGICAS (CORREGIDO) ---
  Widget _buildModernBadge(String title, String value, IconData icon) {
    // Calculamos el ancho para que quepan 2 por fila aproximadamente
    final double width = (MediaQuery.of(context).size.width - 65) / 2;

    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFfbf6ec),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFc99450).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFc99450)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(), // Transformación del String
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    // uppercase: true, <-- ELIMINA ESTA LÍNEA
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5e3a1c),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
