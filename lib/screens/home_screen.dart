import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sensors_service.dart';
import '../services/auth_storage.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _bg = Color(0xFF0B0F19);
  static const Color _surface = Color(0xFF151C2C);
  static const Color _surfaceLight = Color(0xFF1E273B);
  static const Color _primary = Color(0xFFFF5500);
  static const Color _accent = Color(0xFF00E5A0);
  static const Color _textPrimary = Color(0xFFF8FAFC);
  static const Color _textSecondary = Color(0xFF94A3B8);
  static const Color _border = Color(0xFF263147);

  final SensorsService _sensorsService = SensorsService();
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _gpsSub;
  Timer? _workoutTimer;

  String _username = "Atleta";
  String _email = "atleta@crimsonfit.com";
  bool _fingerprintEnabled = false;
  bool _faceEnabled = false;

  bool _isRunning = false;
  int _elapsedSeconds = 0;
  int _steps = 0;
  double _accelForce = 0.0;
  String _intensity = "Reposo";
  String _gyroCoords = "0°, 0°";
  String _posture = "Postura Recta";
  double _distanceMeters = 0.0;

  final List<LatLng> _route = [];
  LatLng _center = const LatLng(20.2244, -99.0897);

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _initLocation();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final fallbackName = await AuthStorage.getUsername();
    if (mounted) {
      setState(() {
        _username = prefs.getString('cf_username') ?? fallbackName;
        _email = prefs.getString('cf_email') ?? "No registrado";
        _fingerprintEnabled = prefs.getBool('cf_fingerprint_enabled') ?? false;
        _faceEnabled = prefs.getBool('cf_face_enabled') ?? false;
      });
    }
  }

  // Modal de Mi Perfil (Usuario y Correo bloqueados, Contraseña editable)
  void _showProfileDialog() {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureNew = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
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
                child: const Icon(Icons.account_circle_rounded, color: _primary, size: 26),
              ),
              const SizedBox(width: 12),
              const Text(
                "MI PERFIL ATLETA",
                style: TextStyle(color: _textPrimary, fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("DATOS DE CUENTA (NO MODIFICABLES)", style: TextStyle(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 10),

                // Campo Usuario (Solo lectura)
                TextFormField(
                  initialValue: _username,
                  readOnly: true,
                  style: const TextStyle(color: _textSecondary),
                  decoration: InputDecoration(
                    labelText: "Nombre de usuario",
                    labelStyle: const TextStyle(color: _textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: _textSecondary),
                    suffixIcon: const Icon(Icons.lock_outline, size: 18, color: _textSecondary),
                    filled: true,
                    fillColor: _bg.withOpacity(0.6),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Campo Correo (Solo lectura)
                TextFormField(
                  initialValue: _email,
                  readOnly: true,
                  style: const TextStyle(color: _textSecondary),
                  decoration: InputDecoration(
                    labelText: "Correo electrónico",
                    labelStyle: const TextStyle(color: _textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.email_outlined, color: _textSecondary),
                    suffixIcon: const Icon(Icons.lock_outline, size: 18, color: _textSecondary),
                    filled: true,
                    fillColor: _bg.withOpacity(0.6),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Estado de biometría
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      backgroundColor: _bg,
                      side: BorderSide(color: _fingerprintEnabled ? _accent : _border),
                      avatar: Icon(Icons.fingerprint, size: 16, color: _fingerprintEnabled ? _accent : _textSecondary),
                      label: Text(
                        _fingerprintEnabled ? "Huella Activa" : "Huella Inactiva",
                        style: TextStyle(fontSize: 11, color: _fingerprintEnabled ? _accent : _textSecondary),
                      ),
                    ),
                    Chip(
                      backgroundColor: _bg,
                      side: BorderSide(color: _faceEnabled ? _accent : _border),
                      avatar: Icon(Icons.camera_alt_outlined, size: 16, color: _faceEnabled ? _accent : _textSecondary),
                      label: Text(
                        _faceEnabled ? "Rostro Activo" : "Rostro Inactivo",
                        style: TextStyle(fontSize: 11, color: _faceEnabled ? _accent : _textSecondary),
                      ),
                    ),
                  ],
                ),

                const Divider(color: _border, height: 26),
                const Text("CAMBIAR CONTRASEÑA", style: TextStyle(fontSize: 10, color: _primary, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 10),

                TextField(
                  controller: newPassCtrl,
                  obscureText: obscureNew,
                  style: const TextStyle(color: _textPrimary),
                  decoration: InputDecoration(
                    labelText: "Nueva contraseña",
                    labelStyle: const TextStyle(color: _textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.vpn_key_outlined, color: _primary),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, color: _textSecondary, size: 20),
                      onPressed: () => setModalState(() => obscureNew = !obscureNew),
                    ),
                    filled: true,
                    fillColor: _bg,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: obscureNew,
                  style: const TextStyle(color: _textPrimary),
                  decoration: InputDecoration(
                    labelText: "Confirmar nueva contraseña",
                    labelStyle: const TextStyle(color: _textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.check_circle_outline, color: _primary),
                    filled: true,
                    fillColor: _bg,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primary, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("CANCELAR", style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final p1 = newPassCtrl.text.trim();
                final p2 = confirmPassCtrl.text.trim();

                if (p1.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Escribe una nueva contraseña"), backgroundColor: Colors.redAccent),
                  );
                  return;
                }
                if (p1 != p2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Las contraseñas no coinciden"), backgroundColor: Colors.redAccent),
                  );
                  return;
                }

                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('cf_password', p1);
                await AuthStorage.registerUser(_username, p1, _fingerprintEnabled || _faceEnabled);

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Contraseña actualizada correctamente"),
                    backgroundColor: _accent,
                  ),
                );
              },
              child: const Text("ACTUALIZAR CLAVE", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return "${hours.toString().padLeft(2, '0')}:$mm:$ss";
    }
    return "$mm:$ss";
  }

  Future<void> _initLocation() async {
    await [Permission.location, Permission.activityRecognition].request();

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Activa el GPS de tu dispositivo para rastrear tu ruta"),
            backgroundColor: _primary,
          ),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      try {
        Position pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (mounted) {
          setState(() => _center = LatLng(pos.latitude, pos.longitude));
          _mapController.move(_center, 17.5);
        }
      } catch (_) {}
    }
  }

  void _toggleSession() async {
    if (_isRunning) {
      _sensorsService.dispose();
      _gpsSub?.cancel();
      _workoutTimer?.cancel();

      final distText = _distanceMeters >= 1000
          ? "${(_distanceMeters / 1000).toStringAsFixed(2)} km"
          : "${_distanceMeters.toStringAsFixed(0)} m";
      final timeText = _formatDuration(_elapsedSeconds);
      final summary = "${DateTime.now().toString().substring(0, 16)} | $timeText | $_steps pasos | $distText";

      await AuthStorage.saveWorkout(summary);
      setState(() => _isRunning = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Excelente sesión! Entrenamiento guardado."),
            backgroundColor: _accent,
          ),
        );
      }
    } else {
      await [Permission.location, Permission.activityRecognition].request();

      setState(() {
        _isRunning = true;
        _elapsedSeconds = 0;
        _steps = 0;
        _distanceMeters = 0.0;
        _route.clear();
        _route.add(_center);
      });

      _workoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsedSeconds++);
      });

      _sensorsService.startSensors(
        onSteps: (s) {
          if (mounted) setState(() => _steps = s);
        },
        onAccel: (f, i) {
          if (mounted) {
            setState(() {
              _accelForce = f;
              _intensity = i;
            });
          }
        },
        onGyro: (c, p) {
          if (mounted) {
            setState(() {
              _gyroCoords = c;
              _posture = p;
            });
          }
        },
        onError: (err) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
          }
        },
      );

      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 1,
        ),
      ).listen((pos) {
        final pt = LatLng(pos.latitude, pos.longitude);
        if (mounted) {
          setState(() {
            if (_route.isNotEmpty) {
              double moved = Geolocator.distanceBetween(
                _route.last.latitude,
                _route.last.longitude,
                pt.latitude,
                pt.longitude,
              );
              if (moved >= 0.8) {
                _distanceMeters += moved;
                _route.add(pt);
              }
            } else {
              _route.add(pt);
            }
            _center = pt;
          });
          _mapController.move(pt, 18.0);
        }
      });
    }
  }

  void _showHistoryModal() async {
    final items = await AuthStorage.getWorkouts();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
            ),
            const Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: _primary),
                SizedBox(width: 10),
                Text(
                  "HISTORIAL DE RENDIMIENTO",
                  style: TextStyle(fontWeight: FontWeight.w800, color: _textPrimary, fontSize: 16),
                ),
              ],
            ),
            const Divider(color: _border, height: 24),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                child: Text(
                  "Aún no hay sesiones registradas.\n¡Inicia tu primer entrenamiento hoy!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _textSecondary),
                ),
              )
                  : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => Container(
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _primary.withOpacity(0.15),
                      child: const Icon(Icons.bolt_rounded, color: _primary),
                    ),
                    title: Text(
                      items[i],
                      style: const TextStyle(fontSize: 13, color: _textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sensorsService.dispose();
    _gpsSub?.cancel();
    _workoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String distanceFormatted = _distanceMeters >= 1000
        ? "${(_distanceMeters / 1000).toStringAsFixed(2)} km"
        : "${_distanceMeters.toStringAsFixed(1)} m";

    return Scaffold(
      backgroundColor: _bg,
      // MENÚ HAMBURGUESA (DRAWER)
      drawer: Drawer(
        backgroundColor: _surface,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_bg, _surfaceLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(bottom: BorderSide(color: _border)),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: _primary,
                child: Text(
                  _username.isNotEmpty ? _username[0].toUpperCase() : "A",
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
              accountName: Text(
                _username.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _textPrimary),
              ),
              accountEmail: Text(
                _email,
                style: const TextStyle(color: _accent, fontSize: 13),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_pin_rounded, color: _primary),
              title: const Text("Mi Perfil", style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
              subtitle: const Text("Ver datos y cambiar contraseña", style: TextStyle(color: _textSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(context); // Cierra el menú hamburguesa
                _showProfileDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded, color: _accent),
              title: const Text("Historial de Entrenamientos", style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _showHistoryModal();
              },
            ),
            ListTile(
              leading: const Icon(Icons.my_location_rounded, color: Colors.lightBlueAccent),
              title: const Text("Recalibrar GPS", style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _initLocation();
              },
            ),
            const Spacer(),
            const Divider(color: _border),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primary), // Ícono de hamburguesa en Naranja Volt
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("PANEL DE ENTRENAMIENTO", style: TextStyle(fontSize: 10, color: _textSecondary, letterSpacing: 1.2)),
            Text("HOLA, ${_username.toUpperCase()}", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _textPrimary)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Centrar GPS",
            icon: const Icon(Icons.my_location_rounded, color: _textSecondary),
            onPressed: _initLocation,
          ),
          IconButton(
            tooltip: "Historial",
            icon: const Icon(Icons.history_rounded, color: _primary),
            onPressed: _showHistoryModal,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isRunning ? _accent : _border,
                      width: _isRunning ? 2 : 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(initialCenter: _center, initialZoom: 17),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(points: _route, color: _primary, strokeWidth: 5),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _center,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _accent.withOpacity(0.25),
                              ),
                              child: const Icon(Icons.navigation_rounded, color: _accent, size: 26),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 18,
                  left: 26,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _bg.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _isRunning ? _accent : _border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: _isRunning ? _accent : _textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isRunning ? "SESIÓN ACTIVA" : "GPS LISTO",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _isRunning ? _accent : _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isRunning ? [_surfaceLight, _surface] : [_surface, _surface],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isRunning ? _primary : _border,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.timer_outlined, color: _primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("TIEMPO ACTIVO", style: TextStyle(fontSize: 11, color: _textSecondary, fontWeight: FontWeight.w700)),
                        Text("Duración total", style: TextStyle(fontSize: 11, color: _textSecondary)),
                      ],
                    ),
                  ],
                ),
                Text(
                  _formatDuration(_elapsedSeconds),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                    letterSpacing: 1.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 5,
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.48,
              children: [
                _metricCard("PODÓMETRO", "$_steps", "pasos", Icons.directions_walk_rounded, _accent),
                _metricCard("DISTANCIA", distanceFormatted, "recorrida", Icons.route_rounded, _primary),
                _metricCard("INTENSIDAD", "${_accelForce.toStringAsFixed(1)} m/s²", _intensity, Icons.local_fire_department_rounded, Colors.amberAccent),
                _metricCard("POSTURA", _posture, _gyroCoords, Icons.accessibility_new_rounded, Colors.lightBlueAccent),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRunning ? _surfaceLight : _primary,
                  foregroundColor: _isRunning ? _accent : Colors.white,
                  side: _isRunning ? const BorderSide(color: _accent, width: 2) : BorderSide.none,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _toggleSession,
                icon: Icon(_isRunning ? Icons.stop_circle_outlined : Icons.play_arrow_rounded, size: 26),
                label: Text(
                  _isRunning ? "FINALIZAR Y GUARDAR SESIÓN" : "INICIAR ENTRENAMIENTO",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String mainValue, String subtitle, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: _textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mainValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}