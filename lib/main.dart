// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Importaciones de Auth
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:manual_ganadero_flutter/screens/principal/login_screen.dart';
import 'package:manual_ganadero_flutter/screens/principal/register_screen.dart';
import 'package:manual_ganadero_flutter/screens/principal/dashboard_screen.dart';
import 'package:manual_ganadero_flutter/screens/principal/tutorial_screen.dart';
import 'package:manual_ganadero_flutter/screens/bovino/register_animal_screen.dart';
import 'package:manual_ganadero_flutter/screens/bovino/animal_detail_screen.dart';
import 'package:manual_ganadero_flutter/screens/bovino/edit_animal_screen.dart';
import 'package:manual_ganadero_flutter/screens/profile/profile_screen.dart';
import 'package:manual_ganadero_flutter/screens/inventario/inventory_screen.dart';
import 'package:manual_ganadero_flutter/screens/finance/finance_screen.dart';
// Importaciones para Marketplace
import 'package:manual_ganadero_flutter/screens/marketplace/marketplace_screen.dart';
import 'package:manual_ganadero_flutter/screens/marketplace/select_animal_to_publish_screen.dart';
import 'package:manual_ganadero_flutter/screens/marketplace/marketplace_product_detail_screen.dart';
// Importación para la pantalla de IA
import 'package:manual_ganadero_flutter/screens/intelligence/intelligence_screen.dart';
import 'package:manual_ganadero_flutter/screens/calendar/calendar_screen.dart'; // Asegúrate de importar CalendarScreen
import 'package:manual_ganadero_flutter/screens/estadisticas/estadisticas_screen.dart'; // ¡IMPORTACIÓN DE LA PANTALLA DE ESTADÍSTICAS!
import 'package:manual_ganadero_flutter/screens/profile/notification_settings_screen.dart';
import 'package:manual_ganadero_flutter/screens/noticias/in_app_notification_screen.dart'; // ¡IMPORTACIÓN NECESARIA!
import 'package:manual_ganadero_flutter/screens/noticias/news_screen.dart'; // ¡IMPORTACIÓN NECESARIA!

import 'package:manual_ganadero_flutter/screens/modulos/leche_screen.dart';
import 'package:manual_ganadero_flutter/screens/modulos/reportes_screen.dart';
import 'package:manual_ganadero_flutter/screens/modulos/genetica_screen.dart';
import 'package:manual_ganadero_flutter/screens/modulos/engorda_screen.dart';
import 'package:manual_ganadero_flutter/screens/modulos/reproductora_screen.dart';
import 'package:manual_ganadero_flutter/screens/modulos/sanidad_screen.dart'; // <-- Agrega esta línea
import 'package:intl/date_symbol_data_local.dart';
import 'package:manual_ganadero_flutter/screens/profile/ranch_setup_screen.dart';
import 'package:manual_ganadero_flutter/screens/profile/terms_acceptance_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:manual_ganadero_flutter/services/notification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  // runZonedGuarded atrapa CUALQUIER error asíncrono no controlado para que
  // la app nunca se cierre sola por una excepción suelta en el arranque.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Atrapa errores del framework de Flutter (no tumba la app).
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('⚠️ FlutterError: ${details.exceptionAsString()}');
    };

    // --- Inicializaciones protegidas ---
    // Cada paso va en su propio try/catch: si UNO falla, la app igual arranca
    // en lugar de quedarse congelada en el splash y luego cerrarse.
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      debugPrint('⚠️ No se pudo cargar .env: $e');
    }

    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);

      // Persistencia offline: la app funciona completa sin señal y sincroniza
      // automáticamente al reconectar. Caché ilimitada para ranchos grandes.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('⚠️ Error al inicializar Firebase: $e');
    }

    try {
      await initializeDateFormatting('es_MX', null);
    } catch (e) {
      debugPrint('⚠️ Error al inicializar formato de fechas: $e');
    }

    // Arranca la UI de inmediato. NO esperamos a las notificaciones aquí
    // porque su init carga toda la base de zonas horarias y bloquea el arranque.
    runApp(const MyApp());

    // Notificaciones: se inicializan DESPUÉS de mostrar la UI, sin bloquear.
    unawaited(_initNotificationsSafe());
  }, (error, stack) {
    debugPrint('⛔ Error no controlado: $error');
  });
}

