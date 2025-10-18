import 'package:flutter/material.dart';
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
        role: _selectedRole!, // ya lo validamos en el form
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro exitoso')),
      );
      goHomeAndClear(context);
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

    // Usa el rol elegido o pídeselo al usuario
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

  @override
  Widget build(BuildContext context) {
    final submitChild = _loading
        ? const CircularProgressIndicator()
        : const Text('Registrarse');

    return Scaffold(
      appBar: AppBar(title: const Text('Registro')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _nombre,
                decoration:
                    const InputDecoration(labelText: 'Nombre de usuario'),
                validator: (v) =>
                    Validators.requiredText(v, msg: 'Ingresa tu nombre'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _correo,
                decoration:
                    const InputDecoration(labelText: 'Correo electrónico'),
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                validator: Validators.passwordMin6,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                items: _roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRole = v),
                decoration: const InputDecoration(labelText: 'Rol'),
                validator: (v) => v == null ? 'Selecciona un rol' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _registrar,
                  child: submitChild,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('o'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _registrarConGoogle,
                  icon: const Icon(Icons.login),
                  label: const Text('Continuar con Google'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
