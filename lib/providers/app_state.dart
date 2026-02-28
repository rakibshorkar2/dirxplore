import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppState with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _defaultSavePath = '/storage/emulated/0/Download';
  int _maxConcurrentDownloads = 3;
  String _appVersion = 'Unknown';
  bool _initialized = false;

  ThemeMode get themeMode => _themeMode;
  String get defaultSavePath => _defaultSavePath;
  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  String get appVersion => _appVersion;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Theme
    final tIdx = prefs.getInt('themeMode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[tIdx];

    // Load Settings
    _defaultSavePath = prefs.getString('savePath') ?? '/storage/emulated/0/Download';
    _maxConcurrentDownloads = prefs.getInt('maxConcurrent') ?? 3;

    // Load App Version
    final info = await PackageInfo.fromPlatform();
    _appVersion = info.version;

    _initialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  Future<void> setDefaultSavePath(String path) async {
    _defaultSavePath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('savePath', path);
  }

  Future<void> setMaxConcurrentDownloads(int max) async {
    _maxConcurrentDownloads = max;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('maxConcurrent', max);
  }
}
