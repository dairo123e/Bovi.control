import 'package:flutter/material.dart';

class EventosTareasPage extends StatefulWidget {
  @override
  _EventosTareasPageState createState() => _EventosTareasPageState();
}

class _EventosTareasPageState extends State<EventosTareasPage> {
  final _formKey = GlobalKey<FormState>();
  String? _tipo;
  String? _descripcion;
  DateTime? _fecha;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Eventos y Tareas'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Registrar Evento o Tarea',
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      value: _tipo,
                      items: [
                        DropdownMenuItem(
                            value: 'Feria Ganadera',
                            child: Text('Feria Ganadera')),
                        DropdownMenuItem(
                            value: 'Vacunación', child: Text('Vacunación')),
                        DropdownMenuItem(
                            value: 'Purgar', child: Text('Purgar')),
                        DropdownMenuItem(
                            value: 'Fumigar', child: Text('Fumigar')),
                        DropdownMenuItem(
                            value: 'Aplicación de complejos vitaminicos',
                            child: Text('Aplicación de complejos vitaminicos')),
                        DropdownMenuItem(
                            value: 'Alimentar', child: Text('Alimentar')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _tipo = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Tipo de Evento o Tarea',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.green.shade50,
                      ),
                      validator: (value) =>
                          value == null ? 'Por favor selecciona un tipo' : null,
                    ),
                    SizedBox(height: 16.0),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.green.shade50,
                      ),
                      onSaved: (value) {
                        _descripcion = value;
                      },
                    ),
                    SizedBox(height: 16.0),
                    ElevatedButton.icon(
                      icon: Icon(Icons.date_range),
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2101),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.green,
                                  onPrimary: Colors.white,
                                  onSurface: Colors.green,
                                ),
                                textButtonTheme: TextButtonThemeData(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.green,
                                  ),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null && picked != _fecha) {
                          setState(() {
                            _fecha = picked;
                          });
                        }
                      },
                      label: Text('Seleccionar Fecha'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: Size(double.infinity, 50),
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
                                    'Evento/Tarea guardado: $_tipo - $_descripcion en la fecha: ${_fecha?.toLocal().toShortDateString()}'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        child: Text('Guardar Evento/Tarea'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(
                              horizontal: 40, vertical: 22),
                          textStyle: TextStyle(fontSize: 16.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.0),
                  ],
                ),
              ),
            ),
          ),
          Container(
            color: Colors.white, // Color de fondo para el logo
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Image.asset(
                'assets/logo bovi control.jpg',
                fit: BoxFit.contain, // Mantiene la proporción del logo
                height: 150, // Ajusta la altura del logo según sea necesario
                width: 150, // Ajusta el ancho del logo según sea necesario
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension DateExtension on DateTime {
  String toShortDateString() {
    return "${this.day}/${this.month}/${this.year}";
  }
}
