// lib/screens/intelligence/intelligence_screen.dart

import 'dart:io';
import 'dart:typed_data'; // Importar para Float32List y Uint8List
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img_lib; // Alias para la librería 'image'
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

// Usamos tu modelo Animal existente
import 'package:manual_ganadero_flutter/models/animal.dart';

// Modelo para los registros de análisis
class AnalysisRecord {
  final String id;
  final String imageUrl;
  final String aiResult;
  final String? animalId; // ID del animal asociado, opcional
  final String? animalName; // Nombre del animal asociado, opcional
  final DateTime timestamp;

  AnalysisRecord({
    required this.id,
    required this.imageUrl,
    required this.aiResult,
    this.animalId,
    this.animalName,
    required this.timestamp,
  });

  factory AnalysisRecord.fromFirestore(Map<String, dynamic> data, String id) {
    return AnalysisRecord(
      id: id,
      imageUrl: data['imageUrl'] as String,
      aiResult: data['aiResult'] as String,
      animalId: data['animalId'] as String?,
      animalName: data['animalName'] as String?,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'aiResult': aiResult,
      'animalId': animalId,
      'animalName': animalName,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class IntelligenceScreen extends StatefulWidget {
  const IntelligenceScreen({super.key});

  @override
  State<IntelligenceScreen> createState() => _IntelligenceScreenState();
}

class _IntelligenceScreenState extends State<IntelligenceScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  User? _currentUser;

  List<Animal> _registeredAnimals = [];
  Animal? _selectedAnimal; // Animal seleccionado para análisis

  File? _imageToAnalyze; // Imagen seleccionada para análisis
  bool _isAnalyzing = false;
  String _analysisMessage = "Sube una imagen para análisis de IA.";

  Interpreter? _interpreter;
  List<String>? _labels;
  List<AnalysisRecord> _analysisRecords = []; // Historial de análisis

  // Variables para la comparación
  AnalysisRecord? _recordToCompare1;
  AnalysisRecord? _recordToCompare2;

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((user) {
      if (!mounted) return; // Add mounted check
      setState(() {
        _currentUser = user;
        if (user != null) {
          _loadRegisteredAnimals();
          _loadAnalysisRecords();
          _loadModelAndLabels(); // Cargar el modelo cuando el usuario esté autenticado
        } else {
          _registeredAnimals.clear();
          _selectedAnimal = null;
          _analysisRecords.clear();
          _analysisMessage = "Inicia sesión para usar la IA.";
          _interpreter
              ?.close(); // Cerrar el intérprete si el usuario cierra sesión
          _interpreter = null;
          _labels = null;
          _recordToCompare1 = null;
          _recordToCompare2 = null;
        }
      });
    });
  }

  // --- Carga el modelo de IA y las etiquetas ---
  Future<void> _loadModelAndLabels() async {
    if (_interpreter != null && _labels != null) return; // Ya cargado

    if (!mounted) return; // Add mounted check
    setState(() {
      _analysisMessage = "Cargando modelo de IA...";
    });

    try {
      _interpreter = await Interpreter.fromAsset(
          'assets/models/model_unquant.tflite'); // Nombre de archivo corregido
      print('Modelo de IA cargado exitosamente.');

      String labelsData =
          await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelsData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      print('Etiquetas de IA cargadas: $_labels');

      if (!mounted) return; // Add mounted check
      setState(() {
        _analysisMessage = "Modelo de IA listo.";
      });
    } catch (e) {
      print('Error al cargar el modelo o las etiquetas de IA: $e');
      if (!mounted) return; // Add mounted check
      setState(() {
        _analysisMessage =
            'Error: No se pudo cargar el modelo de IA. Verifica los archivos.';
      });
    }
  }

  // --- Carga los animales registrados del usuario actual ---
  Future<void> _loadRegisteredAnimals() async {
    if (_currentUser == null) return;

    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('animals')
          .get();

      if (!mounted) return; // Add mounted check
      setState(() {
        _registeredAnimals = snapshot.docs
            .map((doc) => Animal.fromFirestore(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList();
        if (_selectedAnimal != null &&
            !_registeredAnimals.any((a) => a.id == _selectedAnimal!.id)) {
          _selectedAnimal = null;
        }
      });
    } catch (e) {
      print('Error al cargar animales registrados: $e');
      if (!mounted) return; // Add mounted check
      _showSnackBar('Error al cargar animales registrados.');
    }
  }

  // --- Carga el historial de análisis de IA del usuario ---
  Future<void> _loadAnalysisRecords() async {
    if (_currentUser == null) return;

    try {
      _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('analysis_records')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return; // Add mounted check
        setState(() {
          _analysisRecords = snapshot.docs
              .map((doc) => AnalysisRecord.fromFirestore(doc.data(), doc.id))
              .toList();
        });
      });
    } catch (e) {
      print('Error al cargar historial de análisis: $e');
      if (!mounted) return; // Add mounted check
      _showSnackBar('Error al cargar historial de análisis.');
    }
  }

