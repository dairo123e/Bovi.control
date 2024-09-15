import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

class PerfilPage extends StatefulWidget {
  @override
  _PerfilPageState createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  XFile? _image;
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _fincaController = TextEditingController();
  final TextEditingController _ubicacionController = TextEditingController();
  final TextEditingController _ganadoController = TextEditingController();
  final TextEditingController _tipoController = TextEditingController();

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _image = image;
      });
    }
  }

  Future<void> _guardarPerfil() async {
    // Aquí guardamos los datos en Cloud Firestore
    try {
      await FirebaseFirestore.instance.collection('perfiles').add({
        'nombre_ganadero': _nombreController.text,
        'nombre_finca': _fincaController.text,
        'ubicacion_finca': _ubicacionController.text,
        'numero_cabezas': _ganadoController.text,
        'tipo_ganado': _tipoController.text,
        // Opcionalmente puedes guardar la ruta de la imagen
        'imagen': _image != null ? _image!.path : null,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Perfil guardado exitosamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar perfil: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Perfil del Ganadero'),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.green[200],
                backgroundImage:
                    _image != null ? FileImage(File(_image!.path)) : null,
                child: _image == null
                    ? Icon(
                        Icons.add_a_photo,
                        color: Colors.white,
                        size: 50,
                      )
                    : null,
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _nombreController,
              decoration: InputDecoration(
                labelText: "Nombre del Ganadero",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.green[50],
                labelStyle: TextStyle(color: Colors.green[800]),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green[800]!),
                ),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _fincaController,
              decoration: InputDecoration(
                labelText: "Nombre de la Finca",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.green[50],
                labelStyle: TextStyle(color: Colors.green[800]),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green[800]!),
                ),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _ubicacionController,
              decoration: InputDecoration(
                labelText: "Ubicación de la Finca",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.green[50],
                labelStyle: TextStyle(color: Colors.green[800]),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green[800]!),
                ),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _ganadoController,
              decoration: InputDecoration(
                labelText: "Número de Cabezas de Ganado",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.green[50],
                labelStyle: TextStyle(color: Colors.green[800]),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green[800]!),
                ),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _tipoController,
              decoration: InputDecoration(
                labelText: "Tipo de Ganado",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.green[50],
                labelStyle: TextStyle(color: Colors.green[800]),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green[800]!),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _guardarPerfil,
              child: Text('Guardar Perfil'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                minimumSize: Size(double.infinity, 50),
                textStyle: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
