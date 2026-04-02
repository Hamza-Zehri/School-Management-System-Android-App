import 'package:shared_preferences/shared_preferences.dart';
import '../db/extended_database_helper.dart';

class SecurityService {
  static final SecurityService instance = SecurityService._();
  SecurityService._();

  static const String _pinKey = 'app_pin';
  static const String _lockEnabledKey = 'app_lock_enabled';

  Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lockEnabledKey) ?? false;
  }

  Future<void> setLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockEnabledKey, enabled);
  }

  Future<String?> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey);
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
  }

  Future<bool> verifyPin(String enteredPin) async {
    final savedPin = await getPin();
    return savedPin == enteredPin;
  }

  Future<bool> resetPinWithRecovery(String schoolName) async {
    final settings = await ExtendedDatabaseHelper.instance.getSchoolSettings();
    if (settings != null && settings.schoolName.toLowerCase().trim() == schoolName.toLowerCase().trim()) {
      await setPin('1234'); // Reset to default
      return true;
    }
    return false;
  }
}
