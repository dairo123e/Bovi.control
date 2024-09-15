import 'package:flutter/material.dart';
import 'menu.dart';
import 'registro.dart';
// Importaciones de Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  // Asegurarse de que los bindings de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Ejecutar la aplicación
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Material App',
      home: Scaffold(body: Builder(
        builder: (BuildContext context) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Bovi_Control',
                        style: TextStyle(
                          color: Color.fromARGB(255, 74, 212, 53),
                          fontSize: 70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        'Tus animales merecen lo mejor',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                    )
                  ],
                ),
                Image.asset('assets/logo bovi control.jpg'),
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => MenuPage()),
                        );
                        final snackBar = SnackBar(
                            content: Text('Sessión Iniciada Correctamente'));
                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                      },
                      child: Text('Iniciar Sesión'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 104, 209, 117),
                          padding: EdgeInsets.symmetric(
                              horizontal: 100, vertical: 20),
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          )),
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => RegistroPage()),
                        );
                        final snackBar =
                            SnackBar(content: Text('Pagina de Registro'));
                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                      },
                      child: Text('Registrate',
                          style: TextStyle(color: Colors.green)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          side: BorderSide(color: Colors.green),
                          padding: EdgeInsets.symmetric(
                              horizontal: 100, vertical: 20),
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          )),
                    )
                  ],
                )
              ],
            ),
          );
        },
      )),
    );
  }
}
