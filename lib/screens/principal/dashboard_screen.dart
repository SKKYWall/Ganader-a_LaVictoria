import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Widgets y pantallas
import 'package:manual_ganadero_flutter/widgets/dashboard_widgets.dart';
import 'package:manual_ganadero_flutter/widgets/dashboard_charts.dart';
import 'package:manual_ganadero_flutter/screens/bovino/bovino_screen.dart';
import 'package:manual_ganadero_flutter/screens/profile/profile_screen.dart';
import 'package:manual_ganadero_flutter/screens/inventario/inventory_screen.dart';
import 'package:manual_ganadero_flutter/screens/finance/finance_screen.dart';
import 'package:manual_ganadero_flutter/screens/calendar/calendar_screen.dart';
import 'package:manual_ganadero_flutter/screens/marketplace/marketplace_screen.dart';
import 'package:manual_ganadero_flutter/screens/intelligence/intelligence_screen.dart';
import 'package:manual_ganadero_flutter/screens/estadisticas/estadisticas_screen.dart';
import 'package:manual_ganadero_flutter/screens/modulos/reportes_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
  }

  // Stream que escucha los propósitos de los animales del usuario
  Stream<Set<String>> _getUnlockedModulesStream() {
    if (_user == null) return Stream.value({});

    return FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .collection('animals')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data()['purpose'] as String?)
          .where((p) => p != null)
          .cast<String>()
          .toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: _buildAppBar(),
      body: StreamBuilder<Set<String>>(
        stream: _getUnlockedModulesStream(),
        builder: (context, snapshot) {
          // Si aún carga o no hay usuario, mostramos un set vacío
          final unlocked = snapshot.data ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                DashboardChartModule(
                  title: 'Estadísticas',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const EstadisticasScreen())),
                  legendItems: const [
                    {'color': Color(0xFFa75c2e), 'text': 'Ganancia'},
                    {'color': Color(0xFF673ab7), 'text': 'Gastos'},
                  ],
                ),
                const SizedBox(height: 20),

                // FILA 1: BOVINO Y CALENDARIO (Siempre desbloqueados)
                Row(
                  children: [
                    Expanded(
                      child: ModuleCard(
                        title: 'Bovino',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const BovinoScreen())),
                        children: const [
                          Icon(FontAwesomeIcons.cow,
                              size: 50, color: Color(0xFF8B4513)),
                          Text('Mis Animales', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ModuleCard(
                        title: 'Calendario',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const CalendarScreen())),
                        children: const [
                          Icon(Icons.calendar_month,
                              size: 50, color: Colors.red),
                          Text('Tareas', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // FILA 2: INVENTARIO Y FINANZAS
                Row(
                  children: [
                    Expanded(
                      child: ModuleCard(
                        title: 'Inventario',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const InventoryScreen())),
                        children: const [
                          Icon(Icons.inventory,
                              size: 50,
                              color: Color(0xFF31319A)), // Azul oscuro
                          Text('Suministros', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ModuleCard(
                        title: 'Finanzas',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const FinanceScreen())),
                        children: const [
                          Icon(Icons.monetization_on,
                              size: 50, color: Colors.green),
                          Text('Ingresos/Egresos',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Línea divisoria opcional para separar fijos de dinámicos
                const Divider(color: Colors.black12, thickness: 1),
                const SizedBox(height: 10),

                // ==========================================
                // MÓDULOS DINÁMICOS (POR PROPÓSITO)
                // ==========================================

                // FILA 3: LECHE Y GENÉTICA
                Row(
                  children: [
                    Expanded(
                      child: _buildDynamicModule(
                        title: 'Producción Leche',
                        purposeKey: 'Leche',
                        icon: FontAwesomeIcons.faucet,
                        color: Colors.blue,
                        isUnlocked: unlocked.contains('Leche'),
                        onTap: () => Navigator.pushNamed(context, '/leche'),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildDynamicModule(
                        title: 'Genética',
                        purposeKey: 'Genética',
                        icon: FontAwesomeIcons.dna,
                        color: Colors.teal,
                        isUnlocked: unlocked.contains('Genética'),
                        onTap: () => Navigator.pushNamed(context, '/genetica'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // FILA 4: ENGORDA Y REPRODUCTORA
                Row(
                  children: [
                    Expanded(
                      child: _buildDynamicModule(
                        title: 'Engorda y Prod.',
                        purposeKey: 'Engorda o Carne', // Actualizado mensaje
                        icon: FontAwesomeIcons.weightScale,
                        color: Colors.orange,
                        // Se desbloquea con Engorda o Carne
                        isUnlocked: unlocked.contains('Engorda') ||
                            unlocked.contains('Carne'),
                        onTap: () => Navigator.pushNamed(context, '/engorda'),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildDynamicModule(
                        title: 'Reproductora',
                        purposeKey: 'Reproductora',
                        icon: FontAwesomeIcons.venus,
                        color: Colors.pink,
                        isUnlocked: unlocked.contains('Reproductora'),
                        onTap: () =>
                            Navigator.pushNamed(context, '/reproductora'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // FILA 5: SANIDAD Y REPORTES (Siempre Desbloqueados)
                Row(
                  children: [
                    Expanded(
                      child: ModuleCard(
                        title: 'Sanidad',
                        onTap: () =>
                            Navigator.pushNamed(context, '/sanidadScreen'),
                        children: const [
                          Icon(Icons.vaccines, size: 50, color: Colors.teal),
                          Text('Salud Animal', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ModuleCard(
                        title: 'Reportes',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ReportesScreen())),
                        children: const [
                          Icon(FontAwesomeIcons.filePdf,
                              size: 50, color: Colors.redAccent),
                          Text('Exportación', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ==========================================
                // BOTONES GRANDES FINALES
                // ==========================================
                LargeActionButton(
                  text: 'Análisis IA Animal',
                  icon: FontAwesomeIcons.brain,
                  backgroundColor: const Color(0xFF9C27B0),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const IntelligenceScreen())),
                ),
                const SizedBox(height: 15),
                LargeActionButton(
                  text: 'Marketplace Ganadero',
                  icon: FontAwesomeIcons.store,
                  backgroundColor: const Color(0xFFFBC02D),
                  textColor: const Color(0xFF5e3a1c),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const MarketplaceScreen())),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget auxiliar para módulos que se bloquean/desbloquean
  Widget _buildDynamicModule({
    required String title,
    required String purposeKey,
    required IconData icon,
    required Color color,
    required bool isUnlocked,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.5,
      child: ModuleCard(
        title: title,
        onTap: isUnlocked
            ? onTap
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Registra un animal de tipo "$purposeKey" para desbloquear.')),
                );
              },
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 50, color: isUnlocked ? color : Colors.grey),
              if (!isUnlocked)
                const Icon(FontAwesomeIcons.lock,
                    size: 20, color: Colors.black54),
            ],
          ),
          Text(
            isUnlocked ? 'Gestionar' : 'Bloqueado',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFfbf6ec),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.newspaper, color: Color(0xFF5e3a1c)),
        onPressed: () => Navigator.of(context).pushNamed('/newsScreen'),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Color(0xFF5e3a1c)),
          onPressed: () =>
              Navigator.of(context).pushNamed('/inAppNotifications'),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 20.0),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen())),
            child: const CircleAvatar(
                backgroundColor: Color(0xFFc99450),
                child: Icon(Icons.person, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
