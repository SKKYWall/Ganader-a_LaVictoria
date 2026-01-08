// lib/screens/marketplace/marketplace_product_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importar FirebaseAuth
import 'package:intl/intl.dart'; // Para formatear la fecha
import 'package:manual_ganadero_flutter/models/marketplace_listing.dart'; // Importar tu modelo de listado
import 'package:flutter/services.dart'; // Para FilteringTextInputFormatter
import 'package:manual_ganadero_flutter/models/animal.dart'; // Importar Animal y VaccineRecord

class MarketplaceProductDetailScreen extends StatefulWidget {
  final String listingId;

  const MarketplaceProductDetailScreen({
    super.key,
    required this.listingId,
  });

  @override
  State<MarketplaceProductDetailScreen> createState() =>
      _MarketplaceProductDetailScreenState();
}

class _MarketplaceProductDetailScreenState
    extends State<MarketplaceProductDetailScreen> {
  MarketplaceListing? _listing;
  bool _isLoading = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser =
      FirebaseAuth.instance.currentUser; // Obtener usuario actual

  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProductDetail();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadProductDetail() async {
    try {
      // Cargar directamente desde la colección pública de listings
      _firestore
          .collection('marketplace_listings')
          .doc(widget.listingId)
          .snapshots() // Usar snapshots para actualizaciones en tiempo real
          .listen((docSnapshot) {
        if (!mounted) return;
        if (docSnapshot.exists && docSnapshot.data() != null) {
          setState(() {
            _listing = MarketplaceListing.fromFirestore(
                docSnapshot.data() as Map<String, dynamic>, docSnapshot.id);
            _isLoading = false;
            // Si hay un precio en el listing, inicializar el controlador de texto
            _priceController.text = _listing!.price.toStringAsFixed(2);
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Publicación no encontrada.')),
          );
          Navigator.of(context).pop(); // Volver si la publicación no existe
        }
      });
    } catch (e) {
      print('Error al cargar detalles del producto en el marketplace: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Error al cargar detalles del producto: ${e.toString()}')),
      );
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    return formatter.format(amount);
  }

  Widget _buildDetailRow(String label, String? value) {
    String displayValue =
        (value == null || value.isEmpty || value == 'null') ? 'N/A' : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF5e3a1c),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  // Helper para formatear fechas de tipo DateTime
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime != null) {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
    return 'N/A';
  }

  // Helper para formatear pesos
  String _formatWeight(double? weight) {
    return weight != null ? '${weight.toStringAsFixed(1)} kg' : 'N/A';
  }

  // Widget auxiliar para títulos de sección (añadido para consistencia visual)
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, top: 15.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF5e3a1c),
        ),
      ),
    );
  }

  // --- NUEVAS FUNCIONES PARA PROPIETARIO ---

  Future<void> _handleUpdatePrice() async {
    if (_listing == null ||
        _currentUser == null ||
        _currentUser!.uid != _listing!.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No tienes permiso para editar este anuncio.')),
      );
      return;
    }

    final newPriceText = _priceController.text.trim();
    final newPrice = double.tryParse(newPriceText);

    if (newPrice == null || newPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un precio válido.')),
      );
      return;
    }

    try {
      await _firestore
          .collection('marketplace_listings')
          .doc(_listing!.listingId)
          .update({'price': newPrice});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Precio actualizado correctamente.')),
      );
    } catch (e) {
      print('Error al actualizar precio: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar precio: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleRemoveListing() async {
    if (_listing == null ||
        _currentUser == null ||
        _currentUser!.uid != _listing!.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No tienes permiso para eliminar este anuncio.')),
      );
      return;
    }

    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Publicación',
              style: TextStyle(color: Color(0xFF5e3a1c))),
          content: const Text(
            '¿Estás seguro de que deseas eliminar este animal del Marketplace? Esto no afectará su registro en tus animales, solo su visibilidad para venta.',
            style: TextStyle(color: Colors.black87),
          ),
          backgroundColor: const Color(0xFFfbf6ec),
          surfaceTintColor: const Color(0xFFfbf6ec),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF6b4226))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar del Marketplace',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await _firestore
            .collection('marketplace_listings')
            .doc(_listing!.listingId)
            .delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Publicación eliminada del Marketplace correctamente.')),
        );
        Navigator.of(context)
            .pop(true); // Volver y quizás forzar una actualización
      } catch (e) {
        print('Error al eliminar publicación: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al eliminar publicación: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determinar si el usuario actual es el propietario del listado
    final bool isOwner = _currentUser?.uid == _listing?.ownerId;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFfbf6ec),
        appBar: AppBar(
          backgroundColor: const Color(0xFFf5f0e1),
          title: const Text(
            'Cargando...',
            style: TextStyle(
                color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF5e3a1c)),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6b4226)),
          ),
        ),
      );
    }

    if (_listing == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFfbf6ec),
        appBar: AppBar(
          backgroundColor: const Color(0xFFf5f0e1),
          title: const Text('Detalle del Producto',
              style: TextStyle(color: Color(0xFF5e3a1c))),
        ),
        body: const Center(
          child: Text(
            'Producto no encontrado en el Marketplace.',
            style: TextStyle(fontSize: 16, color: Color(0xFF5e3a1c)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        backgroundColor: const Color(0xFFf5f0e1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF5e3a1c)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          _listing!.title,
          style: const TextStyle(
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
            // Sección de imagen principal
            Center(
              child: Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  image: _listing!.profileImageUrl != null &&
                          _listing!.profileImageUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(_listing!.profileImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _listing!.profileImageUrl == null ||
                        _listing!.profileImageUrl!.isEmpty
                    ? Icon(Icons.photo_size_select_actual,
                        size: 100, color: Colors.grey[400])
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            // Precio y Título del anuncio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _listing!.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5e3a1c),
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Precio: Editable si es el propietario, estático si no
                      isOwner
                          ? Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _priceController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+\.?\d{0,2}')),
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Precio (MXN)',
                                        prefixIcon: const Icon(
                                            Icons.attach_money,
                                            color: Color(0xFF5e3a1c)),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        labelStyle: const TextStyle(
                                            color: Color(0xFF5e3a1c)),
                                      ),
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFc99450)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: _handleUpdatePrice,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6b4226),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 15, vertical: 15),
                                    ),
                                    child: const Text('Actualizar'),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              'Precio: ${_formatCurrency(_listing!.price)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFc99450),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Descripción del listing
            Text(
              _listing!.description,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),

            // Detalles del animal
            _buildSectionTitle('Detalles del Animal'),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Raza', _listing!.breed),
                    _buildDetailRow('Sexo', _listing!.sex),
                    // Usar _formatDateTime para la fecha de nacimiento
                    _buildDetailRow('Fecha de Nacimiento',
                        _formatDateTime(_listing!.birthDate)),
                    _buildDetailRow('Número de Arete', _listing!.earTagNumber),
                    _buildDetailRow('Número de Pierna', _listing!.legNumber),
                    _buildDetailRow('Ubicación del Animal', _listing!.location),
                    _buildDetailRow(
                        'Número de Registro', _listing!.registrationNumber),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sección de Vacunación
            _buildSectionTitle('Vacunación'),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _listing!.vaccinations != null &&
                        _listing!.vaccinations!.isNotEmpty
                    ? ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _listing!.vaccinations!.length,
                        itemBuilder: (context, index) {
                          final vaccine = _listing!.vaccinations![index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.vaccines,
                                    color: Color(0xFFc99450), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style,
                                      children: <TextSpan>[
                                        TextSpan(
                                          text: '${vaccine.name}: ',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF5e3a1c)),
                                        ),
                                        TextSpan(
                                          text: DateFormat('dd/MM/yyyy')
                                              .format(vaccine.date),
                                          style: const TextStyle(
                                              color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Text(
                          'No hay vacunas registradas para este animal.',
                          style: TextStyle(
                              fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Sección de Información de Reproducción (Preñez) - Solo si es Hembra
            if (_listing!.sex == 'Hembra')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Información de Reproducción'),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            'Preñada',
                            _listing!.isPregnant != null
                                ? (_listing!.isPregnant! ? 'Sí' : 'No')
                                : 'No especificado',
                          ),
                          if (_listing!.isPregnant == true &&
                              _listing!.pregnancyDate != null)
                            _buildDetailRow(
                              'Fecha de Preñez',
                              DateFormat('dd/MM/yyyy')
                                  .format(_listing!.pregnancyDate!),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),

            // Información de Peso y Parentesco
            _buildSectionTitle('Información de Peso y Parentesco'),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Peso al Nacimiento',
                        _formatWeight(_listing!.birthWeight)),
                    _buildDetailRow('Peso al Destete',
                        _formatWeight(_listing!.weaningWeight)),
                    _buildDetailRow('Padre', _listing!.father),
                    _buildDetailRow('Madre', _listing!.mother),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Salud y Genética
            _buildSectionTitle('Salud y Genética'),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Resistencia a Enfermedades',
                        _listing!.diseaseResistance),
                    _buildDetailRow(
                        'Información de Fertilidad', _listing!.fertilityInfo),
                    _buildDetailRow(
                        'Marcadores Genéticos', _listing!.geneticMarkers),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Información de contacto del publicador (si se incluye en el listado)
            if (_listing!.publisherEmail != null ||
                _listing!.publisherPhone != null ||
                _listing!.publisherRanchAddress != null ||
                (_listing!.publisherSocialMedia != null &&
                    _listing!.publisherSocialMedia!.isNotEmpty)) ...[
              _buildSectionTitle('Información de Contacto del Vendedor'),
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                          'Correo Electrónico', _listing!.publisherEmail),
                      _buildDetailRow('Teléfono', _listing!.publisherPhone),
                      _buildDetailRow('Dirección del Rancho',
                          _listing!.publisherRanchAddress),
                      if (_listing!.publisherSocialMedia != null &&
                          _listing!.publisherSocialMedia!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Redes Sociales:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5e3a1c),
                          ),
                        ),
                        const SizedBox(height: 5),
                        ..._listing!.publisherSocialMedia!.entries.map((entry) {
                          return _buildDetailRow(
                              entry.key.substring(0, 1).toUpperCase() +
                                  entry.key
                                      .substring(1), // Capitaliza el nombre
                              entry.value.toString());
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],

            // Botón "Entrar en contacto" o "Eliminar del Marketplace"
            Center(
              child: SizedBox(
                width: double.infinity,
                child: isOwner
                    ? ElevatedButton.icon(
                        onPressed: _handleRemoveListing,
                        icon: const Icon(Icons.delete_forever,
                            color: Colors.white),
                        label: const Text('Eliminar del Marketplace',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Funcionalidad de contacto por implementar.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.message),
                        label: const Text('Contactar Vendedor'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6b4226),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
