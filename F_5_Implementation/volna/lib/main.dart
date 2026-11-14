import 'package:flutter/material.dart';

import 'controllers/app_controller.dart';
import 'models/app_model.dart';
import 'models/library_model.dart';
import 'models/player_model.dart';
import 'models/services/audio_bootstrap.dart';
import 'models/services/library_store.dart';
import 'views/app_view.dart';

// Entry-point function: Flutter starts here; its name must remain main.
// async allows startup to await platform setup before displaying widgets.
Future<void> main() async {
  // Initialize Flutter's platform bridge before calling audio plugins.
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAudio();
  // Create one shared Model graph so all screens use the same player and library.
  final model = AppModel(
    library: LibraryModel(store: LibraryStore()),
    playback: PlayerModel(),
  );
  // Hand the root widget to Flutter; runApp is a framework function.
  runApp(MusicApp(controller: AppController(model)));
}

