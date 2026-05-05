import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'widgets/role_picker_dialog.dart';
import 'utils/validators.dart';
import 'utils/nav.dart';

class RegistroPage extends StatefulWidget {
  const RegistroPage({Key? key}) : super(key: key);

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _password = TextEditingController();

  final List<String> _roles = const ['ganadero', 'veterinario'];
  String? _selectedRole;

  bool _loading = false;
  bool _obscure = true;
  final _authSvc = AuthService();

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _authSvc.registerWithEmail(
        displayName: _nombre.text,
        email: _correo.text,
        password: _password.text,
        role: _selectedRole!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro exitoso')),
      );
      goHomeAndClear(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final map = {
        'email-already-in-use': 'Ese correo ya está registrado.',
        'invalid-email': 'Correo inválido.',
        'weak-password': 'La contraseña es demasiado débil.',
        'operation-not-allowed': 'El registro con email no está habilitado.',
      };
      final msg = map[e.code] ?? 'Error al registrar: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final map = {
        'permission-denied':
            'No tienes permisos en Firestore. Revisa las reglas publicadas.',
        'unavailable': 'Servicio no disponible temporalmente. Intenta de nuevo.',
      };
      final msg = map[e.code] ?? 'Error de base de datos: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registrarConGoogle() async {
    if (_loading) return;

    var role = _selectedRole ?? await pickRoleDialog(context);
    if (role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar un rol')),
      );
      return;
    }
    setState(() => _selectedRole = role);

    setState(() => _loading = true);
    try {
      await _authSvc.signInWithGoogleAndProvision(roleIfNew: role);
      if (!mounted) return;
      goHomeAndClear(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  SizedBox get _gap => const SizedBox(height: 16);

  @override
  Widget build(BuildContext context) {
    final submitChild = _loading
        ? const CircularProgressIndicator()
        : const Text('Registrarse');

    final bg = const Color.fromARGB(255, 104, 209, 117);

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: bg,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: Colors.black87),
          hintStyle: const TextStyle(color: Colors.black54),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.black12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.black26),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: Colors.black.withOpacity(0.4), width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Crear cuenta')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Stack(
                children: [
                  // Tarjeta del formulario
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Text(
                              'Regístrate',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Crea tu cuenta para continuar',
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            _gap,
                            TextFormField(
                              controller: _nombre,
                              decoration: const InputDecoration(
                                labelText: 'Nombre de usuario',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) => Validators.requiredText(
                                v,
                                msg: 'Ingresa tu nombre',
                              ),
                            ),
                            _gap,
                            TextFormField(
                              controller: _correo,
                              decoration: const InputDecoration(
                                labelText: 'Correo electrónico',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                            ),
                            _gap,
                            TextFormField(
                              controller: _password,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              obscureText: _obscure,
                              validator: Validators.passwordMin6,
                            ),
                            _gap,
                            DropdownButtonFormField<String>(
                              value: _selectedRole,
                              items: _roles
                                  .map((r) => DropdownMenuItem(
                                      value: r, child: Text(r)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedRole = v),
                              decoration: const InputDecoration(
                                labelText: 'Rol',
                                prefixIcon: Icon(Icons.work_outline),
                              ),
                              validator: (v) =>
                                  v == null ? 'Selecciona un rol' : null,
                            ),
                            const SizedBox(height: 22),
                            ElevatedButton(
                              onPressed: _loading ? null : _registrar,
                              child: submitChild,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.black.withOpacity(0.2),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: Text(
                                    'o',
                                    style: TextStyle(
                                        color: Colors.black.withOpacity(0.6)),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.black.withOpacity(0.2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Botón Google estilo imagen adjunta
                            GoogleAuthButton(
                              onPressed: _loading ? null : _registrarConGoogle,
                              text: 'Continuar con Google',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Indicador de carga superpuesto
                  if (_loading)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón “Continuar con Google” con estilo similar al de la imagen:
/// fondo blanco, borde suave, logo de Google a la izquierda.
class GoogleAuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  const GoogleAuthButton({
    super.key,
    required this.onPressed,
    this.text = 'Continuar con Google',
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          width: double.infinity, // botón ancho completo
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled ? Colors.black12 : Colors.black12.withOpacity(0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min, // <- evita overflow
              children: [
                // Usa tu JPEG
                Image.asset(
                  'assets/google_logo.jpeg',
                  width: 22,
                  height: 22,
                  errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 22),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis, // <- seguridad extra
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}