  // --- Selección de Imagen ---
  Future<void> _pickImage(ImageSource source) async {
    if (_currentUser == null) {
      if (!mounted) return; // Add mounted check
      _showSnackBar('Necesitas iniciar sesión para subir fotos.');
      return;
    }
    if (_interpreter == null || _labels == null) {
      if (!mounted) return; // Add mounted check
      _showSnackBar(
          'El modelo de IA aún no está cargado. Espera un momento y reintenta.');
      await _loadModelAndLabels();
      if (_interpreter == null || _labels == null) {
        if (!mounted) return; // Add mounted check
        _showSnackBar(
            'El modelo de IA no pudo cargarse. Verifica los archivos.');
        return;
      }
    }

    final pickedFile = await ImagePicker().pickImage(source: source);

    if (pickedFile != null) {
      if (!mounted) return; // Add mounted check
      setState(() {
        _imageToAnalyze = File(pickedFile.path);
        _analysisMessage = "Imagen seleccionada. Analizando...";
        _isAnalyzing = true;
      });
      _analyzeAndUploadImage(_imageToAnalyze!);
    } else {
      if (!mounted) return; // Add mounted check
      setState(() {
        _analysisMessage = "No se seleccionó ninguna imagen.";
      });
    }
  }

  // --- Análisis de Imagen y Subida a Firebase ---
  Future<void> _analyzeAndUploadImage(File imageFile) async {
    if (_currentUser == null || _interpreter == null || _labels == null) {
      if (!mounted) return; // Add mounted check
      setState(() {
        _analysisMessage =
            "Error: Usuario no autenticado o modelo de IA no cargado.";
        _isAnalyzing = false;
      });
      return;
    }

    String aiResultText = "Análisis fallido.";
    String? uploadedImageUrl;

    try {
      // 1. Ejecutar análisis de IA localmente (código existente)
      final originalImage = img_lib.decodeImage(imageFile.readAsBytesSync());
      if (originalImage == null) {
        throw Exception("No se pudo decodificar la imagen. Formato inválido.");
      }

      final resizedImage =
          img_lib.copyResize(originalImage, width: 224, height: 224);

      var inputBytes = Float32List(1 * 224 * 224 * 3);
      int pixelIndex = 0;
      for (int y = 0; y < resizedImage.height; y++) {
        for (int x = 0; x < resizedImage.width; x++) {
          final img_lib.Pixel pixel = resizedImage.getPixel(x, y);
          inputBytes[pixelIndex++] = pixel.r / 255.0;
          inputBytes[pixelIndex++] = pixel.g / 255.0;
          inputBytes[pixelIndex++] = pixel.b / 255.0;
        }
      }

      var input = inputBytes.reshape([1, 224, 224, 3]);
      var output =
          List.filled(1 * _labels!.length, 0).reshape([1, _labels!.length]);

      _interpreter!.run(input, output);

      List<double> probabilities = output[0].cast<double>();
      double maxProb = 0;
      int predictedIndex = -1;

      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          predictedIndex = i;
        }
      }

      if (predictedIndex != -1 && predictedIndex < _labels!.length) {
        aiResultText =
            "Detectado: ${_labels![predictedIndex]} (${(maxProb * 100).toStringAsFixed(2)}%)";
      } else {
        aiResultText = "No se pudo determinar el resultado de la IA.";
      }

