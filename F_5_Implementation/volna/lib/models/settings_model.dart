import 'package:flutter/foundation.dart';
import 'services/library_store.dart';
import 'ui_message.dart';

/// Defaults to English independently of the device language and persists overrides.
class SettingsModel extends ChangeNotifier {
  SettingsModel(this.store);
  final LibraryStore store;
  String languageCode = 'en';
  bool lightTheme = false;
  bool saving = false, _disposed = false;
  bool _initialized = false;
  Future<void>? _initialization;
  int _revision = 0;
  UiMessage? error;
  void clearError() {
    error = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() =>
      _initialization ??= _load().whenComplete(() => _initialization = null);

  Future<void> _load() async {
    // Capture the preference revision so a slow load cannot overwrite a newer choice.
    final revision = _revision;
    try {
      final data = await store.read('settings');
      if (_disposed || saving || revision != _revision) return;
      languageCode = data['language'] == 'ru' ? 'ru' : 'en';
      lightTheme = data['theme'] == 'light';
      notifyListeners();
    } catch (_) {
      /* A missing language preference falls back to English. */
    } finally {
      _initialized = true;
    }
  }

  Future<void> setLanguage(String code) => _save(language: code);

  Future<void> setLightTheme(bool light) => _save(light: light);

  Future<void> _save({String? language, bool? light}) async {
    // Load both saved preferences before changing one, preserving the other.
    if (!_initialized) await initialize();
    final code = language ?? languageCode;
    final isLight = light ?? lightTheme;
    if (_disposed || saving || !['en', 'ru'].contains(code)) return;
    ++_revision;
    saving = true;
    error = null;
    notifyListeners();
    try {
      await store.write('settings', {
        'language': code,
        'theme': isLight ? 'light' : 'dark',
      });
      if (!_disposed) {
        languageCode = code;
        lightTheme = isLight;
      }
    } catch (_) {
      error = const UiMessage(MessageId.settingsSaveFailed);
    } finally {
      saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

