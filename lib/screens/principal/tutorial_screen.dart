// lib/screens/principal/tutorial_screen.dart
//
// Tutorial de bienvenida (onboarding). Se muestra automáticamente la primera
// vez que el usuario entra al dashboard, y se puede volver a ver desde Ayuda.
// Marca `tutorialSeen: true` en el documento del usuario para no repetirlo.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class _TutorialStep {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  const _TutorialStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const Color _brown = Color(0xFF5e3a1c);
  static const Color _gold = Color(0xFFc99450);
  static const Color _cream = Color(0xFFfbf6ec);

  final List<_TutorialStep> _steps = const [
    _TutorialStep(
      icon: FontAwesomeIcons.cow,
      color: _brown,
      title: 'Bienvenido a Manual Ganadero',
      description:
          'Te mostramos lo básico en menos de un minuto. Puedes saltarlo cuando quieras.',
    ),
    _TutorialStep(
      icon: FontAwesomeIcons.houseChimney,
      color: _gold,
      title: '1. Elige tu rancho',
      description:
          'Arriba en el inicio puedes cambiar entre tus ranchos. Todo lo que registres se guarda en el rancho que tengas activo.',
    ),
    _TutorialStep(
      icon: Icons.add_circle,
      color: Colors.green,
      title: '2. Registra un animal',
      description:
          'Entra a "Bovino", toca el botón +, llena los datos y presiona Guardar. ¡Listo, ya quedó en tu hato!',
    ),
    _TutorialStep(
      icon: Icons.lock_open,
      color: Colors.teal,
      title: '3. Se desbloquean módulos',
      description:
          'Según el propósito de tus animales (Leche, Engorda, Genética...) se activan los módulos correspondientes en la pantalla de inicio.',
    ),
    _TutorialStep(
      icon: Icons.mic,
      color: Colors.red,
      title: '4. Registra hablando',
      description:
          'En "Bovino" toca el micrófono y di "Oye Rancho". Puedes registrar y consultar usando tu voz (función Beta, en mejora continua).',
    ),
    _TutorialStep(
      icon: Icons.calendar_month,
      color: Colors.indigo,
      title: '5. Calendario y recordatorios',
      description:
          'Agenda vacunas, partos y tareas. La app te enviará notificaciones para que no se te pase nada importante.',
    ),
    _TutorialStep(
      icon: Icons.check_circle,
      color: Colors.green,
      title: '¡Todo listo!',
      description:
          'Explora con confianza. Puedes volver a ver este tutorial cuando quieras desde Ayuda, en tu perfil.',
    ),
  ];

  Future<void> _finish() async {
    // Marca el tutorial como visto para no volver a mostrarlo en cada inicio.
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'tutorialSeen': true}, SetOptions(merge: true));
      }
    } catch (_) {
      // Si falla (sin conexión), no pasa nada: se intentará marcar la próxima vez.
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLast = _index == _steps.length - 1;

    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Column(
          children: [
            // Botón "Saltar" (se oculta en el último paso).
            Align(
              alignment: Alignment.topRight,
              child: isLast
                  ? const SizedBox(height: 48)
                  : TextButton(
                      onPressed: _finish,
                      child: const Text('Saltar',
                          style: TextStyle(
                              color: _brown, fontWeight: FontWeight.bold)),
                    ),
            ),

            // Contenido de los pasos.
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final s = _steps[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: s.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s.icon, size: 60, color: s.color),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _brown),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Indicadores de página (puntitos).
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? _gold : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botón principal: Siguiente / Empezar.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brown,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    if (isLast) {
                      _finish();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Text(
                    isLast ? 'Empezar a usar la app' : 'Siguiente',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
