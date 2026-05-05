// lib/home_login.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Servicios
import 'services/auth_service.dart';

// Widgets y utilidades
import 'widgets/role_picker_dialog.dart';
import 'utils/validators.dart';
import 'utils/nav.dart';

/// Pantalla de bienvenida (la usa AuthGate cuando no hay sesión)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Center(
                  child: Text(
                    'Bovi Controll',
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
                    style: TextStyle(fontSize: 15, color: Colors.black),
                  ),
                )
              ],
            ),
            // Si tu archivo existe con ese nombre/espacio, se mantiene:
            Image.asset('assets/logo bovi control.jpg'),
            Column(
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 104, 209, 117),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 100, vertical: 20),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('Iniciar Sesión'),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/registro'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 100, vertical: 20),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Regístrate',
                    style: TextStyle(color: Colors.green),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}

/// ---------- LOGIN REDISEÑADO (estilo del registro) ----------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  final _authSvc = AuthService();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _authSvc.signInWithEmailAndProvision(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión iniciada correctamente')),
      );
      goHomeAndClear(context);
    } on FirebaseAuthException catch (e) {
      final map = {
        'user-not-found': 'Usuario no encontrado',
        'wrong-password': 'Contraseña incorrecta',
        'invalid-email': 'Email inválido',
        'invalid-credential': 'Correo o contraseña incorrectos',
        'user-disabled': 'Esta cuenta fue deshabilitada',
        'too-many-requests':
            'Demasiados intentos. Intenta nuevamente en unos minutos',
      };
      final msg = map[e.code] ?? 'Error al iniciar sesión';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_email.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ingresa tu email para recuperar la contraseña')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _email.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email de recuperación enviado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_loading) return;

    // Pide el rol por adelantado para aprovisionar si es usuario nuevo
    String? role = await pickRoleDialog(context); // 'ganadero' | 'veterinario'
    if (role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar un rol')),
      );
      return;
    }

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
    const bg = Color.fromARGB(255, 104, 209, 117);

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
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Iniciar sesión')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Stack(
                children: [
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
                          children: [
                            const Text(
                              'Bienvenido',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ingresa para continuar',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.6),
                              ),
                            ),
                            _gap,
                            TextFormField(
                              controller: _email,
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
                              obscureText: _obscure,
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
                              validator: Validators.passwordMin6,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _resetPassword,
                                child: const Text('¿Olvidaste tu contraseña?'),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ElevatedButton(
                              onPressed: _loading ? null : _signIn,
                              child: _loading
                                  ? const CircularProgressIndicator()
                                  : const Text('Iniciar sesión'),
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
                            // Botón Google igual que en Registro
                            GoogleAuthButton(
                              onPressed: _loading ? null : _signInWithGoogle,
                              text: 'Continuar con Google',
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/registro'),
                              child: const Text(
                                '¿No tienes cuenta? Regístrate',
                                style: TextStyle(color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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

/// ---------- Reutilizable: botón Google con imagen ----------
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
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled ? Colors.black12 : Colors.black12.withOpacity(0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tu asset JPEG
                Image.asset(
                  'assets/google_logo.jpeg',
                  width: 22,
                  height: 22,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.login, size: 22),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis,
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
