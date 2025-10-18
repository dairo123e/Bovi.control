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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade100, Colors.green.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              // Título y formulario
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Center(
                          child: Text(
                            'Registrar Evento o Tarea',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                        SizedBox(height: 24.0),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.2),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                value: _tipo,
                                items: [
                                  'Feria Ganadera',
                                  'Vacunación',
                                  'Purgar',
                                  'Fumigar',
                                  'Aplicación de complejos vitaminicos',
                                  'Alimentar',
                                ]
                                    .map((item) => DropdownMenuItem(
                                          value: item,
                                          child: Text(item),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => _tipo = value);
                                },
                                decoration: InputDecoration(
                                  labelText: 'Tipo de Evento o Tarea',
                                  prefixIcon:
                                      Icon(Icons.event, color: Colors.green),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.green.shade50,
                                ),
                                validator: (value) => value == null
                                    ? 'Por favor selecciona un tipo'
                                    : null,
                              ),
                              SizedBox(height: 16.0),
                              TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Descripción',
                                  prefixIcon: Icon(Icons.description,
                                      color: Colors.green),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.green.shade50,
                                ),
                                maxLines: 2,
                                onSaved: (value) => _descripcion = value,
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Ingresa una descripción'
                                        : null,
                              ),
                              SizedBox(height: 16.0),
                              ElevatedButton.icon(
                                icon: Icon(Icons.date_range),
                                label: Text(
                                  _fecha != null
                                      ? 'Fecha: ${_fecha!.toShortDateString()}'
                                      : 'Seleccionar Fecha',
                                ),
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
                                  if (picked != null) {
                                    setState(() => _fecha = picked);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  minimumSize: Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              SizedBox(height: 24.0),
                              ElevatedButton.icon(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    _formKey.currentState!.save();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '✅ Guardado: $_tipo - $_descripcion\n📅 ${_fecha?.toShortDateString() ?? "Sin fecha"}',
                                        ),
                                        backgroundColor: Colors.green.shade700,
                                      ),
                                    );
                                  }
                                },
                                icon: Icon(Icons.save),
                                label: Text('Guardar Evento/Tarea'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade800,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  minimumSize: Size(double.infinity, 50),
                                  textStyle: TextStyle(fontSize: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Logo abajo
              Container(
                color: Colors.white,
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Image.asset(
                    'assets/logo bovi control.jpg',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension DateExtension on DateTime {
  String toShortDateString() {
    return "${this.day}/${this.month}/${this.year}";
  }
}
