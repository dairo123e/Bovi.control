import 'package:flutter/material.dart';

class NotificacionesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notificaciones Ganaderas'),
        backgroundColor: Colors.green,
      ),
      body: ListView(
        padding: EdgeInsets.all(10.0),
        children: [
          _buildNotificationCard(
            context,
            titulo: 'Vacuna pendiente',
            descripcion: 'La vaca #23 necesita su vacuna anual.',
            numeroVaca: '23',
            raza: 'Holstein',
            edad: '4',
            estadoSalud: 'Buena',
          ),
          _buildNotificationCard(
            context,
            titulo: 'Revisión de producción',
            descripcion: 'Revisar producción de leche de la vaca #45.',
            numeroVaca: '45',
            raza: 'Jersey',
            edad: '5',
            estadoSalud: 'Regular',
          ),
          _buildNotificationCard(
            context,
            titulo: 'Alerta de parto',
            descripcion: 'Vaca #12 está por dar a luz en las próximas horas.',
            numeroVaca: '12',
            raza: 'Simmental',
            edad: '6',
            estadoSalud: 'Atención especial',
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context,
      {required String titulo,
      required String descripcion,
      required String numeroVaca,
      required String raza,
      required String edad,
      required String estadoSalud}) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.notifications_active, color: Colors.green),
        title: Text(titulo),
        subtitle: Text(descripcion),
        trailing: Icon(Icons.arrow_forward),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetalleNotificacionPage(
                titulo: titulo,
                descripcion: descripcion,
                numeroVaca: numeroVaca,
                raza: raza,
                edad: edad,
                estadoSalud: estadoSalud,
              ),
            ),
          );
        },
      ),
    );
  }
}

class DetalleNotificacionPage extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final String numeroVaca;
  final String raza;
  final String edad;
  final String estadoSalud;

  DetalleNotificacionPage({
    required this.titulo,
    required this.descripcion,
    required this.numeroVaca,
    required this.raza,
    required this.edad,
    required this.estadoSalud,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle de Notificación'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              descripcion,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Divider(),
            Text(
              "Información de la Vaca",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text("Número: $numeroVaca", style: TextStyle(fontSize: 18)),
            Text("Raza: $raza", style: TextStyle(fontSize: 18)),
            Text("Edad: $edad años", style: TextStyle(fontSize: 18)),
            Text("Estado de salud: $estadoSalud",
                style: TextStyle(fontSize: 18, color: Colors.green)),
          ],
        ),
      ),
    );
  }
}
