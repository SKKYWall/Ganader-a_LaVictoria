import 'package:flutter/material.dart';
import 'screens/principal/dashboard_screen.dart';
import 'screens/bovino/animal_detail_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/dashboard': (context) => DashboardScreen(),
  '/animalDetail': (context) => AnimalDetailScreen(),
};