// Inicializa el servicio de notificaciones de forma segura y diferida.
Future<void> _initNotificationsSafe() async {
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('⚠️ Error al inicializar notificaciones: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manual Ganadero',
      theme: ThemeData(primarySwatch: Colors.brown),

      home: const AuthCheck(), // Set your initial screen here
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/tutorial': (context) => const TutorialScreen(),
        '/registerAnimal': (context) => const RegisterAnimalScreen(),
        '/animalDetail': (context) =>
            const AnimalDetailScreen(animalId: ''), // You'll likely pass the ID
        '/editAnimal': (context) =>
            const EditAnimalScreen(animalId: ''), // You'll likely pass the ID
        '/profile': (context) => const ProfileScreen(),
        '/inventory': (context) => const InventoryScreen(),
        '/finance': (context) => const FinanceScreen(),
        '/calendar': (context) =>
            const CalendarScreen(), // Asegúrate de que esta ruta exista
        // Rutas del Marketplace
        '/leche': (context) => const LecheScreen(),
        '/reportes': (context) => const ReportesScreen(),
        '/genetica': (context) => const GeneticaScreen(),
        '/engorda': (context) => const EngordaScreen(),
        '/reproductora': (context) => const ReproductoraScreen(),
        '/marketplace': (context) => const MarketplaceScreen(),
        '/selectAnimalToPublish': (context) =>
            const SelectAnimalToPublishScreen(),
        '/marketplaceProductDetail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          // Ahora solo pasamos el 'listingId', ya que la pantalla de detalles
          // carga toda la información necesaria directamente desde el listado.
          return MarketplaceProductDetailScreen(
            listingId: args['listingId'],
          );
        },
        // Ruta para la pantalla de IA
        '/intelligence': (context) => const IntelligenceScreen(),
        '/estadisticas': (context) =>
            const EstadisticasScreen(), // ¡NUEVA RUTA para Estadísticas!
        '/notificationSettings': (context) =>
            const NotificationSettingsScreen(),
        '/inAppNotifications': (context) =>
            const InAppNotificationScreen(), // ¡RUTA NECESARIA!
        '/newsScreen': (context) => const NewsScreen(), // ¡RUTA NECESARIA!
        '/sanidadScreen': (context) => const SanidadScreen(),
      },
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFfbf6ec),
            body: Center(
                child: CircularProgressIndicator(color: Color(0xFF6b4226))),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          final lastSignIn = user.metadata.lastSignInTime;

          if (lastSignIn != null &&
              DateTime.now().difference(lastSignIn).inDays >= 7) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Tu sesión ha expirado por seguridad. Inicia sesión nuevamente.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            });
            return const LoginScreen();
          }

          // _UserRouter cachea el Future en initState para que authStateChanges()
          // no relance la lectura de Firestore en cada rebuild.
          return _UserRouter(uid: user.uid);
        }

        return const LoginScreen();
      },
    );
  }
}

// Widget separado para que el Future de Firestore se cree UNA sola vez
// en initState y no se repita con cada rebuild del StreamBuilder padre.
class _UserRouter extends StatefulWidget {
  final String uid;
  const _UserRouter({required this.uid});

  @override
  State<_UserRouter> createState() => _UserRouterState();
}

class _UserRouterState extends State<_UserRouter> {
  late final Future<DocumentSnapshot> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _userFuture,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              backgroundColor: Color(0xFFfbf6ec),
              body: Center(
                  child:
                      CircularProgressIndicator(color: Color(0xFFc99450))));
        }

        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final data =
              userSnapshot.data!.data() as Map<String, dynamic>?;

          if (data != null && data['setupCompleted'] == true) {
            if (data['termsAccepted'] != true) {
              return TermsAcceptanceScreen(
                onAccepted: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const DashboardScreen()),
                    (_) => false),
              );
            }
            return const DashboardScreen();
          } else {
            return const RanchSetupScreen();
          }
        }

        return const RanchSetupScreen();
      },
    );
  }
}
