import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:manual_ganadero_flutter/screens/bovino/bovino_screen.dart';
import 'package:manual_ganadero_flutter/screens/profile/profile_screen.dart';
import 'package:manual_ganadero_flutter/screens/inventario/inventory_screen.dart';
import 'package:manual_ganadero_flutter/screens/finance/finance_screen.dart';
import 'package:manual_ganadero_flutter/screens/calendar/calendar_screen.dart';
import 'package:manual_ganadero_flutter/screens/marketplace/marketplace_screen.dart';
import 'package:manual_ganadero_flutter/screens/intelligence/intelligence_screen.dart';
import 'package:manual_ganadero_flutter/screens/estadisticas/estadisticas_screen.dart';
//import 'package:manual_ganadero_flutter/screens/noticias/in_app_notification_screen.dart'; // Importa la pantalla de notificaciones in-app
//import 'package:manual_ganadero_flutter/screens/noticias/news_screen.dart'; // Importa la nueva pantalla de noticias

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  User? _user;
  bool _isLoading = true;
  String? _errorMessage;

  // Colores distintivos para cada módulo
  final Color _bovinoColor = const Color(0xFF8B4513); // Marrón para Bovino
  final Color _calendarioColor =
      const Color(0xFFE53935); // Rojo para Calendario
  final Color _inventarioColor =
      const Color.fromARGB(255, 49, 49, 154); // Azul oscuro para Inventario
  final Color _finanzasColor = const Color(0xFF4CAF50); // Verde para Finanzas
  final Color _textoColor =
      const Color.fromARGB(255, 0, 0, 0); // Color de texto principal

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      _user = FirebaseAuth.instance.currentUser;
      if (_user == null) {
        // If no user is logged in, redirect to login
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      if (userDoc.exists) {
        // You can load more user data here if you have it in Firestore
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading user data: $e';
      });
      print('Error loading user data: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFfbf6ec),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6b4226)),
          ),
        ),
      );
    }

    if (_user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFfbf6ec),
        body: Center(
          child: Text(
            'User not authenticated. Redirecting...',
            style: TextStyle(color: Color(0xFF5e3a1c)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        backgroundColor: const Color(0xFFfbf6ec),
        elevation: 0,
        // --- Botón de Noticias (leading - izquierda) ---
        leading: IconButton(
          icon: const Icon(Icons.newspaper, color: Color(0xFF5e3a1c)),
          onPressed: () {
            // Asegúrate de que esta ruta esté definida en tu main.dart
            Navigator.of(context)
                .pushNamed('/newsScreen'); // Navegar a la pantalla de noticias
          },
          tooltip: 'Noticias y Novedades',
        ),
        // Título vacío
        title: const SizedBox.shrink(),
        centerTitle: true,
        actions: [
          // --- Campanita de Notificaciones (acciones - derecha) ---
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_user!.uid)
                .collection('inAppNotifications')
                .where('read', isEqualTo: false) // Filtrar por no leídas
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return IconButton(
                  icon: const Icon(Icons.notifications_none,
                      color: Color(0xFF5e3a1c)),
                  onPressed: () {
                    // Asegúrate de que esta ruta esté definida en tu main.dart
                    Navigator.of(context).pushNamed('/inAppNotifications');
                  },
                );
              }
              if (snapshot.hasError) {
                print('Error loading unread notifications: ${snapshot.error}');
                return IconButton(
                  icon: const Icon(Icons.notifications_off, color: Colors.red),
                  onPressed: () {
                    // Asegúrate de que esta ruta esté definida en tu main.dart
                    Navigator.of(context).pushNamed('/inAppNotifications');
                  },
                );
              }

              final unreadCount = snapshot.data?.docs.length ?? 0;

              return Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      unreadCount > 0
                          ? Icons.notifications_active // Campana con algo
                          : Icons.notifications_none, // Campana vacía
                      color: const Color(0xFF5e3a1c),
                    ),
                    onPressed: () {
                      // Asegúrate de que esta ruta esté definida en tu main.dart
                      Navigator.of(context).pushNamed('/inAppNotifications');
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8, // Ajusta la posición para que no se superponga
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white, width: 1.5), // Borde blanco
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18, // Tamaño mínimo para el círculo
                          minHeight: 18,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10, // Tamaño de fuente para el número
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                ],
              );
            },
          ),
          // --- Fin Campanita de Notificaciones ---

          // Avatar del Perfil (ya existente)
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const ProfileScreen()),
                );
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFc99450),
                backgroundImage: _user?.photoURL != null
                    ? NetworkImage(_user!.photoURL!)
                    : null,
                child: _user?.photoURL == null
                    ? const Icon(Icons.person, color: Colors.white, size: 24)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics Section (NOW NAVIGATES TO EstadisticasScreen)
            _buildChartModule(
              title: 'Estadísticas', // Changed to 'Estadísticas' for generality
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          const EstadisticasScreen()), // Navigation to EstadisticasScreen
                );
              },
              chartWidget:
                  _buildLineChartExample(), // Keeps the visual example on the dashboard
              legendItems: [
                {'color': const Color(0xFFa75c2e), 'text': 'Exceptor'},
                {'color': const Color(0xFF673ab7), 'text': 'Ipsum oc'},
              ],
            ),
            const SizedBox(height: 20),

            // 2-column Modules (Bovino, Calendar) - Unified with colors
            Row(
              children: [
                Expanded(
                  child: _buildModuleCard(
                    title: 'Bovino', // Title for the Bovine module
                    onTap: () {
                      // NAVIGATION TO BOVINOSCREEN!
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const BovinoScreen()),
                      );
                    },
                    children: [
                      // Using FontAwesomeIcons.cow to be more specific
                      Icon(FontAwesomeIcons.cow, size: 60, color: _bovinoColor),
                      const SizedBox(height: 10),
                      Text(
                        'Manage your bovines and animals.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _textoColor,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildModuleCard(
                    title: 'Calendario',
                    onTap: () {
                      // CHANGE HERE! NAVIGATION TO CALENDARSCREEN
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const CalendarScreen()),
                      );
                    },
                    children: [
                      Icon(Icons.calendar_month,
                          size: 60, color: _calendarioColor),
                      const SizedBox(height: 10),
                      Text(
                        'Schedule events and reminders.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _textoColor,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // 2-column Modules (Inventory, Finance) - Unified with colors
            Row(
              children: [
                Expanded(
                  child: _buildModuleCard(
                    title: 'Inventario',
                    onTap: () {
                      // CHANGE HERE! NAVIGATION TO INVENTORYSCREEN
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const InventoryScreen()),
                      );
                    },
                    children: [
                      Icon(Icons.inventory, size: 60, color: _inventarioColor),
                      const SizedBox(height: 10),
                      Text(
                        'Control your supplies.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _textoColor,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildModuleCard(
                    title: 'Finanzas',
                    onTap: () {
                      // CHANGE HERE! NAVIGATION TO FINANCE_SCREEN
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const FinanceScreen()),
                      );
                    },
                    children: [
                      Icon(Icons.monetization_on,
                          size: 60, color: _finanzasColor),
                      const SizedBox(height: 10),
                      Text(
                        'Manage income and expenses.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _textoColor,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Large action buttons modified
            _buildLargeActionButton(
              text: 'AI Analysis for Animals', // Modified text
              icon: FontAwesomeIcons.brain, // AI icon (brain)
              backgroundColor: const Color(0xFF9C27B0), // Purple color
              onTap: () {
                // NEW NAVIGATION! To IntelligenceScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const IntelligenceScreen()),
                );
              },
            ),
            const SizedBox(height: 15),
            _buildLargeActionButton(
              text: 'Livestock Marketplace', // Modified text
              icon: FontAwesomeIcons.store, // Shop icon
              backgroundColor: const Color(0xFFFBC02D), // Yellow/gold color
              textColor: const Color(0xFF5e3a1c), // Text color for contrast
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MarketplaceScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            // Puedes añadir un botón para añadir una notificación de prueba aquí para desarrolladores
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_user != null) {
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(_user!.uid)
                        .collection('inAppNotifications')
                        .add({
                      'title': 'Alerta de Prueba',
                      'body': '¡Nueva notificación in-app! Revisa tu campana.',
                      'timestamp': FieldValue.serverTimestamp(),
                      'read': false,
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Notificación de prueba enviada.')),
                    );
                  }
                },
                icon: const Icon(Icons.add_alert, color: Colors.white),
                label: const Text('Enviar Notificación de Prueba',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFc99450),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Widget to build statistics modules with chart
  Widget _buildChartModule({
    required String title,
    required VoidCallback onTap,
    required Widget chartWidget,
    List<Map<String, dynamic>>? legendItems,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5e3a1c),
                  ),
                ),
                if (legendItems != null)
                  Row(
                    children: legendItems.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: item['color'],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item['text'],
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
            const SizedBox(height: 15),
            chartWidget,
          ],
        ),
      ),
    );
  }

  // Generic widget for smaller module cards (Bovine, Calendar, Inventory, Finance)
  Widget _buildModuleCard({
    required String title,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment:
              MainAxisAlignment.center, // Vertically center the content
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5e3a1c), // Title maintains its original color
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  // Widget for large action buttons (AI, Marketplace)
  Widget _buildLargeActionButton({
    required String text,
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onTap,
    Color textColor = Colors.white, // Added a parameter for text color
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: textColor, size: 28), // Use textColor here
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  // Use TextStyle to apply textColor
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor, // Use textColor here
                ),
                softWrap: true,
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: textColor, size: 20), // Use textColor here
          ],
        ),
      ),
    );
  }

  // --- Example chart widgets (FL_Chart) ---

  Widget _buildLineChartExample() {
    return AspectRatio(
      aspectRatio: 1.70,
      child: Padding(
        padding:
            const EdgeInsets.only(right: 18.0, left: 12.0, top: 12, bottom: 0),
        child: LineChart(
          LineChartData(
            lineTouchData:
                LineTouchData(enabled: false), // Deshabilita la interactividad
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) {
                return const FlLine(
                  color: Color(0xffececec),
                  strokeWidth: 1,
                );
              },
              getDrawingVerticalLine: (value) {
                return const FlLine(
                  color: Color(0xffececec),
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, TitleMeta meta) {
                    const style = TextStyle(
                      color: Color(0xff72719b),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    );
                    Widget text;
                    switch (value.toInt()) {
                      case 0:
                        text = const Text('Jan', style: style);
                        break;
                      case 1:
                        text = const Text('Feb', style: style);
                        break;
                      case 2:
                        text = const Text('Mar', style: style);
                        break;
                      case 3:
                        text = const Text('Apr', style: style);
                        break;
                      case 4:
                        text = const Text('May', style: style);
                        break;
                      case 5:
                        text = const Text('Jun', style: style);
                        break;
                      default:
                        text = const Text('', style: style);
                        break;
                    }
                    return SideTitleWidget(
                      space: 8,
                      meta: meta,
                      child: text, // Pass the complete TitleMeta object
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 20,
                  getTitlesWidget: (value, TitleMeta meta) {
                    const style = TextStyle(
                      color: Color(0xff72719b),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    );
                    return SideTitleWidget(
                      space: 8,
                      meta: meta, // Pass the complete TitleMeta object
                      child: Text(value.toInt().toString(),
                          style: style, textAlign: TextAlign.left),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(
              show: false,
            ),
            minX: 0,
            maxX: 5,
            minY: 0,
            maxY: 100,
            lineBarsData: [
              LineChartBarData(
                spots: const [
                  FlSpot(0, 20),
                  FlSpot(1, 45),
                  FlSpot(2, 28),
                  FlSpot(3, 80),
                  FlSpot(4, 99),
                  FlSpot(5, 43),
                ],
                isCurved: true,
                color: const Color(0xFFa75c2e),
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (FlSpot spot, double xPercentage,
                      LineChartBarData bar, int index) {
                    if (spot.y == 80) {
                      return FlDotCirclePainter(
                        radius: 5,
                        color: const Color(0xFF673ab7),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    }
                    return FlDotCirclePainter(
                      radius: 3,
                      color: const Color(0xFFa75c2e),
                      strokeWidth: 1,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFFa75c2e).withOpacity(0.3),
                ),
              ),
              LineChartBarData(
                spots: const [
                  FlSpot(0, 50),
                  FlSpot(1, 70),
                  FlSpot(2, 30),
                  FlSpot(3, 90),
                  FlSpot(4, 60),
                  FlSpot(5, 80),
                ],
                isCurved: true,
                color: const Color(0xFF673ab7),
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF673ab7).withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
