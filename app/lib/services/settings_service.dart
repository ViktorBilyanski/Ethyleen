import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._();
  factory SettingsService() => _instance;
  SettingsService._();

  late SharedPreferences _prefs;

  // Theme
  final ValueNotifier<bool> isDarkMode = ValueNotifier(true);

  // Notifications
  bool notificationsEnabled = true;
  DateTime? alertsMutedUntil;

  // Device
  int powerBankCapacity = 10000;

  // Custom thresholds (null = use calibration defaults)
  Map<String, double>? customThresholds;

  // Environment ideal ranges
  double idealTempMin = 2;
  double idealTempMax = 8;
  double idealHumidityMin = 30;
  double idealHumidityMax = 50;

  // Onboarding
  bool onboardingCompleted = false;

  bool get alertsMuted =>
      alertsMutedUntil != null && DateTime.now().isBefore(alertsMutedUntil!);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    isDarkMode.value = _prefs.getBool('dark_mode') ?? true;
    notificationsEnabled = _prefs.getBool('notifications') ?? true;
    powerBankCapacity = _prefs.getInt('powerbank_mah') ?? 10000;
    onboardingCompleted = _prefs.getBool('onboarding_done') ?? false;
    idealTempMin = _prefs.getDouble('ideal_temp_min') ?? 2;
    idealTempMax = _prefs.getDouble('ideal_temp_max') ?? 8;
    idealHumidityMin = _prefs.getDouble('ideal_hum_min') ?? 30;
    idealHumidityMax = _prefs.getDouble('ideal_hum_max') ?? 50;

    final muteMs = _prefs.getInt('mute_until');
    if (muteMs != null) {
      alertsMutedUntil = DateTime.fromMillisecondsSinceEpoch(muteMs);
      if (!alertsMuted) alertsMutedUntil = null;
    }

    final threshJson = _prefs.getString('custom_thresholds');
    if (threshJson != null) {
      final map = jsonDecode(threshJson) as Map<String, dynamic>;
      customThresholds = map.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }
  }

  Future<void> setDarkMode(bool v) async {
    isDarkMode.value = v;
    await _prefs.setBool('dark_mode', v);
  }

  Future<void> setNotifications(bool v) async {
    notificationsEnabled = v;
    await _prefs.setBool('notifications', v);
  }

  Future<void> setPowerBankCapacity(int mah) async {
    powerBankCapacity = mah;
    await _prefs.setInt('powerbank_mah', mah);
  }

  Future<void> setOnboardingCompleted(bool v) async {
    onboardingCompleted = v;
    await _prefs.setBool('onboarding_done', v);
  }

  Future<void> muteAlerts(Duration duration) async {
    alertsMutedUntil = DateTime.now().add(duration);
    await _prefs.setInt('mute_until', alertsMutedUntil!.millisecondsSinceEpoch);
  }

  Future<void> unmuteAlerts() async {
    alertsMutedUntil = null;
    await _prefs.remove('mute_until');
  }

  Future<void> setIdealTemp(double min, double max) async {
    idealTempMin = min;
    idealTempMax = max;
    await _prefs.setDouble('ideal_temp_min', min);
    await _prefs.setDouble('ideal_temp_max', max);
  }

  Future<void> setIdealHumidity(double min, double max) async {
    idealHumidityMin = min;
    idealHumidityMax = max;
    await _prefs.setDouble('ideal_hum_min', min);
    await _prefs.setDouble('ideal_hum_max', max);
  }

  void applyFridgePreset() {
    setIdealTemp(2, 8);
    setIdealHumidity(30, 50);
  }

  void applyRoomPreset() {
    setIdealTemp(18, 24);
    setIdealHumidity(40, 60);
  }

  Future<void> setCustomThresholds(Map<String, double>? thresholds) async {
    customThresholds = thresholds;
    if (thresholds == null) {
      await _prefs.remove('custom_thresholds');
    } else {
      await _prefs.setString('custom_thresholds', jsonEncode(thresholds));
    }
  }
}