      // --- INICIO: Manejo de errores más granular para Firebase ---
      // 2. Subir la imagen a Firebase Storage
      try {
        final String fileName =
            '${_currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
        final Reference storageRef =
            _storage.ref().child('analysis_images/$fileName');
        final UploadTask uploadTask = storageRef.putFile(imageFile);
        final TaskSnapshot snapshot = await uploadTask;
        uploadedImageUrl = await snapshot.ref.getDownloadURL();
        print('Imagen subida a Storage: $uploadedImageUrl');
      } on FirebaseException catch (e) {
        print('Error Firebase Storage: ${e.code} - ${e.message}');
        throw Exception(
            'Error al subir imagen a Firebase Storage: ${e.message}');
      } catch (e) {
        print('Error desconocido al subir imagen a Storage: $e');
        throw Exception(
            'Error desconocido al subir imagen a Storage: ${e.toString()}');
      }

      // 3. Guardar el registro del análisis en Firestore
      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('analysis_records')
            .add(
              AnalysisRecord(
                id: '', // Firestore asignará uno
                imageUrl: uploadedImageUrl, // Usamos la URL que obtuvimos
                aiResult: aiResultText,
                animalId: _selectedAnimal?.id,
                animalName: _selectedAnimal?.name,
                timestamp: DateTime.now(),
              ).toFirestore(),
            );
        print('Análisis de IA guardado en Firestore.');
        if (!mounted) return; // Add mounted check
        _showSnackBar('Análisis completado y guardado.');
      } on FirebaseException catch (e) {
        print('Error Firebase Firestore: ${e.code} - ${e.message}');
        throw Exception('Error al guardar registro en Firestore: ${e.message}');
      } catch (e) {
        print('Error desconocido al guardar registro en Firestore: $e');
        throw Exception(
            'Error desconocido al guardar registro en Firestore: ${e.toString()}');
      }
      // --- FIN: Manejo de errores más granular para Firebase ---
    } catch (e) {
      // Este bloque catch general manejará excepciones del análisis de IA
      // o excepciones relanzadas desde los bloques try-catch internos (Storage/Firestore).
      print('Fallo general en el análisis o subida: $e');
      aiResultText =
          'Error en el análisis: ${e.toString().split(':')[0]}. Detalles: ${e.toString()}';
      if (!mounted) return; // Add mounted check
      _showSnackBar(
          'Error al procesar la imagen: ${e.toString().split(':')[0]}.');
    } finally {
      if (!mounted) return; // Add mounted check
      setState(() {
        _analysisMessage = aiResultText;
        _isAnalyzing = false;
        _imageToAnalyze = null; // Limpiar imagen después del análisis
      });
    }
  }

  // --- Lógica de Comparación ---
  void _toggleRecordForComparison(AnalysisRecord record) {
    setState(() {
      if (_recordToCompare1 == null) {
        _recordToCompare1 = record;
      } else if (_recordToCompare2 == null &&
          _recordToCompare1!.id != record.id) {
        _recordToCompare2 = record;
      } else if (_recordToCompare1!.id == record.id) {
        _recordToCompare1 =
            null; // Deseleccionar el primero si se pulsa de nuevo
      } else if (_recordToCompare2!.id == record.id) {
        _recordToCompare2 =
            null; // Deseleccionar el segundo si se pulsa de nuevo
      } else {
        // Si ya hay dos seleccionados y se pulsa uno nuevo, reemplaza el segundo
        _recordToCompare1 = record; // Reemplazar con el nuevo
        _recordToCompare2 = null;
      }
    });

    if (_recordToCompare1 != null && _recordToCompare2 != null) {
      _showComparisonDialog();
    }
  }

  Future<void> _showComparisonDialog() async {
    if (_recordToCompare1 == null || _recordToCompare2 == null) {
      if (!mounted) return; // Add mounted check
      _showSnackBar('Selecciona dos análisis para comparar.');
      return;
    }

    // Obtener los datos completos de los animales si están asociados
    Animal? animal1;
    Animal? animal2;

    if (_recordToCompare1!.animalId != null) {
      try {
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('animals')
            .doc(_recordToCompare1!.animalId)
            .get();
        if (doc.exists) {
          animal1 =
              Animal.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
        }
      } catch (e) {
        print('Error al cargar animal 1 para comparación: $e');
      }
    }

    if (_recordToCompare2!.animalId != null) {
      try {
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('animals')
            .doc(_recordToCompare2!.animalId)
            .get();
        if (doc.exists) {
          animal2 =
              Animal.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
        }
      } catch (e) {
        print('Error al cargar animal 2 para comparación: $e');
      }
    }

    if (!mounted) return; // Add mounted check before showing dialog
    // Mostrar el diálogo de comparación
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Comparación de Análisis',
            style: TextStyle(
                color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFfbf6ec),
          surfaceTintColor: const Color(0xFFfbf6ec),
          content: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _buildComparisonCard(_recordToCompare1!, animal1)),
                const SizedBox(width: 10),
                Expanded(
                    child: _buildComparisonCard(_recordToCompare2!, animal2)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!mounted) {
                  return; // Add mounted check inside onPressed if needed
                }
                Navigator.of(context).pop();
                setState(() {
                  _recordToCompare1 = null; // Limpiar selección al cerrar
                  _recordToCompare2 = null;
                });
              },
              child: const Text('Cerrar',
                  style: TextStyle(color: Color(0xFF6b4226))),
            ),
          ],
        );
      },
    );
  }

  Widget _buildComparisonCard(AnalysisRecord record, Animal? animal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.network(
            record.imageUrl,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 120,
              height: 120,
              color: Colors.grey[200],
              child:
                  const Icon(Icons.broken_image, size: 60, color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          record.aiResult,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF5e3a1c)),
        ),
        const SizedBox(height: 5),
        Text(
          DateFormat('dd/MM/yyyy').format(record.timestamp),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Divider(color: Color.fromARGB(128, 201, 148, 80)),
        if (animal != null) ...[
          _buildInfoRow('Nombre:', animal.name),
          _buildInfoRow('Raza:', animal.breed ?? 'N/A'),
          _buildInfoRow('Sexo:', animal.sex ?? 'N/A'),
          _buildInfoRow('Edad:', animal.age?.toString() ?? 'N/A'),
        ] else ...[
          const Text(
            'No asociado a un animal registrado.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5e3a1c),
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
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
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Análisis de IA para Ganado',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5e3a1c),
          ),
        ),
        centerTitle: true,
      ),
      body: _currentUser == null
          ? const Center(
              child: Text(
                'Por favor, inicia sesión para usar la funcionalidad de IA.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF5e3a1c)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sección 1: Seleccionar Animal y Subir Fotos
                  _buildSectionTitle('Análisis con Animal Registrado'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<Animal>(
                    decoration: InputDecoration(
                      labelText: 'Seleccionar Animal',
                      labelStyle: const TextStyle(color: Color(0xFF5e3a1c)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    value: _selectedAnimal,
                    hint: const Text('Elige un animal de tu lista'),
                    items: _registeredAnimals.map((animal) {
                      return DropdownMenuItem<Animal>(
                        value: animal,
                        child: Text(animal.name),
                      );
                    }).toList(),
                    onChanged: (Animal? newValue) {
                      setState(() {
                        _selectedAnimal = newValue;
                      });
                    },
                    isExpanded: true,
                    style: const TextStyle(color: Color(0xFF5e3a1c)),
                    dropdownColor: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildUploadButton('Tomar Foto', Icons.camera_alt, () {
                        if (_selectedAnimal == null) {
                          _showSnackBar(
                              'Por favor, selecciona un animal primero.');
                        } else {
                          _pickImage(ImageSource.camera);
                        }
                      }),
                      _buildUploadButton('Galería', Icons.photo_library, () {
                        if (_selectedAnimal == null) {
                          _showSnackBar(
                              'Por favor, selecciona un animal primero.');
                        } else {
                          _pickImage(ImageSource.gallery);
                        }
                      }),
                    ],
                  ),

                  const Divider(
                      height: 40, thickness: 1, color: Color(0xFFc99450)),

                  // Sección 2: Subir Fotos sin Animal
                  _buildSectionTitle('Análisis Rápido (sin animal asociado)'),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildUploadButton(
                          'Tomar Foto', Icons.camera_alt_outlined, () {
                        setState(() {
                          _selectedAnimal = null;
                        });
                        _pickImage(ImageSource.camera);
                      }),
                      _buildUploadButton(
                          'Galería', Icons.collections_bookmark_outlined, () {
                        setState(() {
                          _selectedAnimal = null;
                        });
                        _pickImage(ImageSource.gallery);
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Área de previsualización de imagen y resultado del análisis
                  Center(
                    child: Column(
                      children: [
                        _imageToAnalyze == null
                            ? Container(
                                height: 150,
                                width: 150,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[400]!),
                                ),
                                child: Icon(Icons.image,
                                    size: 80, color: Colors.grey[400]),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(_imageToAnalyze!,
                                    height: 150, width: 150, fit: BoxFit.cover),
                              ),
                        const SizedBox(height: 15),
                        _isAnalyzing
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF6b4226)),
                              )
                            : Text(
                                _analysisMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5e3a1c)),
                              ),
                      ],
                    ),
                  ),

                  const Divider(
                      height: 40, thickness: 1, color: Color(0xFFc99450)),

                  // Sección 3: Análisis Realizados
                  _buildSectionTitle('Análisis Realizados'),
                  const SizedBox(height: 10),
                  _analysisRecords.isEmpty
                      ? const Center(
                          child: Text(
                          'No hay análisis previos.',
                          style:
                              TextStyle(fontSize: 14, color: Color(0xFF5e3a1c)),
                        ))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _analysisRecords.length,
                          itemBuilder: (context, index) {
                            final record = _analysisRecords[index];
                            bool isSelected1 =
                                _recordToCompare1?.id == record.id;
                            bool isSelected2 =
                                _recordToCompare2?.id == record.id;
                            bool isSelected = isSelected1 || isSelected2;

                            return _buildAnalysisRecordCard(record, isSelected);
                          },
                        ),
                  const SizedBox(height: 20),
                  // Botón de comparación
                  if (_recordToCompare1 != null && _recordToCompare2 != null)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _showComparisonDialog,
                        icon: const Icon(Icons.compare_arrows,
                            color: Colors.white),
                        label: const Text('Comparar Seleccionados',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFc99450),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 20),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  const Divider(
                      height: 40, thickness: 1, color: Color(0xFFc99450)),

                  // Sección 4: Sugerencia de Cruces (IA Avanzada)
                  _buildSectionTitle('Sugerencia de Cruces (Próximamente)'),
                  const SizedBox(height: 10),
                  Card(
                    margin: const EdgeInsets.only(bottom: 10.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Esta funcionalidad te permitirá obtener recomendaciones de cruces óptimos para tus animales.',
                            style: TextStyle(
                                fontSize: 15, color: Color(0xFF5e3a1c)),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Requiere un modelo de Inteligencia Artificial avanzado que considere factores como genética, historial de producción y objetivos de mejora. Estamos trabajando para integrar esta característica.',
                            style:
                                TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () {
                              _showSnackBar(
                                  '¡Estamos desarrollando esta función avanzada!');
                            },
                            icon: const Icon(Icons.info_outline,
                                color: Colors.white),
                            label: const Text('Más información',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFc99450),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  // --- Widgets Auxiliares ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF5e3a1c),
        ),
      ),
    );
  }

  Widget _buildUploadButton(
      String text, IconData icon, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5.0),
        child: ElevatedButton.icon(
          onPressed: _isAnalyzing ? null : onPressed,
          icon: Icon(icon, color: Colors.white),
          label: Text(text, style: const TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6b4226),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            disabledBackgroundColor: Color.fromARGB(
                128, 107, 66, 38), // 0x80 is 128 in decimal for 0.5 opacidad
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisRecordCard(AnalysisRecord record, bool isSelected) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: isSelected
            ? const BorderSide(color: Color(0xFFc99450), width: 2.0)
            : BorderSide.none,
      ),
      elevation: 2,
      child: InkWell(
        onTap: () => _toggleRecordForComparison(record),
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen del análisis
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  record.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.aiResult,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF5e3a1c),
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (record.animalName != null &&
                        record.animalName!.isNotEmpty)
                      Text(
                        'Animal Asociado: ${record.animalName}',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                      ),
                    Text(
                      'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(record.timestamp)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.check_circle, color: Color(0xFF6b4226)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
