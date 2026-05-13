// lib/widgets/voice_action_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:manual_ganadero_flutter/services/ai_voice_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VALORES VÁLIDOS — deben coincidir EXACTAMENTE con edit_animal_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
const _validSex = ['Macho', 'Hembra'];
const _validPurposes = [
  'Leche',
  'Carne',
  'Genética',
  'Engorda',
  'Reproductora'
];
const _validBreeds = [
  'Nelore',
  'Angus',
  'Brangus',
  'Brahman',
  'Brahman Rojo',
  'Hereford',
  'Charolais',
  'Simmental',
  'Limousin',
  'Holstein',
  'Jersey',
  'Suizo Pardo',
  'Guzerat',
  'Indubrasil',
  'Beefmaster',
  'Santa Gertrudis',
  'Texas Longhorn',
  'Cebú',
  'Otro',
];

// ── Palabras clave ampliadas (igual que en live_voice_dialog) ──
const _confirmWords = [
  'sí',
  'si',
  'claro',
  'ok',
  'dale',
  'correcto',
  'aceptar',
  'confirmar',
  'confirma',
  'guardarlo',
  'guardar',
  'adelante',
  'exacto',
  'perfecto',
  'listo',
  'va',
];
const _cancelWords = [
  'no',
  'cancela',
  'cancelar',
  'espera',
  'mal',
  'error',
  'incorrecto',
  'está mal',
  'para',
  'detente',
  'borra',
];

