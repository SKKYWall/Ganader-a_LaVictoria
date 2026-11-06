// lib/widgets/bulk_weight_dialog.dart
//
// Registrar el peso de varios animales en una sola sesión (ej. pesar todo
// el lote de engorda al salir del corral) en vez de abrir el diálogo de
// peso de cada animal uno por uno. Un solo batch write al final.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';

/// Devuelve true si se guardó al menos un peso.
Future<bool> showBulkWeightDialog(
  BuildContext context, {
  required String userId,
  required String ranchId,
  required List<Animal> animals,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BulkWeightSheet(
      userId: userId,
      ranchId: ranchId,
      animals: animals,
    ),
  );
  return result ?? false;
}

class _BulkWeightSheet extends StatefulWidget {
  final String userId;
  final String ranchId;
  final List<Animal> animals;

  const _BulkWeightSheet({
    required this.userId,
    required this.ranchId,
    required this.animals,
  });

  @override
  State<_BulkWeightSheet> createState() => _BulkWeightSheetState();
}

class _BulkWeightSheetState extends State<_BulkWeightSheet> {
  DateTime _selectedDate = DateTime.now();
  final Set<String> _selected = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;

  TextEditingController _controllerFor(String animalId) {
    return _controllers.putIfAbsent(
        animalId, () => TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final entries = <(String, double)>[];
    for (final id in _selected) {
      final text = _controllers[id]?.text.trim() ?? '';
      final weight = double.tryParse(text);
      if (weight != null && weight > 0) {
        entries.add((id, weight));
      }
    }
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ingresa al menos un peso válido'),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final (animalId, weight) in entries) {
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('ranches')
            .doc(widget.ranchId)
            .collection('animals')
            .doc(animalId);
        batch.update(ref, {
          'stats': FieldValue.arrayUnion([
            {
              'label': 'Peso',
              'value': weight,
              'date': Timestamp.fromDate(_selectedDate),
            }
          ])
        });
      }
      await batch.commit();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFfbf6ec),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.scale, color: Color(0xFFc99450))),
              const SizedBox(width: 15),
              const Expanded(
                  child: Text('Pesaje por Lote',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5e3a1c)))),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Color(0xFFc99450), size: 18),
                  const SizedBox(width: 10),
                  Text(
                      'Fecha de pesaje: ${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.animals.length,
              itemBuilder: (context, index) {
                final animal = widget.animals[index];
                final isSelected = _selected.contains(animal.id);
                return Card(
                  color: isSelected ? const Color(0xFFfbf6ec) : Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          activeColor: const Color(0xFFc99450),
                          onChanged: (checked) => setState(() {
                            if (checked == true) {
                              _selected.add(animal.id);
                            } else {
                              _selected.remove(animal.id);
                            }
                          }),
                        ),
                        const Icon(FontAwesomeIcons.cow,
                            color: Color(0xFFc99450), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                '${animal.name} (${animal.earTagNumber})',
                                overflow: TextOverflow.ellipsis)),
                        if (isSelected)
                          SizedBox(
                            width: 90,
                            child: TextField(
                              controller: _controllerFor(animal.id),
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: const InputDecoration(
                                  isDense: true,
                                  suffixText: 'kg',
                                  border: OutlineInputBorder()),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFc99450),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Guardar Pesajes (${_selected.length})',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
