import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class RanchSetupScreen extends StatefulWidget {
  const RanchSetupScreen({super.key});

  @override
  State<RanchSetupScreen> createState() => _RanchSetupScreenState();
}

class _RanchSetupScreenState extends State<RanchSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  final TextEditingController _ranchNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _hectaresController = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  bool _isGettingLocation = false;

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);

        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          // Opcional: Podrías usar geocoding para poner el nombre de la ciudad aquí
          _locationController.text = "Ubicación GPS capturada";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('¡Ubicación obtenida correctamente!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al obtener ubicación: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _saveRanchInfo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_currentUser != null) {
        // 1. Creamos un nuevo documento con un ID automático en la subcolección 'ranches'
        DocumentReference newRanchRef = _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('ranches')
            .doc();

        await newRanchRef.set({
          'id': newRanchRef.id,
          'ranchName': _ranchNameController.text.trim(),
          'location': _locationController.text.trim(),
          'latitude': _latitude,
          'longitude': _longitude,
          'hectares': double.tryParse(_hectaresController.text.trim()) ?? 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 2. Marcamos este rancho como el "seleccionado actualmente" en el perfil del usuario
        await _firestore.collection('users').doc(_currentUser!.uid).update({
          'currentRanchId': newRanchRef.id,
          'setupCompleted': true,
        });

        if (mounted) Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      // Manejo de error...
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        backgroundColor: const Color(0xFFfbf6ec),
        elevation: 0,
        title: const Text('Configura tu Rancho',
            style: TextStyle(
                color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false, // Evita que regresen al registro
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.landscape, size: 80, color: Color(0xFFc99450)),
              const SizedBox(height: 20),
              const Text(
                '¡Bienvenido a Manual Ganadero Pro!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5e3a1c)),
              ),
              const SizedBox(height: 10),
              const Text(
                'Para ofrecerte una mejor experiencia y métricas precisas, cuéntanos un poco sobre tu propiedad.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _ranchNameController,
                decoration: InputDecoration(
                  labelText: 'Nombre del Rancho / Finca',
                  prefixIcon: const Icon(Icons.home_work, color: Colors.grey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 15),
              // CAMPO DE UBICACIÓN CON BOTÓN GPS
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Estado / Municipio o Referencia',
                  prefixIcon: const Icon(Icons.location_on),
                  suffixIcon: IconButton(
                    icon: _isGettingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location,
                            color: Color(0xFFc99450)),
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
                    tooltip: "Obtener mi ubicación actual",
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _hectaresController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Tamaño de la propiedad (Hectáreas)',
                  prefixIcon: const Icon(Icons.map, color: Colors.grey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFc99450),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isLoading ? null : _saveRanchInfo,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Guardar y Comenzar',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