class VoiceActionDialog {
  // ─────────────────────────────────────────────
  // PUNTO DE ENTRADA (flujo manual)
  // ─────────────────────────────────────────────
  static Future<void> show(BuildContext context, String transcribedText) async {
    if (transcribedText.trim().isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFc99450))),
    );

    try {
      final data = await AIVoiceService.processCommand(transcribedText);
      if (context.mounted) Navigator.of(context).pop();
      if (data == null) {
        if (context.mounted)
          _showSnack(context, 'No entendí la instrucción. Intenta de nuevo.',
              Colors.orange);
        return;
      }
      if (context.mounted)
        await showConfirmationModal(context, data, transcribedText);
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _showSnack(context, 'Error de conexión. Intenta de nuevo.', Colors.red);
      }
    }
  }

  // ─────────────────────────────────────────────
  // MODAL DE CONFIRMACIÓN
  // autoExecute=true → ejecuta Firebase directamente
  // ─────────────────────────────────────────────
  static Future<void> showConfirmationModal(
      BuildContext context, Map<String, dynamic> data, String originalText,
      {bool autoExecute = false}) async {
    final tts = FlutterTts();
    await tts.setLanguage('es-MX');
    await tts.setSpeechRate(0.48);
    await tts.awaitSpeakCompletion(true);

    final accion = data['accion']?.toString() ?? 'registrar_evento';

    String initSexo = data['sexo']?.toString() ?? 'Hembra';
    if (!_validSex.contains(initSexo)) initSexo = 'Hembra';
    String initRaza = data['raza']?.toString() ?? 'Otro';
    if (!_validBreeds.contains(initRaza)) initRaza = 'Otro';
    String initProp = data['proposito']?.toString() ?? 'Reproductora';
    if (!_validPurposes.contains(initProp)) initProp = 'Reproductora';

    final animalCtrl =
        TextEditingController(text: data['animal']?.toString() ?? '');
    final areteCtrl = TextEditingController(
        text: _cleanIdField(data['arete']?.toString() ?? ''));
    final piernaCtrl = TextEditingController(
        text: _cleanIdField(data['pierna']?.toString() ?? ''));
    final razaCtrl = TextEditingController(text: initRaza);
    final sexoCtrl = TextEditingController(text: initSexo);
    final propCtrl = TextEditingController(text: initProp);
    final pesoCtrl =
        TextEditingController(text: data['peso']?.toString() ?? '');
    final vacunaCtrl =
        TextEditingController(text: data['vacuna']?.toString() ?? '');
    final eventoCtrl =
        TextEditingController(text: data['evento']?.toString() ?? '');
    final detallesCtrl =
        TextEditingController(text: data['detalles']?.toString() ?? '');
    final nacimientoCtrl = TextEditingController(
        text: _cleanDateField(data['fecha_nacimiento']?.toString() ?? ''));

    if (autoExecute) {
      await _ejecutarAccionFirebase(
          context,
          accion,
          animalCtrl.text,
          areteCtrl.text,
          piernaCtrl.text,
          razaCtrl.text,
          sexoCtrl.text,
          propCtrl.text,
          pesoCtrl.text,
          vacunaCtrl.text,
          eventoCtrl.text,
          detallesCtrl.text,
          nacimientoCtrl.text);
      return;
    }

    final config = _actionConfig(accion);
    final resumen =
        data['resumen_confirmacion']?.toString() ?? 'Confirma los datos';

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          bool isListeningConfirm = false;
          bool hasRespondedVoice = false; // FIX #5: evitar doble respuesta
          final speech = stt.SpeechToText();

          void listenForVoiceConfirm() async {
            final available = await speech.initialize();
            if (!available || !ctx.mounted) return;
            setModalState(() => isListeningConfirm = true);
            hasRespondedVoice = false;

            // FIX #1: Pequeña pausa antes de escuchar
            await Future.delayed(const Duration(milliseconds: 400));

            speech.listen(
              onResult: (result) async {
                // FIX #3: Esperar resultado final
                if (!result.finalResult) return;
                if (hasRespondedVoice) return; // FIX #5: evitar doble disparo
                final words = result.recognizedWords.toLowerCase().trim();
                if (words.isEmpty) return;

                final confirmed = _confirmWords.any((w) => words.contains(w));
                final cancelled = _cancelWords.any((w) => words.contains(w));

                if (!confirmed && !cancelled) {
                  // No se entendió: avisar y dejar botones visibles
                  setModalState(() => isListeningConfirm = false);
                  return;
                }

                hasRespondedVoice = true;
                await speech.stop();
                setModalState(() => isListeningConfirm = false);

                if (confirmed) {
                  Navigator.of(ctx).pop();
                  _ejecutarAccionFirebase(
                      context,
                      accion,
                      animalCtrl.text,
                      areteCtrl.text,
                      piernaCtrl.text,
                      razaCtrl.text,
                      sexoCtrl.text,
                      propCtrl.text,
                      pesoCtrl.text,
                      vacunaCtrl.text,
                      eventoCtrl.text,
                      detallesCtrl.text,
                      nacimientoCtrl.text);
                } else {
                  Navigator.of(ctx).pop();
                  tts.speak('Acción cancelada');
                }
              },
              localeId: 'es-MX',
              cancelOnError: true,
              partialResults: false, // FIX #3: solo resultado final
              listenMode: stt.ListenMode.search, // FIX #4: mode válido
              pauseFor: const Duration(seconds: 8),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 14),

                  // Encabezado
                  Row(children: [
                    Icon(config['icon'], color: config['color'], size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(config['title'],
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5e3a1c)))),
                    IconButton(
                      icon:
                          const Icon(Icons.volume_up, color: Color(0xFFc99450)),
                      tooltip: 'Releer',
                      onPressed: () => tts.speak(resumen),
                    ),
                  ]),
                  const SizedBox(height: 8),

                  // Texto escuchado
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300)),
                    child: Text('🗣️ Escuché: "$originalText"',
                        style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.black54)),
                  ),
                  const SizedBox(height: 6),

                  // Resumen IA
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFfff8ee),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFc99450).withOpacity(0.4))),
                    child: Row(children: [
                      const Icon(Icons.auto_awesome,
                          color: Color(0xFFc99450), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(resumen,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF5e3a1c)))),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  // ── IDENTIFICADORES ──────────────────────────────────────
                  _field('Nombre del animal', animalCtrl, hint: 'Ej: Lupita'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: _field('Arete / # Oreja', areteCtrl,
                            hint: 'Ej: 1234')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _field('Pierna / Raya', piernaCtrl,
                            hint: 'Ej: 56')),
                  ]),
                  const SizedBox(height: 8),

                  // ── CAMPOS POR ACCIÓN ────────────────────────────────────
                  if (accion == 'crear_animal' ||
                      accion == 'editar_animal') ...[
                    Row(children: [
                      Expanded(child: _razaDropdown(razaCtrl, setModalState)),
                      const SizedBox(width: 8),
                      Expanded(child: _sexoDropdown(sexoCtrl, setModalState)),
                    ]),
                    const SizedBox(height: 8),
                    _propositoDropdown(propCtrl, setModalState),
                    const SizedBox(height: 8),
                    _field('Fecha de nacimiento', nacimientoCtrl,
                        hint: 'dd/MM/yyyy'),
                    const SizedBox(height: 8),
                  ],

                  if (accion == 'registrar_peso') ...[
                    _field('Peso (kg) *', pesoCtrl,
                        keyboardType: TextInputType.number, hint: 'Ej: 480'),
                    const SizedBox(height: 8),
                  ],

                  if (accion == 'registrar_vacuna') ...[
                    _field('Nombre de la vacuna *', vacunaCtrl,
                        hint: 'Ej: Clostridal, IBR, DVB'),
                    const SizedBox(height: 8),
                  ],

                  if (accion == 'registrar_evento') ...[
                    _field('Tipo de evento', eventoCtrl,
                        hint: 'Ej: Parto, Tratamiento, Cita'),
                    const SizedBox(height: 8),
                    if (pesoCtrl.text.isNotEmpty)
                      _field('Peso (kg)', pesoCtrl,
                          keyboardType: TextInputType.number),
                    const SizedBox(height: 8),
                  ],

                  if (accion == 'eliminar_animal') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200)),
                      child: const Row(children: [
                        Icon(Icons.warning_amber, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                            child: Text('Esta acción no se puede deshacer.',
                                style: TextStyle(
                                    color: Colors.red, fontSize: 13))),
                      ]),
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (accion != 'eliminar_animal') ...[
                    _field('Notas adicionales', detallesCtrl,
                        maxLines: 2, hint: 'Observaciones extra...'),
                    const SizedBox(height: 14),
                  ] else
                    const SizedBox(height: 6),

                  // ── CONFIRMAR CON VOZ ────────────────────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isListeningConfirm
                          ? Colors.red.withOpacity(0.07)
                          : const Color(0xFF5e3a1c).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isListeningConfirm
                            ? Colors.red
                            : const Color(0xFF5e3a1c).withOpacity(0.3),
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        isListeningConfirm ? Icons.mic : Icons.mic_none,
                        color: isListeningConfirm
                            ? Colors.red
                            : const Color(0xFF5e3a1c),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isListeningConfirm
                              ? 'Escuchando... di "Confirmar" o "Cancelar"'
                              : 'Toca el mic para confirmar por voz',
                          style: TextStyle(
                            color: isListeningConfirm
                                ? Colors.red
                                : const Color(0xFF5e3a1c),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap:
                            isListeningConfirm ? null : listenForVoiceConfirm,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isListeningConfirm
                                ? Colors.red.withOpacity(0.1)
                                : const Color(0xFF5e3a1c).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isListeningConfirm ? Icons.stop : Icons.mic,
                            color: isListeningConfirm
                                ? Colors.red
                                : const Color(0xFF5e3a1c),
                            size: 20,
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),

                  // ── CONFIRMAR CON BOTÓN (siempre visible y prominente) ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: config['color'],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _ejecutarAccionFirebase(
                            context,
                            accion,
                            animalCtrl.text,
                            areteCtrl.text,
                            piernaCtrl.text,
                            razaCtrl.text,
                            sexoCtrl.text,
                            propCtrl.text,
                            pesoCtrl.text,
                            vacunaCtrl.text,
                            eventoCtrl.text,
                            detallesCtrl.text,
                            nacimientoCtrl.text);
                      },
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: Text(config['buttonText'],
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 4),

                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        tts.speak('Acción cancelada');
                      },
                      child: const Text('Cancelar',
                          style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BÚSQUEDA ROBUSTA MULTI-CAMPO
  // ─────────────────────────────────────────────
  static Future<DocumentSnapshot?> _findAnimal({
    required CollectionReference animalsRef,
    required String name,
    required String arete,
    required String pierna,
  }) async {
    final nameLower = name.trim().toLowerCase();
    final areteClean =
        arete.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').toLowerCase();
    final piernaClean =
        pierna.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').toLowerCase();

    final allDocs = await animalsRef.limit(200).get();
    final docs = allDocs.docs;
    if (docs.isEmpty) return null;

    bool isValidId(String s) =>
        s.isNotEmpty && s != 'sinarete' && s != 'sinpierna' && s != 'n/a';

    // 1. Arete exacto
    if (isValidId(areteClean)) {
      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>;
        final docArete = (data['earTagNumber'] ?? '')
            .toString()
            .replaceAll(RegExp(r'[^0-9a-zA-Z]'), '')
            .toLowerCase();
        if (docArete == areteClean) return d;
      }
    }
    // 2. Pierna exacta
    if (isValidId(piernaClean)) {
      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>;
        final docLeg = (data['legNumber'] ?? '')
            .toString()
            .replaceAll(RegExp(r'[^0-9a-zA-Z]'), '')
            .toLowerCase();
        if (docLeg == piernaClean) return d;
      }
    }
    // 3. Nombre exacto
    if (nameLower.isNotEmpty) {
      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>;
        if ((data['name'] ?? '').toString().toLowerCase() == nameLower)
          return d;
      }
    }
    // 4. Nombre parcial
    if (nameLower.length >= 3) {
      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>;
        final docName = (data['name'] ?? '').toString().toLowerCase();
        if (docName.contains(nameLower) || nameLower.contains(docName))
          return d;
      }
    }
    // 5. Arete parcial
    if (isValidId(areteClean) && areteClean.length >= 2) {
      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>;
        final docArete = (data['earTagNumber'] ?? '')
            .toString()
            .replaceAll(RegExp(r'[^0-9a-zA-Z]'), '')
            .toLowerCase();
        if (docArete.contains(areteClean) || areteClean.contains(docArete))
          return d;
      }
    }
    // 6. Pierna parcial
    if (isValidId(piernaClean) && piernaClean.length >= 1) {
      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>;
        final docLeg = (data['legNumber'] ?? '')
            .toString()
            .replaceAll(RegExp(r'[^0-9a-zA-Z]'), '')
            .toLowerCase();
        if (docLeg.contains(piernaClean) || piernaClean.contains(docLeg))
          return d;
      }
    }
    // 7. Nombre es número → buscar en arete y pierna
    if (RegExp(r'^\d+$').hasMatch(nameLower)) {
      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>;
        final docArete = (data['earTagNumber'] ?? '')
            .toString()
            .replaceAll(RegExp(r'\D'), '');
        final docLeg =
            (data['legNumber'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        if (docArete == nameLower || docLeg == nameLower) return d;
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // EJECUTAR EN FIREBASE
  // ─────────────────────────────────────────────
  static Future<void> _ejecutarAccionFirebase(
    BuildContext context,
    String accion,
    String animalName,
    String arete,
    String pierna,
    String raza,
    String sexo,
    String proposito,
    String peso,
    String vacuna,
    String evento,
    String detalles,
    String fechaNacimiento,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final tts = FlutterTts();
    await tts.setLanguage('es-MX');
    await tts.setSpeechRate(0.48);
    await tts.awaitSpeakCompletion(true);

    if (animalName.isEmpty && arete.isEmpty && pierna.isEmpty) {
      _showSnack(context, 'No se pudo identificar el animal.', Colors.orange);
      await tts.speak('No pude identificar al animal');
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final ranchId = userDoc.data()?['currentRanchId'] as String?;
      if (ranchId == null) {
        _showSnack(context, 'No hay rancho seleccionado.', Colors.orange);
        return;
      }

      final animalsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ranches')
          .doc(ranchId)
          .collection('animals');

      // ── CREAR ──────────────────────────────────────────────────────────
      if (accion == 'crear_animal') {
        final duplicate = await _findAnimal(
            animalsRef: animalsRef,
            name: animalName,
            arete: arete,
            pierna: pierna);
        if (duplicate != null) {
          final dupName = (duplicate.data() as Map<String, dynamic>)['name'] ??
              'sin nombre';
          _showSnack(
              context,
              '⚠️ Ya existe "$dupName". Edítalo en lugar de crear uno nuevo.',
              Colors.orange);
          await tts.speak('Ya existe un animal similar llamado $dupName');
          return;
        }

        DateTime? birthDate;
        if (fechaNacimiento.isNotEmpty) {
          try {
            birthDate = DateFormat('dd/MM/yyyy').parse(fechaNacimiento);
          } catch (_) {
            try {
              birthDate = DateTime.parse(fechaNacimiento);
            } catch (_) {}
          }
        }
        birthDate ??= DateTime.now();

        final sexoDb = _validSex.contains(sexo) ? sexo : 'Hembra';
        final razaDb = _validBreeds.contains(raza) ? raza : 'Otro';
        final propositoDb =
            _validPurposes.contains(proposito) ? proposito : 'Reproductora';

        await animalsRef.add({
          'name':
              _capitalize(animalName.isNotEmpty ? animalName : 'Sin nombre'),
          'earTagNumber': _cleanId(arete),
          'legNumber': _cleanId(pierna),
          'breed': razaDb,
          'sex': sexoDb,
          'purpose': propositoDb,
          'description': detalles.isNotEmpty ? detalles : null,
          'location': 'Sin asignar',
          'imageUrls': [],
          'stats': [],
          'vaccinations': [],
          'isPregnant': false,
          'birthDate': Timestamp.fromDate(birthDate),
          'createdAt': FieldValue.serverTimestamp(),
          if (peso.isNotEmpty && double.tryParse(peso) != null)
            'birthWeight': double.parse(peso),
        });

        _showSnack(context, '✅ Animal "${_capitalize(animalName)}" registrado.',
            Colors.green);
        await tts.speak('Animal registrado correctamente');
        return;
      }

      // ── BUSCAR ANIMAL ────────────────────────────────────────────────────
      final found = await _findAnimal(
          animalsRef: animalsRef,
          name: animalName,
          arete: arete,
          pierna: pierna);

      if (found == null) {
        _showSnack(context, 'No encontré ningún animal con esos datos.',
            Colors.orange);
        await tts.speak('No encontré ningún animal con esos datos');
        return;
      }

      final docRef = animalsRef.doc(found.id);
      final docData = found.data() as Map<String, dynamic>;
      final realName = docData['name']?.toString() ?? animalName;

      switch (accion) {
        case 'eliminar_animal':
          await docRef.delete();
          _showSnack(context, '🗑️ Animal "$realName" eliminado.', Colors.red);
          await tts.speak('Animal eliminado correctamente');
          break;

        case 'editar_animal':
          final updates = <String, dynamic>{};
          if (_validBreeds.contains(raza)) updates['breed'] = raza;
          if (_validSex.contains(sexo)) updates['sex'] = sexo;
          if (_validPurposes.contains(proposito))
            updates['purpose'] = proposito;
          if (arete.isNotEmpty && !arete.toLowerCase().contains('sin'))
            updates['earTagNumber'] = _cleanId(arete);
          if (pierna.isNotEmpty && !pierna.toLowerCase().contains('sin'))
            updates['legNumber'] = _cleanId(pierna);
          if (detalles.isNotEmpty) {
            final cur = docData['description'] as String? ?? '';
            updates['description'] = cur.isEmpty ? detalles : '$cur\n$detalles';
          }
          if (fechaNacimiento.isNotEmpty) {
            try {
              updates['birthDate'] = Timestamp.fromDate(
                  DateFormat('dd/MM/yyyy').parse(fechaNacimiento));
            } catch (_) {}
          }
          if (updates.isNotEmpty) {
            await docRef.update(updates);
            _showSnack(
                context, '✅ Animal "$realName" actualizado.', Colors.green);
            await tts.speak('Animal actualizado correctamente');
          }
          break;

        case 'registrar_peso':
          final pesoVal = double.tryParse(peso.replaceAll(',', '.'));
          if (pesoVal == null || pesoVal <= 0) {
            _showSnack(context, 'El peso "$peso" no es válido.', Colors.orange);
            await tts.speak('El peso no es válido');
            return;
          }
          await docRef.update({
            'stats': FieldValue.arrayUnion([
              {
                'date': Timestamp.now(),
                'value': pesoVal,
                'label':
                    'Peso ${DateFormat('dd/MM/yy').format(DateTime.now())}',
              }
            ])
          });
          _showSnack(context, '✅ ${pesoVal}kg registrado para "$realName".',
              Colors.green);
          await tts.speak(
              'Peso de ${pesoVal.toStringAsFixed(0)} kilos registrado para $realName');
          break;

        case 'registrar_vacuna':
          final vName = vacuna.isNotEmpty
              ? _capitalize(vacuna)
              : evento.isNotEmpty
                  ? _capitalize(evento)
                  : '';
          if (vName.isEmpty) {
            _showSnack(
                context, 'Especifica el nombre de la vacuna.', Colors.orange);
            await tts.speak('Necesito saber el nombre de la vacuna');
            return;
          }
          await docRef.update({
            'vaccinations': FieldValue.arrayUnion([
              {'name': vName, 'date': Timestamp.now()}
            ])
          });
          _showSnack(context, '✅ Vacuna "$vName" registrada para "$realName".',
              Colors.green);
          await tts.speak('Vacuna $vName registrada para $realName');
          break;

        case 'registrar_evento':
        default:
          if (peso.isNotEmpty) {
            final pesoVal = double.tryParse(peso.replaceAll(',', '.'));
            if (pesoVal != null && pesoVal > 0) {
              await docRef.update({
                'stats': FieldValue.arrayUnion([
                  {
                    'date': Timestamp.now(),
                    'value': pesoVal,
                    'label': evento.isNotEmpty ? evento : 'Registro voz',
                  }
                ])
              });
            }
          }
          final partes = <String>[
            if (evento.isNotEmpty) evento,
            if (detalles.isNotEmpty) detalles,
          ];
          if (partes.isNotEmpty) {
            final nota = partes.join(': ');
            final fechaStr = DateFormat('dd/MM/yy').format(DateTime.now());
            final cur = docData['description'] as String? ?? '';
            await docRef.update({
              'description':
                  cur.isEmpty ? '$fechaStr: $nota' : '$cur\n$fechaStr: $nota',
            });
          }
          _showSnack(
              context, '✅ Evento registrado para "$realName".', Colors.green);
          await tts.speak('Evento guardado');
          break;
      }
    } catch (e) {
      _showSnack(context, 'Error en base de datos: $e', Colors.red);
    }
  }

  // ─────────────────────────────────────────────
  // UTILIDADES
  // ─────────────────────────────────────────────
  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  static String _cleanId(String val) {
    final lower = val.toLowerCase().trim();
    if (lower.isEmpty ||
        lower == 'n/a' ||
        lower.contains('sin') ||
        lower == 'null') return 'N/A';
    return val.trim();
  }

  static String _cleanIdField(String val) {
    final lower = val.toLowerCase().trim();
    if (lower.isEmpty ||
        lower == 'n/a' ||
        lower.contains('sin') ||
        lower == 'null') return '';
    return val.trim();
  }

  static String _cleanDateField(String val) {
    final lower = val.toLowerCase().trim();
    if (lower.isEmpty ||
        lower.contains('no ') ||
        lower == 'null' ||
        lower == 'no proporcionado') return '';
    return val.trim();
  }

  // ─────────────────────────────────────────────
  // WIDGETS UI
  // ─────────────────────────────────────────────
  static Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboardType, int maxLines = 1, String? hint}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }

  static Widget _sexoDropdown(TextEditingController ctrl, StateSetter set) {
    final currentVal = _validSex.contains(ctrl.text) ? ctrl.text : '';
    return DropdownButtonFormField<String>(
      value: currentVal,
      decoration: const InputDecoration(
          labelText: 'Sexo',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true),
      items: [
        const DropdownMenuItem(value: '', child: Text('Sin especificar')),
        ..._validSex.map((s) => DropdownMenuItem(value: s, child: Text(s))),
      ],
      onChanged: (val) => set(() => ctrl.text = val ?? ''),
    );
  }

  static Widget _propositoDropdown(
      TextEditingController ctrl, StateSetter set) {
    final currentVal =
        _validPurposes.contains(ctrl.text) ? ctrl.text : _validPurposes.first;
    return DropdownButtonFormField<String>(
      value: currentVal,
      decoration: const InputDecoration(
          labelText: 'Propósito',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true),
      items: _validPurposes
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (val) => set(() => ctrl.text = val ?? _validPurposes.first),
    );
  }

  static Widget _razaDropdown(TextEditingController ctrl, StateSetter set) {
    final currentVal = _validBreeds.contains(ctrl.text) ? ctrl.text : 'Otro';
    return DropdownButtonFormField<String>(
      value: currentVal,
      decoration: const InputDecoration(
          labelText: 'Raza',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true),
      items: _validBreeds
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (val) => set(() => ctrl.text = val ?? 'Otro'),
    );
  }

  static Map<String, dynamic> _actionConfig(String accion) {
    switch (accion) {
      case 'crear_animal':
        return {
          'title': 'Nuevo Animal',
          'icon': Icons.add_circle,
          'color': const Color(0xFFc99450),
          'buttonText': 'Registrar Animal'
        };
      case 'eliminar_animal':
        return {
          'title': 'Eliminar Animal',
          'icon': Icons.delete_forever,
          'color': Colors.red,
          'buttonText': 'Confirmar Eliminación'
        };
      case 'editar_animal':
        return {
          'title': 'Editar Animal',
          'icon': Icons.edit,
          'color': const Color(0xFF5e3a1c),
          'buttonText': 'Guardar Cambios'
        };
      case 'registrar_peso':
        return {
          'title': 'Registrar Peso',
          'icon': Icons.monitor_weight,
          'color': Colors.teal,
          'buttonText': 'Registrar Peso'
        };
      case 'registrar_vacuna':
        return {
          'title': 'Registrar Vacuna',
          'icon': Icons.vaccines,
          'color': Colors.indigo,
          'buttonText': 'Registrar Vacuna'
        };
      default:
        return {
          'title': 'Registrar Evento',
          'icon': Icons.event_note,
          'color': const Color(0xFF5e3a1c),
          'buttonText': 'Guardar Evento'
        };
    }
  }

  static void _showSnack(BuildContext context, String msg, Color color) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: color,
          duration: const Duration(seconds: 4)),
    );
  }
}
