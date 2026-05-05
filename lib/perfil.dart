import 'dart:typed_data';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'config/app_config.dart';
import 'services/offline_outbox_service.dart';
import 'widgets/ui/app_background.dart';
import 'widgets/ui/section_title.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({Key? key}) : super(key: key);

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  // ====== TUS CONTROLADORES ORIGINALES ======
  XFile? _image;
  Uint8List? _imageBytes;
  String? _photoUrl;
  String? _photoBase64;
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _fincaController = TextEditingController();
  final TextEditingController _ubicacionController = TextEditingController();
  final TextEditingController _ganadoController = TextEditingController();
  final TextEditingController _tipoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _fincaController.dispose();
    _ubicacionController.dispose();
    _ganadoController.dispose();
    _tipoController.dispose();
    super.dispose();
  }

  // ====== TUS MÉTODOS ORIGINALES ======
  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _image = image;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _cargarPerfil() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .doc('tenants/$kTenantId/users/${user.uid}')
          .get();
      final data = doc.data();
      if (data == null) return;

      final perfil = (data['perfil'] as Map<String, dynamic>?) ?? {};
      _photoUrl = (data['photoUrl'] ?? data['fotoUrl'] ?? '').toString();
      _photoBase64 = (data['photoBase64'] ?? '').toString();

      _nombreController.text = (perfil['nombreGanadero'] ??
              data['displayName'] ??
              user.displayName ??
              '')
          .toString();
      _fincaController.text = (perfil['nombreFinca'] ?? '').toString();
      _ubicacionController.text = (perfil['ubicacionFinca'] ?? '').toString();
      _ganadoController.text = (perfil['numeroCabezas'] ?? '').toString();
      _tipoController.text = (perfil['tipoGanado'] ?? '').toString();

      if (mounted) setState(() {});
    } catch (_) {
      // Si falla la lectura, permitimos igualmente edición local.
    }
  }

  Future<void> _guardarPerfil() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para guardar.')),
      );
      return;
    }

    try {
      String? nextPhotoUrl;
      String? nextPhotoBase64;
      if (_imageBytes != null) {
        if (_imageBytes!.lengthInBytes > 380000) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La foto es muy pesada. Elige una imagen mas liviana.',
              ),
            ),
          );
          return;
        }
        nextPhotoBase64 = base64Encode(_imageBytes!);
        nextPhotoUrl = '';
      }

      await FirebaseFirestore.instance
          .doc('tenants/$kTenantId/users/${user.uid}')
          .set({
        'displayName': _nombreController.text.trim(),
        if (nextPhotoUrl != null) 'photoUrl': nextPhotoUrl,
        if (nextPhotoBase64 != null) 'photoBase64': nextPhotoBase64,
        'updatedAt': FieldValue.serverTimestamp(),
        'perfil': {
          'nombreGanadero': _nombreController.text.trim(),
          'nombreFinca': _fincaController.text.trim(),
          'ubicacionFinca': _ubicacionController.text.trim(),
          'numeroCabezas': int.tryParse(_ganadoController.text.trim()) ?? 0,
          'tipoGanado': _tipoController.text.trim(),
        },
      }, SetOptions(merge: true));

      if (nextPhotoUrl != null) {
        setState(() {
          _photoUrl = nextPhotoUrl;
          _photoBase64 = nextPhotoBase64 ?? _photoBase64;
          _image = null;
          _imageBytes = null;
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Perfil guardado exitosamente')),
      );
    } catch (e) {
      String? nextPhotoUrl;
      String? nextPhotoBase64;
      if (_imageBytes != null) {
        nextPhotoBase64 = base64Encode(_imageBytes!);
        nextPhotoUrl = '';
      }

      await OfflineOutboxService.instance.enqueuePerfilUpdate(
        uid: user.uid,
        displayName: _nombreController.text.trim(),
        nombreGanadero: _nombreController.text.trim(),
        nombreFinca: _fincaController.text.trim(),
        ubicacionFinca: _ubicacionController.text.trim(),
        numeroCabezas: int.tryParse(_ganadoController.text.trim()) ?? 0,
        tipoGanado: _tipoController.text.trim(),
        photoUrl: nextPhotoUrl,
        photoBase64: nextPhotoBase64,
      );

      if (nextPhotoUrl != null) {
        setState(() {
          _photoUrl = nextPhotoUrl;
          _photoBase64 = nextPhotoBase64 ?? _photoBase64;
          _image = null;
          _imageBytes = null;
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil guardado localmente. Se sincronizara.'),
        ),
      );
    }
  }

  // ====== HELPERS UI ======
  InputDecoration _dec(String label, {IconData? icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon:
          icon != null ? Icon(icon, color: Colors.green.shade700) : null,
      filled: true,
      fillColor: Colors.green.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.green.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.green.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.green.shade700, width: 1.6),
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 4,
      shadowColor: Colors.green.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(text: title),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _pill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // Chips para tipo de ganado (rellena _tipoController)
  Widget _tipoChips() {
    final opciones = ['Carne', 'Leche', 'Mixto'];
    final sel = _tipoController.text;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opciones.map((op) {
        final isSel = sel == op;
        return ChoiceChip(
          label: Text(op),
          selected: isSel,
          onSelected: (_) => setState(() => _tipoController.text = op),
          selectedColor: Colors.green.shade600,
          labelStyle: TextStyle(
            color: isSel ? Colors.white : Colors.green.shade900,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: Colors.green.shade50,
          shape: RoundedRectangleBorder(
            side: BorderSide(
                color: isSel ? Colors.green.shade600 : Colors.green.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }).toList(),
    );
  }

  // Stepper para número de cabezas (actualiza _ganadoController)
  Widget _cabezasStepper() {
    int value = int.tryParse(_ganadoController.text.trim()) ?? 0;
    void setVal(int v) {
      value = v < 0 ? 0 : v;
      _ganadoController.text = value.toString();
      setState(() {});
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ganadoController,
            keyboardType: TextInputType.number,
            decoration: _dec('Número de Cabezas', icon: Icons.numbers),
          ),
        ),
        const SizedBox(width: 10),
        _roundBtn(Icons.remove, onTap: () => setVal(value - 1)),
        const SizedBox(width: 8),
        _roundBtn(Icons.add, onTap: () => setVal(value + 1)),
      ],
    );
  }

  Widget _roundBtn(IconData icon, {required VoidCallback onTap}) {
    return InkResponse(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))
          ],
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  // ====== UI ======
  ImageProvider<Object>? _avatarProvider() {
    if (_imageBytes != null) {
      return MemoryImage(_imageBytes!);
    }
    if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(_photoBase64!));
      } catch (_) {
        // si falla decode, intenta con URL
      }
    }
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return NetworkImage(_photoUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Ganadero'),
      ),
      body: AppBackground(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                children: [
                  // Avatar
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withOpacity(.25),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                )
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 56,
                              backgroundColor: Colors.white,
                              backgroundImage: _avatarProvider(),
                              child: (_image == null &&
                                      (_photoUrl == null ||
                                          _photoUrl!.isEmpty) &&
                                      (_photoBase64 == null ||
                                          _photoBase64!.isEmpty) &&
                                      _imageBytes == null)
                                  ? Icon(Icons.photo_camera_outlined,
                                      color: primary, size: 28)
                                  : null,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 8)
                              ],
                            ),
                            child: Icon(Icons.edit, size: 18, color: primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Chips resumen
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(
                        icon: Icons.person,
                        text: _nombreController.text.isEmpty
                            ? 'Ganadero'
                            : _nombreController.text,
                      ),
                      _pill(
                        icon: Icons.home_filled,
                        text: _fincaController.text.isEmpty
                            ? 'Finca'
                            : _fincaController.text,
                      ),
                      _pill(
                        icon: Icons.location_on,
                        text: _ubicacionController.text.isEmpty
                            ? 'Ubicación'
                            : _ubicacionController.text,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Seccion: Datos del Ganadero
                  _sectionCard(
                    title: 'Datos del Ganadero',
                    children: [
                      TextField(
                        controller: _nombreController,
                        decoration:
                            _dec('Nombre del Ganadero', icon: Icons.person),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Seccion: Datos de la Finca
                  _sectionCard(
                    title: 'Datos de la Finca',
                    children: [
                      TextField(
                        controller: _fincaController,
                        decoration:
                            _dec('Nombre de la Finca', icon: Icons.home_filled),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _ubicacionController,
                        decoration: _dec('Ubicación de la Finca',
                            icon: Icons.location_on,
                            hint: 'Vereda / Municipio'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Seccion: Produccion
                  _sectionCard(
                    title: 'Producción',
                    children: [
                      _cabezasStepper(),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _tipoController,
                        readOnly: true,
                        decoration: _dec('Tipo de Ganado',
                            icon: Icons.category, hint: 'Selecciona abajo'),
                      ),
                      const SizedBox(height: 10),
                      _tipoChips(),
                    ],
                  ),
                ],
              ),
            ),

            // Boton guardar fijo
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
              child: ElevatedButton.icon(
                onPressed: _guardarPerfil,
                icon: const Icon(Icons.save_alt),
                label: const Text('Guardar Perfil'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
