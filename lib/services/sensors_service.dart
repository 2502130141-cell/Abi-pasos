import 'dart:async';
import 'dart:math';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorsService {
  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  int? _initialHardwareSteps;
  int _accelSteps = 0;
  bool _hardwareWorking = false;
  DateTime _lastStepTime = DateTime.fromMillisecondsSinceEpoch(0);

  void startSensors({
    required Function(int) onSteps,
    required Function(double, String) onAccel,
    required Function(String, String) onGyro,
    required Function(String) onError,
  }) {
    _initialHardwareSteps = null;
    _accelSteps = 0;
    _hardwareWorking = false;

    // 1. Podómetro nativo (StepCounter)
    try {
      _stepSub = Pedometer.stepCountStream.listen(
            (StepCount event) {
          _initialHardwareSteps ??= event.steps;
          final diff = event.steps - _initialHardwareSteps!;
          if (diff > 0) {
            _hardwareWorking = true;
            onSteps(diff);
          }
        },
        onError: (_) {
          _hardwareWorking = false;
        },
      );
    } catch (_) {
      _hardwareWorking = false;
    }

    // 2. Acelerómetro (Mide intensidad y cuenta pasos en tiempo real si el podómetro nativo no responde)
    _accelSub = accelerometerEventStream().listen((event) {
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      double netForce = (magnitude - 9.81).abs();

      String intensity = "Reposo";
      if (netForce > 5.5) {
        intensity = "Alta (Corriendo)";
      } else if (netForce > 1.8) {
        intensity = "Moderada (Caminando)";
      }
      onAccel(netForce, intensity);

      // Detección de paso por pico de aceleración (umbral sensible de caminata = 2.1 m/s²)
      if (!_hardwareWorking && netForce > 2.1) {
        final now = DateTime.now();
        if (now.difference(_lastStepTime).inMilliseconds > 380) {
          _lastStepTime = now;
          _accelSteps++;
          onSteps(_accelSteps);
        }
      }
    });

    // 3. Giroscopio
    _gyroSub = gyroscopeEventStream().listen((event) {
      String coords = "${event.x.toStringAsFixed(1)}°, ${event.y.toStringAsFixed(1)}°";
      String posture = (event.x.abs() > 1.4 || event.y.abs() > 1.4)
          ? "Inclinado"
          : "Postura Recta";
      onGyro(coords, posture);
    });
  }

  void dispose() {
    _stepSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
  }
}