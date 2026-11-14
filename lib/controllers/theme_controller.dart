import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController {
  ThemeController(this._preferences);

  static const _preferenceKey = 'control_room_dark_theme';

  final SharedPreferences _preferences;
  final isDark = false.obs;

  ThemeMode get themeMode => isDark.value ? ThemeMode.dark : ThemeMode.light;

  Future<void> loadSavedTheme() async {
    isDark.value = _preferences.getBool(_preferenceKey) ?? false;
  }

  Future<void> toggleTheme() async {
    final nextValue = !isDark.value;
    await _preferences.setBool(_preferenceKey, nextValue);
    isDark.value = nextValue;
    Get.changeThemeMode(themeMode);
  }
}
