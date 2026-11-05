// lib/widgets/animal_parent_picker.dart
//
// Selector de padre/madre entre los animales reales del rancho activo
// (filtrados por sexo), con un escape a texto libre para progenitores que
// no están en el sistema (comprados, vendidos, inseminación con semen
// externo, etc.). El valor que entrega es siempre el earTagNumber del
// animal elegido, o el texto manual — la misma convención que ya usa
// genetica_screen.dart para calcular consanguinidad.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';

const String kManualParentSentinel = '__manual__';

class AnimalParentPicker extends StatefulWidget {
  final String label;
  final String sexFilter; // 'Hembra' | 'Macho'
  final String? currentRanchId;
  final String? excludeAnimalId;
  final String? initialEarTag;
  final ValueChanged<String?> onChanged;

  const AnimalParentPicker({
    super.key,
    required this.label,
    required this.sexFilter,
    required this.currentRanchId,
    this.excludeAnimalId,
    this.initialEarTag,
    required this.onChanged,
  });

  @override
  State<AnimalParentPicker> createState() => _AnimalParentPickerState();
}

class _AnimalParentPickerState extends State<AnimalParentPicker> {
  late final TextEditingController _manualController;
  bool _manualMode = false;
  String? _selectedValue;
  bool _resolvedInitial = false;

  @override
  void initState() {
    super.initState();
    _manualController = TextEditingController();
    final initial = widget.initialEarTag;
    if (initial != null && initial.isNotEmpty) {
      // Se asume manual hasta que el stream confirme que coincide con un
      // animal real (ver _resolveInitialIfNeeded).
      _manualMode = true;
      _manualController.text = initial;
      _selectedValue = kManualParentSentinel;
    }
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _animalsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.currentRanchId == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('ranches')
        .doc(widget.currentRanchId)
        .collection('animals')
        .snapshots();
  }

  void _resolveInitialIfNeeded(List<Animal> candidates) {
    if (_resolvedInitial) return;
    _resolvedInitial = true;
    final initial = widget.initialEarTag;
    if (initial == null || initial.isEmpty) return;
    final matches = candidates.any((a) => a.earTagNumber == initial);
    if (matches) {
      _manualMode = false;
      _selectedValue = initial;
    }
  }

  void _handleDropdownChanged(String? val) {
    setState(() {
      _selectedValue = val;
      _manualMode = val == kManualParentSentinel;
    });
    widget.onChanged(_manualMode
        ? (_manualController.text.trim().isEmpty
            ? null
            : _manualController.text.trim())
        : val);
  }

  void _handleManualChanged(String text) {
    widget.onChanged(text.trim().isEmpty ? null : text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _animalsStream(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final candidates = docs
            .map((d) =>
                Animal.fromFirestore(d.data() as Map<String, dynamic>, d.id))
            .where((a) =>
                a.sex == widget.sexFilter &&
                a.id != widget.excludeAnimalId &&
                a.earTagNumber.trim().isNotEmpty &&
                a.earTagNumber != 'N/A')
            .toList();

        if (snapshot.hasData) {
          _resolveInitialIfNeeded(candidates);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedValue,
              decoration: InputDecoration(
                labelText: widget.label,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: [
                ...candidates.map((a) => DropdownMenuItem(
                      value: a.earTagNumber,
                      child: Text('${a.name} (${a.earTagNumber})',
                          overflow: TextOverflow.ellipsis),
                    )),
                const DropdownMenuItem(
                  value: kManualParentSentinel,
                  child: Text('Otro / no está en el sistema'),
                ),
              ],
              onChanged: _handleDropdownChanged,
            ),
            if (_manualMode) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _manualController,
                maxLength: 15,
                decoration: InputDecoration(
                  labelText: 'Arete (texto libre)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: _handleManualChanged,
              ),
            ],
          ],
        );
      },
    );
  }
}
