import 'package:flutter/material.dart';
import 'menu.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistroPage extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();

  // Controladores para capturar los datos del formulario
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registro'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(labelText: 'Nombre de usuario'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Por favor ingresa tu nombre de usuario';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _correoController,
                decoration: InputDecoration(labelText: 'Correo electrónico'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Por favor ingresa tu correo electrónico';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Por favor ingresa tu contraseña';
                  }
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Procesando Datos')),
                      );

                      // Guardar los datos en Firestore
                      try {
                        await FirebaseFirestore.instance
                            .collection('usuarios')
                            .add({
                          'nombre': _nombreController.text,
                          'correo': _correoController.text,
                          'password': _passwordController
                              .text, // No se recomienda guardar la contraseña en texto plano
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Registro exitoso')),
                        );

                        Future.delayed(Duration(seconds: 3), () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => MenuPage()),
                          );
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al registrar: $e')),
                        );
                      }
                    }
                  },
                  child: Text('Registrarse'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
