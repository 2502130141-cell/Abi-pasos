import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const String _keyUser = 'fitness_user';
  static const String _keyPass = 'fitness_pass_hash';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyHistory = 'workout_history';

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  static Future<bool> hasRegisteredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString(_keyUser);
    return user != null && user.isNotEmpty;
  }

  static Future<void> registerUser(String username, String password, bool enableBiometric) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, username);
    await prefs.setString(_keyPass, _hashPassword(password));
    await prefs.setBool(_keyBiometricEnabled, enableBiometric);
  }

  static Future<bool> loginWithPassword(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString(_keyUser);
    final savedHash = prefs.getString(_keyPass);
    return savedUser == username && savedHash == _hashPassword(password);
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  static Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, value);
  }

  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUser) ?? "Atleta";
  }

  static Future<void> saveWorkout(String record) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_keyHistory) ?? [];
    history.insert(0, record);
    await prefs.setStringList(_keyHistory, history);
  }

  static Future<List<String>> getWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyHistory) ?? [];
  }
}