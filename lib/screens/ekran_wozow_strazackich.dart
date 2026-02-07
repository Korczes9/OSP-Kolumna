import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/strazak.dart';

/// Model wozu strażackiego
class WozStrazacki {
  final String id;
  final String nazwa;
  final String? numerRejestracyjny;
  final String? marka;
  final String? model;
  final int? rokProdukcji;
  final String? typ; // np. GBA, GCBA, SLRt
  final int? pojemnoscZbiornika;
  final String? uwagi;
  final bool aktywny;

  WozStrazacki({
    required this.id,
    required this.nazwa,
    this.numerRejestracyjny,
    this.marka,
    this.model,
    this.rokProdukcji,
    this.typ,
    this.pojemnoscZbiornika,
    this.uwagi,
    this.aktywny = true,
  });

  factory WozStrazacki.fromMap(Map<String, dynamic> map, String id) {
    return WozStrazacki(
      id: id,
      nazwa: map['nazwa'] ?? '',
      numerRejestracyjny: map['numerRejestracyjny'],
      marka: map['marka'],
      model: map['model'],
      rokProdukcji: map['rokProdukcji'],
      typ: map['typ'],
      pojemnoscZbiornika: map['pojemnoscZbiornika'],
      uwagi: map['uwagi'],
      aktywny: map['aktywny'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nazwa': nazwa,
      'numerRejestracyjny': numerRejestracyjny,
      'marka': marka,
      'model': model,
      'rokProdukcji': rokProdukcji,
      'typ': typ,
      'pojemnoscZbiornika': pojemnoscZbiornika,
      'uwagi': uwagi,
      'aktywny': aktywny,
    };
  }
}

/// Ekran zarządzania wozami strażackimi
class EkranWozowStrazackich extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranWozowStrazackich({super.key, required this.aktualnyStrazak});

  @override
  State<EkranWozowStrazackich> createState() => _EkranWozowStrazackichState();
}

