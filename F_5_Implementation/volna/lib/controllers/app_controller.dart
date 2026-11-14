import '../models/app_model.dart';
import '../models/library_model.dart';
import '../models/settings_model.dart';
import 'playback_controller.dart';

/// Routes application commands without owning observable domain state.
// Controller classes route commands; observable application state stays in Model.
class AppController {
  AppController(this.model)
    : library = LibraryController(model.library),
      playback = PlaybackController(model.playback, model.library),
      settings = SettingsController(model.settings);
  final AppModel model;
  final LibraryController library;
  final PlaybackController playback;
  final SettingsController settings;
  Future<void> initialize() => model.initialize();
  Future<void> savePlayback() => model.savePlayback();
}

/// Translates folder actions into library operations.
class LibraryController {
  LibraryController(this._model);
  final LibraryModel _model;
  Future<void> addFolder() => _model.addFolder();
  Future<void> refresh() => _model.scan();
  Future<void> removeFolder(String uri) => _model.removeFolder(uri);
  void clearError() => _model.clearError();
}

// This controller exposes preference commands without building any widgets.
class SettingsController {
  SettingsController(this.model);
  final SettingsModel model;
  Future<void> setLanguage(String code) => model.setLanguage(code);
  Future<void> setLightTheme(bool light) => model.setLightTheme(light);
  void clearError() => model.clearError();
}

