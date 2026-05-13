// lib/widgets/live_voice_dialog.dart

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:manual_ganadero_flutter/services/ai_voice_service.dart';
import 'package:manual_ganadero_flutter/widgets/voice_action_dialog.dart';

enum VoiceState { waitingWakeWord, listening, processing, confirming }

class LiveVoiceDialog extends StatefulWidget {
  const LiveVoiceDialog({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => const LiveVoiceDialog(),
    );
  }

  @override
  State<LiveVoiceDialog> createState() => _LiveVoiceDialogState();
}

class _LiveVoiceDialogState extends State<LiveVoiceDialog>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  VoiceState _state = VoiceState.waitingWakeWord;
  String _displayText = 'Di "Oye Rancho" para comenzar';
  String _transcribedCommand = '';
  Map<String, dynamic>? _pendingData;

  // ── FIX #2 y #5: flags para evitar procesamiento doble y cancelaciones prematuras ──
  bool _hasProcessedCommand = false;
  bool _isConfirmationActive = false;
  bool _isTransitioning =
      false; // Evita que _onSpeechStatus actúe durante transiciones

  static const String _wakeWord = 'oye rancho';
  static const Color _brown = Color(0xFF5e3a1c);
  static const Color _gold = Color(0xFFc99450);

  // ── Palabras clave ampliadas para mejor reconocimiento ──
  static const _confirmWords = [
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
    'correcto',
    'exacto',
    'perfecto',
    'listo',
    'va',
  ];
  static const _cancelWords = [
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

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();

    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _initTts().then((_) => _startListeningForWakeWord());
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('es-MX');
    await _tts.setSpeechRate(0.48);
    // FIX #1: awaitSpeakCompletion garantiza que el TTS termina ANTES de activar el mic
    await _tts.awaitSpeakCompletion(true);
  }

  Future<void> _speak(String text) async {
    // FIX #1: Detener cualquier escucha activa ANTES de hablar
    await _speech.stop();
    await _tts.speak(text);
    // FIX #1: Pausa después de TTS para que el eco se disipe antes de escuchar
    await Future.delayed(const Duration(milliseconds: 600));
  }

  void _startListeningForWakeWord() async {
    if (!mounted) return;

    final available = await _speech.initialize(onStatus: _onSpeechStatus);
    if (!available || !mounted) return;

    setState(() {
      _state = VoiceState.waitingWakeWord;
      _displayText = 'Di "Oye Rancho" para comenzar';
      _hasProcessedCommand = false;
      _isConfirmationActive = false;
    });

    _speech.listen(
      onResult: (result) {
        if (result.recognizedWords.toLowerCase().contains(_wakeWord)) {
          _onWakeWordDetected();
        }
      },
      localeId: 'es-MX',
      listenMode: stt.ListenMode.search,
      partialResults: true,
    );
  }

  Future<void> _onWakeWordDetected() async {
    // Evitar activación doble
    if (_state != VoiceState.waitingWakeWord) return;

    _isTransitioning =
        true; // FIX #2: bloquear _onSpeechStatus durante la transición
    await _speech.stop();
    if (!mounted) return;

    setState(() {
      _state = VoiceState.listening;
      _displayText = 'Te escucho, ¿qué quieres hacer?';
      _transcribedCommand = '';
      _hasProcessedCommand = false;
    });

    await _speak('Te escucho');
    if (!mounted) return;
    _isTransitioning = false;

    _speech.listen(
      onResult: (result) {
        if (!mounted) return;

        setState(() => _displayText = result.recognizedWords);
        _transcribedCommand = result.recognizedWords;

        // FIX #5: flag para evitar doble procesamiento
        if (result.finalResult &&
            _transcribedCommand.isNotEmpty &&
            !_hasProcessedCommand) {
          _hasProcessedCommand = true;
          _processCommand();
        }
      },
      localeId: 'es-MX',
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      pauseFor: const Duration(seconds: 4),
    );
  }

  Future<void> _processCommand() async {
    await _speech.stop();
    if (!mounted) return;

    setState(() {
      _state = VoiceState.processing;
      _displayText = 'Analizando tu instrucción...';
    });

    final data = await AIVoiceService.processCommand(_transcribedCommand);
    if (!mounted) return;

    if (data == null) {
      await _speak('No pude entender la instrucción, intenta de nuevo.');
      if (mounted) Navigator.of(context).pop();
      return;
    }

    _pendingData = data;
    await _askForConfirmation();
  }

  Future<void> _askForConfirmation() async {
    if (!mounted || _pendingData == null) return;
    final resumen = _pendingData!['resumen_confirmacion']?.toString() ??
        'Confirma los datos';

    _isTransitioning = true; // FIX #2: bloquear status handler durante TTS
    setState(() {
      _state = VoiceState.confirming;
      _displayText = '$resumen\n\n¿Confirmas? Di "sí" o "no"';
    });

    await _speak('$resumen. ¿Confirmas?');
    if (!mounted) return;

    _isConfirmationActive = true;
    _isTransitioning = false;

    // FIX #3 y #4: partialResults: false + listenMode: search (confirmation no existe en el paquete)
    _speech.listen(
      onResult: (result) async {
        if (!mounted || !_isConfirmationActive) return;

        // FIX #3: Esperar resultado final, no parciales
        if (!result.finalResult) return;

        final words = result.recognizedWords.toLowerCase().trim();
        if (words.isEmpty) return;

        final confirmed = _confirmWords.any((w) => words.contains(w));
        final cancelled = _cancelWords.any((w) => words.contains(w));

        if (!confirmed && !cancelled) return; // Ignorar si no es claro

        _isConfirmationActive = false;
        await _speech.stop();

        if (confirmed) {
          await _speak('Guardando información.');
          if (!mounted) return;
          Navigator.of(context).pop();
          await VoiceActionDialog.showConfirmationModal(
              context, _pendingData!, _transcribedCommand,
              autoExecute: true);
        } else {
          await _speak('Cancelado.');
          if (mounted) Navigator.of(context).pop();
        }
      },
      localeId: 'es-MX',
      listenMode: stt.ListenMode
          .search, // FIX #4: search en lugar del inexistente confirmation
      partialResults: false, // FIX #3: solo resultado final
      pauseFor: const Duration(seconds: 10),
    );
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;

    // FIX #2: No actuar durante transiciones TTS→STT
    if (_isTransitioning) return;

    if (status == 'done' || status == 'notListening') {
      if (_state == VoiceState.waitingWakeWord) {
        Future.delayed(const Duration(seconds: 1), _startListeningForWakeWord);
      } else if (_state == VoiceState.listening) {
        // FIX #5: Solo procesar si no se ha hecho ya
        if (_transcribedCommand.isNotEmpty && !_hasProcessedCommand) {
          _hasProcessedCommand = true;
          _processCommand();
        } else if (_transcribedCommand.isEmpty) {
          _speak('No escuché nada. Intenta de nuevo.');
          if (mounted) Navigator.of(context).pop();
        }
        // Si ya procesó (_hasProcessedCommand = true), no hace nada
      } else if (_state == VoiceState.confirming && !_isConfirmationActive) {
        // FIX #2: Solo cancelar si la confirmación ya no está activa
        _speak('Tiempo agotado. Cancelando.');
        if (mounted) Navigator.of(context).pop();
      }
      // Si _isConfirmationActive == true, ignorar: el listener sigue esperando
    }
  }

  void _forceStartListening() async {
    _isTransitioning = true;
    await _speech.stop();
    _isTransitioning = false;
    _onWakeWordDetected();
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.52,
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(
              _state == VoiceState.confirming
                  ? '¿Confirmas?'
                  : 'Asistente de Voz',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _brown)),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (ctx, child) => Transform.scale(
                scale: _state == VoiceState.processing
                    ? 1.0
                    : _pulseAnimation.value,
                child: child),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (_state == VoiceState.processing ? _gold : Colors.red)
                      .withOpacity(0.12),
                  border: Border.all(
                      color:
                          _state == VoiceState.processing ? _gold : Colors.red,
                      width: 2.5)),
              child: _state == VoiceState.processing
                  ? const Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: _gold))
                  : const Icon(Icons.mic, color: Colors.red, size: 40),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
              child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200)),
                  child: SingleChildScrollView(
                      child: Text(_displayText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: _state == VoiceState.waitingWakeWord
                                  ? Colors.grey
                                  : Colors.black87,
                              fontStyle: _state == VoiceState.waitingWakeWord
                                  ? FontStyle.italic
                                  : FontStyle.normal))))),
          const SizedBox(height: 16),

          // ── FIX EXTRA: Botones de confirmación visual cuando está en modo confirmar ──
          if (_state == VoiceState.confirming)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Confirmar',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        _isConfirmationActive = false;
                        await _speech.stop();
                        await _speak('Guardando información.');
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        await VoiceActionDialog.showConfirmationModal(
                            context, _pendingData!, _transcribedCommand,
                            autoExecute: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        _isConfirmationActive = false;
                        await _speech.stop();
                        await _speak('Cancelado.');
                        if (mounted) Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                    onPressed: () {
                      _speech.stop();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancelar')),
                if (_state != VoiceState.processing)
                  FloatingActionButton(
                      heroTag: 'voice_fab',
                      backgroundColor:
                          _state == VoiceState.listening ? Colors.red : _gold,
                      onPressed: _state == VoiceState.listening
                          ? () async {
                              if (!_hasProcessedCommand) {
                                _hasProcessedCommand = true;
                                await _speech.stop();
                                _processCommand();
                              }
                            }
                          : _forceStartListening,
                      child: const Icon(Icons.mic, color: Colors.white)),
              ],
            ),
        ],
      ),
    );
  }
}
