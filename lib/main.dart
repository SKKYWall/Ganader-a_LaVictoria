// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Importaciones de Auth
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:manual_ganadero_flutter/screens/principal/login_screen.dart';
import 'package:manual_ganadero_flutter/screens/principal/register_screen.dart';
import 'package:manual_ganadero_flutter/screens/principal/dashboard_screen.dart';
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
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('es_MX', null);
  runApp(const MyApp());
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
      // Este stream sabe mágicamente si el usuario cerró la app sin desloguearse
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Mientras revisa a Firebase, mostramos un loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFfbf6ec),
            body: Center(
                child: CircularProgressIndicator(color: Color(0xFF6b4226))),
          );
        }

        // 2. Si el usuario SÍ tiene sesión activa en la memoria del celular
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          final lastSignIn = user.metadata.lastSignInTime;

          // REGLA DE EXPIRACIÓN: 7 Días
          // (Si quieres probarlo, cambia .inDays >= 7 por .inMinutes >= 1)
          if (lastSignIn != null &&
              DateTime.now().difference(lastSignIn).inDays >= 7) {
            // Cerramos sesión en segundo plano sin romper la pantalla
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
            // Lo regresamos al Login
            return const LoginScreen();
          }

          // Si la sesión es válida (no han pasado los 7 días), ¡pásale directo al Dashboard!
          // Si la sesión es válida (no han pasado los 7 días), verificamos si ya configuró su rancho
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    backgroundColor: Color(0xFFfbf6ec),
                    body: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFc99450))));
              }

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                Map<String, dynamic>? data =
                    userSnapshot.data!.data() as Map<String, dynamic>?;

                // Si ya completó la configuración, va al Dashboard
                if (data != null && data['setupCompleted'] == true) {
                  return const DashboardScreen();
                } else {
                  // Si NO la ha completado, lo obligamos a pasar por la configuración
                  return const RanchSetupScreen();
                }
              }

              // Si el documento no existe (ej. un usuario totalmente nuevo que entró con Google)
              return const RanchSetupScreen();
            },
          );
        }

        // 3. Si no hay sesión iniciada en lo absoluto, mostrar Login
        return const LoginScreen();
      },
    );
  }
}
