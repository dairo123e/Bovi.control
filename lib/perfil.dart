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
    try {
      await FirebaseFirestore.instance.collection('perfiles').add({
        'nombre_ganadero': _nombreController.text,
        'nombre_finca': _fincaController.text,
        'ubicacion_finca': _ubicacionController.text,
        'numero_cabezas': _ganadoController.text,
        'tipo_ganado': _tipoController.text,
        'imagen': _image != null ? _image!.path : null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Perfil guardado exitosamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al guardar perfil: $e')),
      );
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon:
              icon != null ? Icon(icon, color: Colors.green[800]) : null,
          labelText: label,
          filled: true,
          fillColor: Colors.green[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          labelStyle: TextStyle(color: Colors.green[900]),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green[800]!),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[100]!, Colors.green[50]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Perfil del Ganadero',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                SizedBox(height: 16),

                // Avatar de perfil
                GestureDetector(
                  onTap: _pickImage,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade200,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.green[200],
                      backgroundImage:
                          _image != null ? FileImage(File(_image!.path)) : null,
                      child: _image == null
                          ? Icon(Icons.add_a_photo,
                              color: Colors.white, size: 40)
                          : null,
                    ),
                  ),
                ),

                SizedBox(height: 20),
                Divider(thickness: 1.5, color: Colors.green[200]),

                // Card con los campos
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                  color: Colors.white.withOpacity(0.95),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildTextField(
                          label: "Nombre del Ganadero",
                          controller: _nombreController,
                          icon: Icons.person,
                        ),
                        _buildTextField(
                          label: "Nombre de la Finca",
                          controller: _fincaController,
                          icon: Icons.home_filled,
                        ),
                        _buildTextField(
                          label: "Ubicación de la Finca",
                          controller: _ubicacionController,
                          icon: Icons.location_on,
                        ),
                        _buildTextField(
                          label: "Número de Cabezas de Ganado",
                          controller: _ganadoController,
                          keyboardType: TextInputType.number,
                          icon: Icons.numbers,
                        ),
                        _buildTextField(
                          label: "Tipo de Ganado",
                          controller: _tipoController,
                          icon: Icons.category,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Botón guardar
                ElevatedButton.icon(
                  onPressed: _guardarPerfil,
                  icon: Icon(Icons.save_alt),
                  label: Text('Guardar Perfil'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    minimumSize: Size(double.infinity, 50),
                    textStyle: TextStyle(fontSize: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
