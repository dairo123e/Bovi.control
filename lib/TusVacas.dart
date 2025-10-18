import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class TusVacasPage extends StatefulWidget {
  @override
  _TusVacasPageState createState() => _TusVacasPageState();
}

class _TusVacasPageState extends State<TusVacasPage> {
  final _formKey = GlobalKey<FormState>();
  final List<Map<String, dynamic>> _vacas = [];

  String? _nombre;
  String? _raza;
  DateTime? _fechaNacimiento;
  int? _cantidadPartos;
  double? _promedioProduccion;
  String? _vacunas;
  File? _image;

  final TextEditingController _fechaController = TextEditingController();

  @override
  void dispose() {
    _fechaController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _saveVaca() {
    if (_formKey.currentState?.validate() == true) {
      _formKey.currentState?.save();

      setState(() {
        _vacas.add({
          'nombre': _nombre,
          'raza': _raza,
          'fechaNacimiento': _fechaNacimiento,
          'cantidadPartos': _cantidadPartos,
          'promedioProduccion': _promedioProduccion,
          'vacunas': _vacunas,
          'image': _image,
        });

        _fechaNacimiento = null;
        _fechaController.clear();
        _image = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vaca registrada exitosamente')),
      );

      _formKey.currentState?.reset();
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.green[700]),
      filled: true,
      fillColor: Colors.green[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tus Vacas'),
        backgroundColor: Colors.green[700],
        elevation: 5,
        shadowColor: Colors.greenAccent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registrar Nueva Vaca',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800]),
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    decoration: _buildInputDecoration('Nombre', Icons.pets),
                    onSaved: (value) => _nombre = value,
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Ingrese un nombre'
                        : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    decoration: _buildInputDecoration('Raza', Icons.list_alt),
                    onSaved: (value) => _raza = value,
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Ingrese la raza'
                        : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _fechaController,
                    readOnly: true,
                    decoration: _buildInputDecoration(
                        'Fecha de Nacimiento', Icons.calendar_today),
                    onTap: () async {
                      FocusScope.of(context).requestFocus(FocusNode());
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.green[700]!,
                              onPrimary: Colors.white,
                              onSurface: Colors.green[700]!,
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.green[700],
                              ),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _fechaNacimiento = pickedDate;
                          _fechaController.text =
                              "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                        });
                      }
                    },
                    validator: (value) => (_fechaNacimiento == null)
                        ? 'Seleccione una fecha'
                        : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    decoration: _buildInputDecoration(
                        'Cantidad de Partos', Icons.numbers),
                    keyboardType: TextInputType.number,
                    onSaved: (value) =>
                        _cantidadPartos = int.tryParse(value ?? '0'),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Ingrese cantidad'
                        : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    decoration: _buildInputDecoration(
                        'Promedio de Producción', Icons.local_drink),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    onSaved: (value) =>
                        _promedioProduccion = double.tryParse(value ?? '0'),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Ingrese promedio'
                        : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    decoration: _buildInputDecoration(
                        'Vacunas', Icons.medical_services),
                    onSaved: (value) => _vacunas = value,
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Ingrese vacunas'
                        : null,
                  ),
                  SizedBox(height: 20),
                  _image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(_image!,
                              height: 150, width: 150, fit: BoxFit.cover),
                        )
                      : Text(
                          'No se ha seleccionado ninguna imagen',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: Icon(Icons.image),
                    label: Text('Seleccionar Imagen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding:
                          EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                  ),
                  SizedBox(height: 30),
                  Center(
                    child: ElevatedButton(
                      onPressed: _saveVaca,
                      child: Text('Registrar Vaca',
                          style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[800],
                        padding:
                            EdgeInsets.symmetric(horizontal: 60, vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 6,
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                ],
              ),
            ),
            Divider(color: Colors.green[300], thickness: 2),
            SizedBox(height: 10),
            Text(
              'Vacas Registradas',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800]),
            ),
            SizedBox(height: 16),
            _vacas.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No hay vacas registradas aún.',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _vacas.length,
                    itemBuilder: (context, index) {
                      final vaca = _vacas[index];
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 10, horizontal: 16),
                          leading: vaca['image'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: Image.file(vaca['image'],
                                      width: 60, height: 60, fit: BoxFit.cover),
                                )
                              : CircleAvatar(
                                  backgroundColor: Colors.green[200],
                                  child: Icon(Icons.pets,
                                      color: Colors.green[700]),
                                  radius: 30,
                                ),
                          title: Text(vaca['nombre'] ?? '',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Raza: ${vaca['raza']}"),
                              Text(
                                  "Fecha Nac: ${vaca['fechaNacimiento']?.day}/${vaca['fechaNacimiento']?.month}/${vaca['fechaNacimiento']?.year}"),
                              Text("Partos: ${vaca['cantidadPartos']}"),
                              Text("Promedio: ${vaca['promedioProduccion']} L"),
                              Text("Vacunas: ${vaca['vacunas']}"),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
