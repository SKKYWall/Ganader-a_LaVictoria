// lib/screens/calendar/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Necesario para 'whereNotNull' u otros si se usan
import 'dart:collection';
import 'package:manual_ganadero_flutter/models/calendar.dart'; // Importa el modelo CalendarEvent
import 'package:manual_ganadero_flutter/screens/calendar/add_edit_event_screen.dart'; // Importa la pantalla de añadir/editar
import 'package:intl/intl.dart'; // Para formatear fechas

// Funciones auxiliares para TableCalendar para comparar y hacer hash de fechas
// Ignoran la hora para que los eventos del mismo día sean tratados igual
int getHashCode(DateTime key) {
  return key.day * 1000000 + key.month * 10000 + key.year;
}

bool isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) {
    return false;
  }
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  late final ValueNotifier<List<CalendarEvent>> _selectedEventsNotifier;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.disabled;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Mapa para almacenar todos los eventos cargados desde Firestore
  // La clave es la fecha normalizada (solo año, mes, día)
  final Map<DateTime, List<CalendarEvent>> _allEvents =
      LinkedHashMap<DateTime, List<CalendarEvent>>(
    equals: isSameDay,
    hashCode: getHashCode,
  );

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    // Inicializar el notifier con los eventos del día seleccionado actual
    _selectedEventsNotifier = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadEvents(); // Cargar eventos desde Firestore al iniciar
  }

  @override
  void dispose() {
    _selectedEventsNotifier.dispose();
    super.dispose();
  }

  // Helper para obtener eventos de un día específico
  List<CalendarEvent> _getEventsForDay(DateTime day) {
    return _allEvents[day] ?? [];
  }

  // Helper para obtener eventos de una semana específica
  List<CalendarEvent> _getEventsForWeek(DateTime weekFocusedDay) {
    List<CalendarEvent> weekEvents = [];
    DateTime startOfWeek = weekFocusedDay.subtract(
        Duration(days: weekFocusedDay.weekday - 1)); // Lunes de la semana
    DateTime endOfWeek =
        startOfWeek.add(const Duration(days: 6)); // Domingo de la semana

    DateTime currentDay = startOfWeek;
    while (currentDay.isBefore(endOfWeek.add(const Duration(days: 1)))) {
      weekEvents.addAll(_getEventsForDay(currentDay));
      currentDay = currentDay.add(const Duration(days: 1));
    }
    // Ordenar eventos por fecha y luego por título
    weekEvents.sort((a, b) {
      int dateComparison = a.date.compareTo(b.date);
      if (dateComparison != 0) {
        return dateComparison;
      }
      return a.title.compareTo(b.title);
    });
    return weekEvents;
  }

  // Helper para obtener eventos de un mes específico (incluye mes actual o próximo)
  List<CalendarEvent> _getEventsForMonth(DateTime monthFocusedDay) {
    List<CalendarEvent> monthEvents = [];
    DateTime startOfMonth =
        DateTime.utc(monthFocusedDay.year, monthFocusedDay.month, 1);
    DateTime endOfMonth = DateTime.utc(monthFocusedDay.year,
        monthFocusedDay.month + 1, 0); // Último día del mes

    DateTime currentDay = startOfMonth;
    while (currentDay.isBefore(endOfMonth.add(const Duration(days: 1)))) {
      monthEvents.addAll(_getEventsForDay(currentDay));
      currentDay = currentDay.add(const Duration(days: 1));
    }
    // Ordenar eventos por fecha y luego por título
    monthEvents.sort((a, b) {
      int dateComparison = a.date.compareTo(b.date);
      if (dateComparison != 0) {
        return dateComparison;
      }
      return a.title.compareTo(b.title);
    });
    return monthEvents;
  }

  // Función para cargar los eventos desde Firestore
  Future<void> _loadEvents() async {
    if (_currentUser == null) return;

    try {
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('calendarEvents')
          .orderBy('date')
          .get();

      if (!mounted) return; // Añadido check
      setState(() {
        _allEvents.clear(); // Limpiar eventos existentes
        for (var doc in querySnapshot.docs) {
          final event = CalendarEvent.fromFirestore(
              doc.data() as Map<String, dynamic>, doc.id);
          final normalizedDate =
              DateTime.utc(event.date.year, event.date.month, event.date.day);

          _allEvents.update(
            normalizedDate,
            (list) => list..add(event),
            ifAbsent: () => [event],
          );
        }

        // Asegúrate de que _selectedDay no sea nulo al actualizar _selectedEventsNotifier
        if (_selectedDay != null) {
          _selectedEventsNotifier.value = _getEventsForDay(_selectedDay!);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar eventos: $e')),
        );
      }
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay; // Actualiza focusedDay también
        _rangeSelectionMode = RangeSelectionMode.disabled;
      });
      _selectedEventsNotifier.value = _getEventsForDay(selectedDay);
    }
  }

  // Función para manejar la navegación a la pantalla de añadir/editar evento
  void _navigateToAddEditEvent({CalendarEvent? event}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditEventScreen(event: event),
      ),
    );
    if (result == true) {
      _loadEvents(); // Recarga los eventos si se añade/edita/elimina
    }
  }

  // Función para eliminar un evento (Firestore)
  Future<void> _deleteEvent(String eventId) async {
    if (_currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('calendarEvents')
          .doc(eventId)
          .delete();
      _loadEvents(); // Recargar eventos después de eliminar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento eliminado con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar evento: $e')),
        );
      }
    }
  }

  // Helper para obtener icono según la categoría
  Icon _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'vacunación':
        return const Icon(Icons.healing, color: Colors.green);
      case 'parto':
        return const Icon(Icons.pets, color: Color(0xFF8B4513)); // Brown
      case 'cita':
        return const Icon(Icons.event, color: Colors.blue);
      case 'mantenimiento':
        return const Icon(Icons.build, color: Colors.orange);
      case 'medicación':
        return const Icon(Icons.medical_services, color: Colors.purple);
      case 'alimentación':
        return const Icon(Icons.restaurant, color: Colors.teal);
      case 'reproducción':
        return const Icon(Icons.favorite, color: Colors.pink);
      case 'sanidad':
        return const Icon(Icons.sick, color: Colors.red);
      default:
        return const Icon(Icons.event_note, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Error: Usuario no autenticado.'),
        ),
      );
    }

    // Obtener eventos para las secciones de la vista unificada
    // Asegurarse de que solo se muestren eventos futuros
    List<CalendarEvent> allUpcomingEvents = _allEvents.values
        .expand((events) => events)
        .where((event) => event.date.isAfter(DateTime.now()
            .subtract(const Duration(minutes: 1)))) // Pequeño buffer
        .toList();
    allUpcomingEvents
        .sort((a, b) => a.date.compareTo(b.date)); // Ordenar por fecha

    // Filtrar eventos de la semana actual (desde hoy hasta fin de semana)
    DateTime now = DateTime.now();
    DateTime startOfWeek = DateTime(now.year, now.month, now.day);
    // Asegúrate de que el fin de semana sea el domingo o el final de la semana laboral
    // Para esta semana: va desde 'hoy' hasta 6 días más.
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));

    List<CalendarEvent> currentWeekEvents = allUpcomingEvents.where((event) {
      return event.date.isAfter(now.subtract(const Duration(minutes: 1))) &&
          event.date
              .isBefore(endOfWeek.add(const Duration(hours: 23, minutes: 59)));
    }).toList();

    // Filtrar eventos del próximo mes (excluyendo la semana actual)
    DateTime startOfNextMonth = DateTime(now.year, now.month + 1, 1);
    DateTime endOfNextMonth =
        DateTime(now.year, now.month + 2, 0); // Último día del próximo mes

    List<CalendarEvent> nextMonthEvents = allUpcomingEvents.where((event) {
      // Eventos que están en el rango del próximo mes y no están ya en la semana actual
      return event.date
              .isAfter(startOfNextMonth.subtract(const Duration(minutes: 1))) &&
          event.date.isBefore(
              endOfNextMonth.add(const Duration(hours: 23, minutes: 59))) &&
          !currentWeekEvents.contains(
              event); // Evitar duplicados si un evento de la semana actual cae en el próximo mes
    }).toList();

    // Filtrar eventos a futuro (más allá del próximo mes, como los partos)
    List<CalendarEvent> futureEvents = allUpcomingEvents.where((event) {
      return event.date
          .isAfter(endOfNextMonth.add(const Duration(hours: 23, minutes: 59)));
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        backgroundColor: const Color(0xFFf5f0e1),
        title: const Text(
          'Calendario de Eventos',
          style: TextStyle(
            color: Color(0xFF5e3a1c),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF5e3a1c)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TableCalendar<CalendarEvent>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                rangeSelectionMode: _rangeSelectionMode,
                eventLoader: (day) => _getEventsForDay(day),
                startingDayOfWeek: StartingDayOfWeek.monday,
                calendarFormat: _calendarFormat,
                onDaySelected: _onDaySelected,
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  markersMaxCount: 3,
                  todayDecoration: BoxDecoration(
                    color: const Color(0xFFc99450).withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Color(0xFF6b4226),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: Colors.red, // Color para los puntos de eventos
                    shape: BoxShape.circle,
                  ),
                  weekendTextStyle: const TextStyle(color: Colors.red),
                  // Estilo para los textos de los días
                  defaultTextStyle: const TextStyle(color: Color(0xFF5e3a1c)),
                  holidayTextStyle: const TextStyle(color: Color(0xFF5e3a1c)),
                  weekNumberTextStyle:
                      const TextStyle(color: Color(0xFF5e3a1c)),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: const TextStyle(
                    color: Color(0xFF5e3a1c),
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                  leftChevronIcon:
                      const Icon(Icons.chevron_left, color: Color(0xFF5e3a1c)),
                  rightChevronIcon:
                      const Icon(Icons.chevron_right, color: Color(0xFF5e3a1c)),
                ),
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
              ),
            ),
            const SizedBox(height: 16.0),

            // Sección de Eventos del Día Seleccionado
            _buildSectionTitle('Eventos del Día Seleccionado'),
            ValueListenableBuilder<List<CalendarEvent>>(
              valueListenable: _selectedEventsNotifier,
              builder: (context, value, _) {
                if (value.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Text(
                        'No hay eventos para el ${DateFormat('dd/MM/yyyy').format(_selectedDay!)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    final event = value[index];
                    return _buildEventCard(event);
                  },
                );
              },
            ),
            const SizedBox(
                height: 20.0), // Espacio después de la sección del día

            // Sección: Actividades de esta Semana
            _buildSectionTitle('Actividades de esta Semana'),
            currentWeekEvents.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Text(
                        'No hay actividades para esta semana.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: currentWeekEvents.length,
                    itemBuilder: (context, index) {
                      final event = currentWeekEvents[index];
                      return _buildEventCard(event);
                    },
                  ),
            const SizedBox(
                height: 20.0), // Espacio después de la sección de la semana

            // Sección: Actividades del Próximo Mes
            _buildSectionTitle('Actividades del Próximo Mes'),
            nextMonthEvents.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Text(
                        'No hay actividades para el próximo mes.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: nextMonthEvents.length,
                    itemBuilder: (context, index) {
                      final event = nextMonthEvents[index];
                      return _buildEventCard(event);
                    },
                  ),

            const SizedBox(height: 20.0),

            // Sección: Eventos a Largo Plazo (Partos)
            _buildSectionTitle('Eventos a Largo Plazo'),
            futureEvents.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Text(
                        'No hay eventos a largo plazo.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: futureEvents.length,
                    itemBuilder: (context, index) {
                      final event = futureEvents[index];
                      return _buildEventCard(event);
                    },
                  ),
            // *** Añadido espacio extra para el FAB ***
            const SizedBox(height: 80.0), // Espacio adicional para el botón FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditEvent(), // Añadir nuevo evento
        backgroundColor: const Color(0xFF6b4226),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- Widgets Auxiliares ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          16.0, 16.0, 16.0, 8.0), // Más padding superior
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20, // Título un poco más grande
            fontWeight: FontWeight.bold,
            color: Color(0xFF5e3a1c),
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: 16.0, vertical: 6.0), // Más margen y vertical
      elevation: 3, // Mayor elevación para un efecto más pronunciado
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)), // Bordes más redondeados
      color: Colors.white, // Fondo de tarjeta blanco
      child: InkWell(
        // Para el efecto de "ripple" al tocar
        onTap: () => _navigateToAddEditEvent(event: event),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.all(12.0), // Más padding dentro de la tarjeta
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icono de la categoría
              Padding(
                padding: const EdgeInsets.only(top: 4.0, right: 12.0),
                child: _getCategoryIcon(event.category),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16, // Título un poco más grande
                          color: Color(0xFF5e3a1c)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(event.date),
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    if (event.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.description,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                        maxLines: 2, // Limitar descripción a 2 líneas
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Botón de eliminar
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDeleteEvent(
                    event.id), // Confirmación antes de eliminar
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Confirmación de eliminación de evento
  Future<void> _confirmDeleteEvent(String eventId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación',
              style: TextStyle(color: Color(0xFF5e3a1c))),
          content:
              const Text('¿Estás seguro de que quieres eliminar este evento?'),
          backgroundColor: const Color(0xFFfbf6ec),
          surfaceTintColor: const Color(0xFFfbf6ec),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF6b4226))),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _deleteEvent(eventId);
    }
  }
}
