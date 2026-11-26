import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_storage.dart';
import '../services/biometric_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const Color _bg = Color(0xFF0B0F19);
  static const Color _surface = Color(0xFF151C2C);
  static const Color _primary = Color(0xFFFF5500);
  static const Color _accent = Color(0xFF00E5A0);
  static const Color _textPrimary = Color(0xFFF8FAFC);
  static const Color _textSecondary = Color(0xFF94A3B8);
  static const Color _border = Color(0xFF263147);

  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _bioService = BiometricService();

  bool _enableFingerprint = false;
  bool _enableFaceId = false;
  bool _obscurePass = true;
  bool _isLoading = false;

  Future<void> _register() async {
    final username = _userCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnack("Completa usuario, correo y contraseña", Colors.redAccent);
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _showSnack("Ingresa un correo electrónico válido", Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Verificación opcional de Huella Digital (con captura de errores para no bloquear)
      if (_enableFingerprint) {
        try {
          bool ok = await _bioService.authenticate();
          if (!ok) {
            _showSnack("No se detectó huella en el dispositivo; se guardará la preferencia.", _primary);
          }
        } catch (_) {
          _showSnack("Sensor de huella no disponible en este entorno, continuando registro...", _primary);
        }
      }

      // 2. Permiso de cámara y verificación para Reconocimiento Facial
      if (_enableFaceId) {
        final camStatus = await Permission.camera.request();
        if (!camStatus.isGranted) {
          setState(() => _isLoading = false);
          _showSnack("Se requiere permiso de cámara para habilitar el reconocimiento facial", Colors.redAccent);
          return;
        }
        try {
          await _bioService.authenticate();
        } catch (_) {}
      }

      // 3. Guardar en tu AuthStorage original (compatibilidad total)
      await AuthStorage.registerUser(
        username,
        password,
        _enableFingerprint || _enableFaceId,
      );

      // 4. Guardar datos extendidos (Correo, Contraseña actual, Huella y Rostro)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cf_username', username);
      await prefs.setString('cf_email', email);
      await prefs.setString('cf_password', password);
      await prefs.setBool('cf_fingerprint_enabled', _enableFingerprint);
      await prefs.setBool('cf_face_enabled', _enableFaceId);

      if (!mounted) return;
      _showSnack("¡Perfil de atleta registrado con éxito!", _accent);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnack("Error al guardar registro: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
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
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textPrimary),
        title: const Text(
          "NUEVO PERFIL ATLETA",
          style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: _primary.withOpacity(0.5), width: 2),
                ),
                child: const Icon(Icons.directions_run_rounded, size: 50, color: _primary),
              ),
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                "Registra tus credenciales y métodos biométricos de acceso rápido.",
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),

            // Usuario
            TextField(
              controller: _userCtrl,
              style: const TextStyle(color: _textPrimary),
              decoration: _fieldDecoration("Nombre de usuario", Icons.person_outline_rounded),
            ),
            const SizedBox(height: 14),

            // Correo Electrónico
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: _textPrimary),
              decoration: _fieldDecoration("Correo electrónico", Icons.email_outlined),
            ),
            const SizedBox(height: 14),

            // Contraseña
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
            const SizedBox(height: 20),

            // Switch Huella Digital
            _biometricTile(
              title: "Habilitar Huella Digital",
              subtitle: "Inicia sesión con el sensor dactilar",
              icon: Icons.fingerprint,
              value: _enableFingerprint,
              onChanged: (val) => setState(() => _enableFingerprint = val),
            ),
            const SizedBox(height: 12),

            // Switch Reconocimiento Facial
            _biometricTile(
              title: "Habilitar Reconocimiento Facial",
              subtitle: "Acceso rápido usando la cámara frontal",
              icon: Icons.camera_alt_outlined,
              value: _enableFaceId,
              onChanged: (val) => setState(() => _enableFaceId = val),
            ),

            const SizedBox(height: 28),
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
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                  "GUARDAR Y REGISTRAR",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _biometricTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? _accent : _border,
          width: 1.5,
        ),
      ),
      child: SwitchListTile(
        activeColor: _accent,
        secondary: Icon(icon, color: value ? _accent : _textSecondary, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: _textSecondary)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}