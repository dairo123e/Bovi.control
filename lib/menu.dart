import 'package:flutter/material.dart';
import 'perfil.dart';
import 'EventosTareasPage.dart';
import 'TusVacas.dart';
import 'TusFincas.dart';
import 'Notificaciones.dart';
import 'SoportePage.dart'; // Nueva página de Contacto/Soporte

class MenuPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menú'),
        backgroundColor: Colors.green,
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              // Acciones futuras para el menú desplegable
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: <Widget>[
            // Campo de búsqueda
            TextField(
              decoration: InputDecoration(
                labelText: "Buscar",
                hintText: "Buscar",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(25.0)),
                ),
              ),
            ),
            SizedBox(height: 10),

            // Botón Perfil
            _buildMenuButton(
              context,
              icon: Icons.person,
              text: "Perfil",
              page: PerfilPage(),
            ),

            // Botón Eventos y Tareas
            _buildMenuButton(
              context,
              icon: Icons.event,
              text: "Eventos y Tareas",
              page: EventosTareasPage(),
            ),

            // Botón Tus Vacas
            _buildMenuButton(
              context,
              icon: Icons.pets,
              text: "Tus Vacas",
              page: TusVacasPage(),
            ),

            // Botón Tus Fincas
            _buildMenuButton(
              context,
              icon: Icons.landscape,
              text: "Tus Fincas",
              page: TusFincasPage(),
            ),

            // Botón Notificaciones
            _buildMenuButton(
              context,
              icon: Icons.notifications,
              text: "Notificaciones",
              page: NotificacionesPage(),
            ),

            // Botón Contacto/Soporte (Nuevo)
            _buildMenuButton(
              context,
              icon: Icons.support_agent,
              text: "Contacto/Soporte",
              page: SoportePage(),
            ),
          ],
        ),
      ),
    );
  }

  // Función para crear botones con un solo código reutilizable
  Widget _buildMenuButton(BuildContext context,
      {required IconData icon, required String text, required Widget page}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => page));
        },
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          minimumSize: Size(double.infinity, 50),
        ),
      ),
    );
  }
}
