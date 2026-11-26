import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_storage.dart';
import '../services/biometric_service.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _bg = Color(0xFF0B0F19);
  static const Color _surface = Color(0xFF151C2C);
  static const Color _surfaceLight = Color(0xFF1E273B);
  static const Color _primary = Color(0xFFFF5500);
  static const Color _primaryGlow = Color(0xFFFF7B00);
  static const Color _accent = Color(0xFF00E5A0);
  static const Color _textPrimary = Color(0xFFF8FAFC);
  static const Color _textSecondary = Color(0xFF94A3B8);
  static const Color _border = Color(0xFF263147);

  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _bioService = BiometricService();
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRegistrationOnStart();
    });
  }

  Future<bool> _hasAnyUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('cf_username')) return true;
    return await AuthStorage.hasRegisteredUser();
  }

  Future<void> _checkRegistrationOnStart() async {
    bool isRegistered = await _hasAnyUser();
    if (!isRegistered && mounted) {
      _showRegisterRequiredDialog(
        "Bienvenido a Crimson Fit. Crea tu perfil de atleta con tu correo y activa el acceso biométrico.",
      );
    }
  }

  void _showRegisterRequiredDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _border, width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, color: _primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Perfil Requerido",
                style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(color: _textSecondary, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("MÁS TARDE", style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
            },
            child: const Text("CREAR CUENTA", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermissionsAndEnter() async {
    bool proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _border, width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.sensors, color: _accent),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Sincronizar Sensores",
                style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          "Para medir tu rendimiento con precisión, necesitamos acceso a tu UBICACIÓN (GPS) y ACTIVIDAD FÍSICA.",
          style: TextStyle(color: _textSecondary, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("ACTIVAR Y ENTRAR", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ??
        false;

    if (!proceed) return;

    await [Permission.location, Permission.activityRecognition].request();

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _loginWithCredentials() async {
    bool isRegistered = await _hasAnyUser();
    if (!isRegistered) {
      if (!mounted) return;
      _showRegisterRequiredDialog("Aún no tienes un perfil creado. Regístrate primero para comenzar.");
      return;
    }

    final inputUser = _userCtrl.text.trim();
    final inputPass = _passCtrl.text.trim();

    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('cf_username');
    final savedPass = prefs.getString('cf_password');

    bool valid = false;
    if (savedUser != null && savedPass != null) {
      valid = (inputUser == savedUser && inputPass == savedPass);
    } else {
      valid = await AuthStorage.loginWithPassword(inputUser, inputPass);
    }

    if (!mounted) return;
    if (valid) {
      await _requestPermissionsAndEnter();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Usuario o contraseña incorrectos"), backgroundColor: Colors.redAccent),
      );
    }
  }

  // Abre el BiometricPrompt nativo del sistema para HUELLA
  void _loginWithFingerprint() async {
    bool isRegistered = await _hasAnyUser();
    if (!isRegistered) {
      if (!mounted) return;
      _showRegisterRequiredDialog("Regístrate primero y activa la huella digital.");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    bool enabled = prefs.getBool('cf_fingerprint_enabled') ?? await AuthStorage.isBiometricEnabled();

    if (!enabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La huella digital no fue habilitada en el registro."),
          backgroundColor: _primary,
        ),
      );
      return;
    }

    final bool authenticated = await _bioService.authenticate(
      reason: 'Coloca tu huella para entrar a tu perfil Crimson Fit',
    );

    if (!mounted) return;
    if (authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Acceso biométrico verificado"), backgroundColor: _accent),
      );
      await _requestPermissionsAndEnter();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Autenticación cancelada o huella no reconocida"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Abre el mismo BiometricPrompt nativo del sistema (con pestaña Huella digital | Rostro)
  void _loginWithFaceNative() async {
    bool isRegistered = await _hasAnyUser();
    if (!isRegistered) {
      if (!mounted) return;
      _showRegisterRequiredDialog("Regístrate primero y habilita el reconocimiento facial.");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    bool faceEnabled = prefs.getBool('cf_face_enabled') ?? false;

    if (!faceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("El reconocimiento facial no fue habilitado al registrarte."),
          backgroundColor: _primary,
        ),
      );
      return;
    }

    // Invoca el BiometricPrompt nativo de Android/Samsung (Huella digital | Rostro)
    final bool authenticated = await _bioService.authenticate(
      reason: 'Escanea tu rostro para entrar a tu perfil Crimson Fit',
    );

    if (!mounted) return;
    if (authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("¡Rostro verificado! Bienvenido Atleta"), backgroundColor: _accent),
      );
      await _requestPermissionsAndEnter();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se verificó el rostro. Asegúrate de tener el rostro registrado en Ajustes del teléfono."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  InputDecoration _fieldDecoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: _primary),
      suffixIcon: suffix,
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_primary, _primaryGlow],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.bolt_rounded, size: 54, color: Colors.white),
                ),
                const SizedBox(height: 18),
                const Text(
                  "CRIMSON FIT",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "SUPERA TUS LÍMITES • UPFIM 4TIG1",
                    style: TextStyle(
                      color: _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _userCtrl,
                  style: const TextStyle(color: _textPrimary),
                  decoration: _fieldDecoration("Usuario", Icons.person_outline_rounded),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  style: const TextStyle(color: _textPrimary),
                  decoration: _fieldDecoration(
                    "Contraseña",
                    Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: _textSecondary,
                      ),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: _primary.withOpacity(0.4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _loginWithCredentials,
                    child: const Text(
                      "COMENZAR ENTRENAMIENTO",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textPrimary,
                          backgroundColor: _surface,
                          side: const BorderSide(color: _border, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _loginWithFingerprint,
                        icon: const Icon(Icons.fingerprint, color: _accent, size: 24),
                        label: const Text("HUELLA", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textPrimary,
                          backgroundColor: _surface,
                          side: const BorderSide(color: _border, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _loginWithFaceNative,
                        icon: const Icon(Icons.face_retouching_natural_rounded, color: _primary, size: 24),
                        label: const Text("ROSTRO", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("¿Nuevo en la plataforma?", style: TextStyle(color: _textSecondary)),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text(
                        "Regístrate aquí",
                        style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}