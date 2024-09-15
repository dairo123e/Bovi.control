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
        title: Text('Tus Fincas'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Registrar Finca',
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 16.0),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  color: Colors.grey.shade200,
                  height: 200,
                  width: double.infinity,
                  child: _imageFile == null
                      ? Center(child: Text('Selecciona una imagen'))
                      : Image.file(_imageFile!, fit: BoxFit.cover),
                ),
              ),
              SizedBox(height: 16.0),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Nombre de la Finca',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.green.shade50,
                ),
                onSaved: (value) {
                  _nombreFinca = value;
                },
                validator: (value) => value == null || value.isEmpty
                    ? 'Por favor ingresa el nombre'
                    : null,
              ),
              SizedBox(height: 16.0),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Ubicación Geográfica',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.green.shade50,
                ),
                onSaved: (value) {
                  _ubicacionGeografica = value;
                },
                validator: (value) => value == null || value.isEmpty
                    ? 'Por favor ingresa la ubicación'
                    : null,
              ),
              SizedBox(height: 16.0),
              Text(
                'Lotes de la Finca',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 8.0),
              ..._lotes.map((lote) {
                return ListTile(
                  title: Text(lote),
                  subtitle: Text('Vacas: ${_vacassPorLote[lote] ?? 0}'),
                );
              }).toList(),
              ElevatedButton(
                onPressed: () {
                  _showAddLoteDialog();
                },
                child: Text('Agregar Lote'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
              SizedBox(height: 16.0),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState?.validate() == true) {
                      _formKey.currentState?.save();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Finca guardada: $_nombreFinca, $_ubicacionGeografica'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: Text('Guardar Finca'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    textStyle: TextStyle(fontSize: 16.0),
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
          title: Text('Agregar Lote'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Nombre del Lote',
                ),
                onChanged: (value) {
                  lote = value;
                },
              ),
              SizedBox(height: 8.0),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Cantidad de Vacas',
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
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _lotes.add(lote);
                  _vacassPorLote[lote] = vacas;
                });
                Navigator.of(context).pop();
              },
              child: Text('Agregar'),
            ),
          ],
        );
      },
    );
  }
}
