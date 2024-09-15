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
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vaca registrada exitosamente')),
      );

      _formKey.currentState?.reset();
      _image = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tus Vacas'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registrar Nueva Vaca',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                      ),
                      onSaved: (value) {
                        _nombre = value;
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese un nombre';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Raza',
                        border: OutlineInputBorder(),
                      ),
                      onSaved: (value) {
                        _raza = value;
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese la raza';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Fecha de Nacimiento',
                        border: OutlineInputBorder(),
                      ),
                      onTap: () async {
                        FocusScope.of(context).requestFocus(FocusNode());
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _fechaNacimiento = pickedDate;
                          });
                        }
                      },
                      readOnly: true,
                      validator: (value) {
                        if (_fechaNacimiento == null) {
                          return 'Por favor seleccione una fecha';
                        }
                        return null;
                      },
                      controller: TextEditingController(
                        text: _fechaNacimiento != null
                            ? "${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}"
                            : '',
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Cantidad de Partos',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (value) {
                        _cantidadPartos = int.tryParse(value!);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese la cantidad de partos';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Promedio de Producción',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (value) {
                        _promedioProduccion = double.tryParse(value!);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese el promedio de producción';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Vacunas',
                        border: OutlineInputBorder(),
                      ),
                      onSaved: (value) {
                        _vacunas = value;
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese el registro de vacunas';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _image != null
                        ? Image.file(_image!, height: 150)
                        : Text('No se ha seleccionado ninguna imagen'),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.image),
                      label: Text('Seleccionar Imagen'),
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: _saveVaca,
                        child: Text('Registrar Vaca'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                          textStyle: TextStyle(fontSize: 16.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Vacas Registradas',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _vacas.length,
                itemBuilder: (context, index) {
                  final vaca = _vacas[index];
                  return Card(
                    child: ListTile(
                      leading: vaca['image'] != null
                          ? Image.file(vaca['image'], width: 50, height: 50)
                          : Icon(Icons.pets),
                      title: Text(vaca['nombre']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Raza: ${vaca['raza']}'),
                          Text(
                              'Fecha de Nacimiento: ${vaca['fechaNacimiento']?.day}/${vaca['fechaNacimiento']?.month}/${vaca['fechaNacimiento']?.year}'),
                          Text('Cantidad de Partos: ${vaca['cantidadPartos']}'),
                          Text(
                              'Promedio de Producción: ${vaca['promedioProduccion']} litros'),
                          Text('Vacunas: ${vaca['vacunas']}'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