class _EkranWozowStrazackichState extends State<EkranWozowStrazackich> {
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wozy strażackie'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('wozy').orderBy('nazwa').snapshots(),
        initialData: null,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Błąd: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final wozy = snapshot.data!.docs
              .map((doc) => WozStrazacki.fromMap(
                  doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          if (wozy.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Brak wozów strażackich',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  if (widget.aktualnyStrazak.jestModeratorem) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _pokazFormularz(null),
                      icon: const Icon(Icons.add),
                      label: const Text('Dodaj pierwszy wóz'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: wozy.length,
            itemBuilder: (context, index) {
              final woz = wozy[index];
              return _buildWozCard(woz);
            },
          );
        },
      ),
      floatingActionButton: widget.aktualnyStrazak.jestModeratorem
          ? FloatingActionButton(
              onPressed: () => _pokazFormularz(null),
              backgroundColor: Colors.blue[700],
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildWozCard(WozStrazacki woz) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: woz.aktywny ? Colors.blue : Colors.grey,
          child: const Icon(Icons.directions_car, color: Colors.white),
        ),
        title: Text(
          woz.nazwa,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (woz.numerRejestracyjny != null)
              Text(woz.numerRejestracyjny!),
            if (woz.marka != null || woz.model != null)
              Text('${woz.marka ?? ''} ${woz.model ?? ''}'.trim()),
            if (woz.typ != null)
              Text('Typ: ${woz.typ}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            if (!woz.aktywny)
              const Text(
                'NIEAKTYWNY',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        trailing: widget.aktualnyStrazak.jestModeratorem
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _pokazFormularz(woz);
                  } else if (value == 'delete') {
                    _usunWoz(woz.id);
                  } else if (value == 'toggle') {
                    _toggleAktywny(woz);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edytuj'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          woz.aktywny ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(woz.aktywny
                            ? 'Oznacz jako nieaktywny'
                            : 'Aktywuj'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Usuń', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              )
            : const Icon(Icons.chevron_right),
        isThreeLine: true,
        onTap: () => _pokazSzczegoly(woz),
      ),
    );
  }

  void _pokazSzczegoly(WozStrazacki woz) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(woz.nazwa),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (woz.numerRejestracyjny != null)
                _buildInfoRow('Numer rejestracyjny', woz.numerRejestracyjny!),
              if (woz.marka != null) _buildInfoRow('Marka', woz.marka!),
              if (woz.model != null) _buildInfoRow('Model', woz.model!),
              if (woz.rokProdukcji != null)
                _buildInfoRow('Rok produkcji', woz.rokProdukcji.toString()),
              if (woz.typ != null) _buildInfoRow('Typ', woz.typ!),
              if (woz.pojemnoscZbiornika != null)
                _buildInfoRow(
                    'Pojemność zbiornika', '${woz.pojemnoscZbiornika} L'),
              _buildInfoRow('Status', woz.aktywny ? 'Aktywny' : 'Nieaktywny'),
              if (woz.uwagi != null && woz.uwagi!.isNotEmpty)
                _buildInfoRow('Uwagi', woz.uwagi!),
            ],
          ),
        ),
        actions: [
          if (widget.aktualnyStrazak.jestModeratorem)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _pokazFormularz(woz);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edytuj'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _pokazFormularz(WozStrazacki? woz) {
    showDialog(
      context: context,
      builder: (context) => _DialogWoza(woz: woz),
    );
  }

  Future<void> _toggleAktywny(WozStrazacki woz) async {
    try {
      await _firestore.collection('wozy').doc(woz.id).update({
        'aktywny': !woz.aktywny,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(woz.aktywny
                ? 'Wóz oznaczony jako nieaktywny'
                : 'Wóz aktywowany'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _usunWoz(String wozId) async {
    final potwierdz = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdzenie'),
        content: const Text('Czy na pewno chcesz usunąć ten wóz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (potwierdz == true && mounted) {
      try {
        await _firestore.collection('wozy').doc(wozId).delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wóz usunięty'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Błąd: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Dialog dodawania/edycji wozu
class _DialogWoza extends StatefulWidget {
  final WozStrazacki? woz;

  const _DialogWoza({this.woz});

  @override
  State<_DialogWoza> createState() => _DialogWozaState();
}

class _DialogWozaState extends State<_DialogWoza> {
  final _formKey = GlobalKey<FormState>();
  final _nazwaController = TextEditingController();
  final _numerRejestracyjnyController = TextEditingController();
  final _markaController = TextEditingController();
  final _modelController = TextEditingController();
  final _rokProdukcjiController = TextEditingController();
  final _typController = TextEditingController();
  final _pojemnoscZbiornika = TextEditingController();
  final _uwagiController = TextEditingController();
  bool _ladowanie = false;

  @override
  void initState() {
    super.initState();
    if (widget.woz != null) {
      _nazwaController.text = widget.woz!.nazwa;
      _numerRejestracyjnyController.text = widget.woz!.numerRejestracyjny ?? '';
      _markaController.text = widget.woz!.marka ?? '';
      _modelController.text = widget.woz!.model ?? '';
      _rokProdukcjiController.text =
          widget.woz!.rokProdukcji?.toString() ?? '';
      _typController.text = widget.woz!.typ ?? '';
      _pojemnoscZbiornika.text =
          widget.woz!.pojemnoscZbiornika?.toString() ?? '';
      _uwagiController.text = widget.woz!.uwagi ?? '';
    }
  }

  @override
  void dispose() {
    _nazwaController.dispose();
    _numerRejestracyjnyController.dispose();
    _markaController.dispose();
    _modelController.dispose();
    _rokProdukcjiController.dispose();
    _typController.dispose();
    _pojemnoscZbiornika.dispose();
    _uwagiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.woz == null ? 'Nowy wóz' : 'Edytuj wóz'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nazwaController,
                decoration: const InputDecoration(
                  labelText: 'Nazwa *',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Wymagane' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _numerRejestracyjnyController,
                decoration: const InputDecoration(
                  labelText: 'Numer rejestracyjny',
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _markaController,
                decoration: const InputDecoration(
                  labelText: 'Marka',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  prefixIcon: Icon(Icons.precision_manufacturing),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rokProdukcjiController,
                decoration: const InputDecoration(
                  labelText: 'Rok produkcji',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _typController,
                decoration: const InputDecoration(
                  labelText: 'Typ (np. GBA, GCBA)',
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pojemnoscZbiornika,
                decoration: const InputDecoration(
                  labelText: 'Pojemność zbiornika (L)',
                  prefixIcon: Icon(Icons.water_drop),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _uwagiController,
                decoration: const InputDecoration(
                  labelText: 'Uwagi',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _ladowanie ? null : () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        ElevatedButton(
          onPressed: _ladowanie ? null : _zapisz,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
          ),
          child: _ladowanie
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Zapisz'),
        ),
      ],
    );
  }

  Future<void> _zapisz() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _ladowanie = true);

    try {
      final wozData = {
        'nazwa': _nazwaController.text.trim(),
        'numerRejestracyjny': _numerRejestracyjnyController.text.trim().isEmpty
            ? null
            : _numerRejestracyjnyController.text.trim(),
        'marka': _markaController.text.trim().isEmpty
            ? null
            : _markaController.text.trim(),
        'model': _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
        'rokProdukcji': _rokProdukcjiController.text.trim().isEmpty
            ? null
            : int.tryParse(_rokProdukcjiController.text.trim()),
        'typ': _typController.text.trim().isEmpty
            ? null
            : _typController.text.trim(),
        'pojemnoscZbiornika': _pojemnoscZbiornika.text.trim().isEmpty
            ? null
            : int.tryParse(_pojemnoscZbiornika.text.trim()),
        'uwagi': _uwagiController.text.trim().isEmpty
            ? null
            : _uwagiController.text.trim(),
        'aktywny': widget.woz?.aktywny ?? true,
      };

      if (widget.woz == null) {
        await FirebaseFirestore.instance.collection('wozy').add(wozData);
      } else {
        await FirebaseFirestore.instance
            .collection('wozy')
            .doc(widget.woz!.id)
            .update(wozData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.woz == null
                ? 'Wóz dodany'
                : 'Wóz zaktualizowany'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _ladowanie = false);
    }
  }
}
