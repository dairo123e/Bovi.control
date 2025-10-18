import 'package:flutter/material.dart';

class NotificacionesPage extends StatelessWidget {
  final Color verdeClaro = const Color(0xFFA5D6A7);
  final Color verdeFuerte = const Color(0xFF388E3C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones Ganaderas'),
        backgroundColor: verdeFuerte,
        elevation: 4,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildNotificationCard(
            context,
            icono: Icons.vaccines,
            colorIcono: Colors.orange,
            titulo: 'Vacuna pendiente',
            descripcion: 'La vaca #23 necesita su vacuna anual.',
            numeroVaca: '23',
            raza: 'Holstein',
            edad: '4',
            estadoSalud: 'Buena',
          ),
          _buildNotificationCard(
            context,
            icono: Icons.local_drink,
            colorIcono: Colors.blue,
            titulo: 'Revisión de producción',
            descripcion: 'Revisar producción de leche de la vaca #45.',
            numeroVaca: '45',
            raza: 'Jersey',
            edad: '5',
            estadoSalud: 'Regular',
          ),
          _buildNotificationCard(
            context,
            icono: Icons.warning_amber,
            colorIcono: Colors.redAccent,
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

  Widget _buildNotificationCard(
    BuildContext context, {
    required IconData icono,
    required Color colorIcono,
    required String titulo,
    required String descripcion,
    required String numeroVaca,
    required String raza,
    required String edad,
    required String estadoSalud,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.green.shade50,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        leading: CircleAvatar(
          backgroundColor: colorIcono.withOpacity(0.2),
          child: Icon(icono, color: colorIcono),
        ),
        title: Text(
          titulo,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        subtitle: Text(descripcion),
        trailing:
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.green),
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

  final Color verdeFuerte = const Color(0xFF388E3C);

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
        title: const Text('Detalle de Notificación'),
        backgroundColor: verdeFuerte,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  descripcion,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                const Divider(thickness: 1),
                const SizedBox(height: 10),
                const Text(
                  "Información de la Vaca",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
                const SizedBox(height: 10),
                _infoRow("Número:", numeroVaca),
                _infoRow("Raza:", raza),
                _infoRow("Edad:", "$edad años"),
                _infoRow("Estado de salud:", estadoSalud,
                    color: Colors.green.shade700),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text("$label ",
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
