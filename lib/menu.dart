import 'package:flutter/material.dart';
import 'perfil.dart';
import 'EventosTareasPage.dart';
import 'TusVacas.dart';
import 'TusFincas.dart';
import 'Notificaciones.dart';
import 'SoportePage.dart';

class MenuPage extends StatelessWidget {
  final List<_MenuOption> menuOptions = [
    _MenuOption("Perfil", Icons.person, Colors.blue, PerfilPage()),
    _MenuOption(
        "Eventos y Tareas", Icons.event, Colors.orange, EventosTareasPage()),
    _MenuOption("Tus Vacas", Icons.pets, Colors.brown, TusVacasPage()),
    _MenuOption("Tus Fincas", Icons.landscape, Colors.teal, TusFincasPage()),
    _MenuOption("Notificaciones", Icons.notifications, Colors.red,
        NotificacionesPage()),
    _MenuOption("Soporte", Icons.support_agent, Colors.purple, SoportePage()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú Principal'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                labelText: "Buscar en el menú...",
                prefixIcon: Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: menuOptions
                  .map((option) => _buildCard(context, option))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, _MenuOption option) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => option.page));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green[100], // Verde claro de fondo
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.2),
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(option.icon, size: 50, color: option.color),
            const SizedBox(height: 10),
            Text(
              option.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green[900],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuOption {
  final String title;
  final IconData icon;
  final Color color;
  final Widget page;

  _MenuOption(this.title, this.icon, this.color, this.page);
}
