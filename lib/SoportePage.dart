import 'package:flutter/material.dart';

class SoportePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contacto y Soporte'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "¿Necesitas ayuda?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Si tienes dudas o necesitas soporte, contáctanos a través de los siguientes medios:",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),

            // Opción para enviar un correo
            ListTile(
              leading: Icon(Icons.email, color: Colors.green),
              title: Text("Correo electrónico"),
              subtitle: Text("dairoquintana023@gmail.com"),
              onTap: () {
                // Acción para enviar un correo
              },
            ),

            // Opción para llamar
            ListTile(
              leading: Icon(Icons.phone, color: Colors.green),
              title: Text("Teléfonos"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("+57 321 3250 580"),
                  Text("+57 320 2095 991"),
                ],
              ),
              onTap: () {
                // Acción para llamar
              },
            ),

            // Opción para abrir el chat en vivo
            ListTile(
              leading: Icon(Icons.chat, color: Colors.green),
              title: Text("Chat en vivo"),
              subtitle: Text("Disponible en nuestra app"),
              onTap: () {
                // Acción para abrir chat en vivo
              },
            ),
          ],
        ),
      ),
    );
  }
}
