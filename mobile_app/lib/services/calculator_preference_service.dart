import 'package:shared_preferences/shared_preferences.dart';

abstract class CalculatorPreferenceService {
  Future<bool> calculatorEnabled();

  Future<void> setCalculatorEnabled(bool enabled);
}

class SharedPreferencesCalculatorPreferenceService
    implements CalculatorPreferenceService {
  const SharedPreferencesCalculatorPreferenceService();

  static const _key = 'hisaab_amount_calculator_enabled_v1';

  @override
  Future<bool> calculatorEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key) ?? false;
  }

  @override
  Future<void> setCalculatorEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key, enabled);
  }
}
