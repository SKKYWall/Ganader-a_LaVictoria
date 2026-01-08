// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manual Ganadero',
      theme: ThemeData(primarySwatch: Colors.brown),
      home: const LoginScreen(), // Set your initial screen here
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
      },
    );
  }
}
