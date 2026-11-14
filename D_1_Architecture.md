# Architecture

[Русская версия](D_1_Architecture.ru.md)

## MVC Rules

Volna uses an explicit project-specific MVC structure:
View reads Model state and sends user actions to Controller; Controller calls Model.
Model owns state and business rules, never importing View or Controller.
Technical services belong to Model, not a fourth top-level layer.

Example: tap a song -> PlaybackController -> PlayerModel -> audio engine ->
Model notification -> refreshed View.
Playback progress has a separate notifier to avoid rebuilding track lists on every tick.

## File Guide

Paths below are relative to `F_5_Implementation/volna/lib`.

| File or directory | Responsibility |
| --- | --- |
| main.dart | Initialize audio and assemble the application |
| controllers/app_controller.dart | AppController wiring; LibraryController folder commands; SettingsController preferences |
| controllers/playback_controller.dart | Playback commands, notification permission coordination and repeat/shuffle actions |
| models/app_model.dart | Startup, playback restoration and checkpoint coordination |
| models/media.dart | Track/folder entities and formatting helpers |
| models/library_model.dart | Folders, scanned tracks, play counts and Top 100 |
| models/player_model.dart | Audio engine, immutable queue, transport, progress and error state |
| models/listening_tracker.dart | Qualify actual listening, excluding seeks, pauses, buffering and radio |
| models/settings_model.dart | Save and load language/theme preferences |
| models/radio_catalog.dart | Fixed station metadata and logo paths |
| models/ui_message.dart | Language-independent message identifiers |
| models/services/audio_bootstrap.dart | Background audio and audio-session setup |
| models/services/library_store.dart | Serialized local JSON persistence |
| models/services/media_library.dart | Android folder picker, scanning and access grants |
| models/services/radio_resolver.dart | Resolve stream redirects and supported playlists |
| models/services/radio_artwork_cache.dart | Prepare station logos for native notifications |
| views/app_view.dart | MaterialApp, locale and themes |
| views/home_screen.dart | Four tabs and library/radio/ranking navigation |
| views/folder_tracks_screen.dart | Selected folder contents |
| views/player_screen.dart | Adaptive full player, seek bar, queue and mini player |
| views/settings_screen.dart | Language and theme controls |
| views/track_tile.dart | Shared lists, track rows and error banners |
| views/track_artwork.dart | Local cover or station logo |
| views/l10n/strings.dart | Localized track labels and messages |
| views/l10n/app_en.arb, app_ru.arb | Editable English/Russian translations |
| views/l10n/app_localizations*.dart | Three generated translation files; do not edit manually |

## Resources and Persistence

`android/` contains the Android host, including document-tree integration;
`assets/` contains the shared cover and station logos; `test/` contains automated checks.
Music remains in the selected phone folders. App-private JSON stores folder references,
counts, preferences and playback checkpoints. Removing a selection does not delete audio.

After changing ARB files, run `flutter gen-l10n`.
There are **24 handwritten Dart files** in lib, plus three generated translation files.
Folder and settings controllers share one file. The queue is an immutable snapshot.


