import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class TusFincasPage extends StatefulWidget {
  @override
  _TusFincasPageState createState() => _TusFincasPageState();
}

class _TusFincasPageState extends State<TusFincasPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  File? _imageFile;
  String? _nombreFinca;
  String? _ubicacionGeografica;
  List<String> _lotes = [];
  Map<String, int> _vacassPorLote = {};

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tus Fincas'),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Registrar Finca',
                style: TextStyle(
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16.0),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: _imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.image, size: 50, color: Colors.grey),
                            SizedBox(height: 10),
                            Text(
                              'Toca para seleccionar una imagen',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: Image.file(
                            _imageFile!,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Nombre de la Finca',
                  prefixIcon: const Icon(Icons.home_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.green.shade50,
                ),
                onSaved: (value) {
                  _nombreFinca = value;
                },
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingresa el nombre' : null,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Ubicación Geográfica',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.green.shade50,
                ),
                onSaved: (value) {
                  _ubicacionGeografica = value;
                },
                validator: (value) => value == null || value.isEmpty
                    ? 'Ingresa la ubicación'
                    : null,
              ),
              const SizedBox(height: 24.0),
              const Text(
                'Lotes de la Finca',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 10.0),
              ..._lotes.map((lote) {
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  color: Colors.green.shade50,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.agriculture),
                    title: Text(lote),
                    subtitle: Text('Vacas: ${_vacassPorLote[lote] ?? 0}'),
                  ),
                );
              }).toList(),
              const SizedBox(height: 10),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _showAddLoteDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar Lote'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_formKey.currentState?.validate() == true) {
                      _formKey.currentState?.save();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Finca guardada: $_nombreFinca, $_ubicacionGeografica',
                          ),
                          backgroundColor: Colors.green.shade600,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Guardar Finca'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                    textStyle: const TextStyle(fontSize: 16.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddLoteDialog() {
    String lote = '';
    int vacas = 0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Agregar Lote'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Nombre del Lote',
                  prefixIcon: Icon(Icons.edit_location),
                ),
                onChanged: (value) {
                  lote = value;
                },
              ),
              const SizedBox(height: 8.0),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Cantidad de Vacas',
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  vacas = int.tryParse(value) ?? 0;
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (lote.isNotEmpty) {
                    _lotes.add(lote);
                    _vacassPorLote[lote] = vacas;
                  }
                });
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }
}
