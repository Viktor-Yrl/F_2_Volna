# Volna

[Русская версия](README.ru.md)

Android music player built with Flutter: local music folders and a fixed radio catalog.

This documentation describes the first version of Volna and its complete current scope.

## Features

- Four tabs: Top 100, Playlists, Radio and Settings.
- Select phone folders, open their tracks and refresh the contents without copying music.
- Play/pause, stop, seek, queue, previous/next, shuffle and repeat.
- Top 100 counts actual listening: 30 seconds or half a short track; radio and seek jumps are excluded.
- Background audio and notification/lock-screen controls.
- Twelve built-in stations with bundled logos; English-language stations appear first.
- English by default, Russian as an option; Dark and Mist Blue themes.
- Saved folder selections, listening statistics, preferences, queue and position.
  Restoring a queue does not automatically start playback.

Removing a folder from Playlists does not delete its music.
There are no downloads, favorites, manual playlist editing or custom radio entries.
Android is the supported target; iOS is not maintained.

## Run

Open `F_5_Implementation/volna` as the Flutter project.
Recorded toolchain: Flutter 3.38.9 / Dart 3.10.8, plus Android SDK.

From this repository root:

```powershell
cd F_5_Implementation/volna
flutter pub get
flutter gen-l10n
flutter run
```

For a connected phone, enable USB debugging. Alternatively use an Android emulator.

## Build an ARM64 APK

From the Flutter project directory:

```powershell
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
Release builds currently use a development signing key, not production signing.

## Documentation

- [Architecture and file guide](D_1_Architecture.md)
- [Testing and limitations](D_2_Testing.md)

Root documents describe the first version. Numbered stage folders provide
short scope summaries and links to the corresponding root documentation.
Detailed radio attribution remains in
[RADIO_SOURCES.md](F_5_Implementation/volna/RADIO_SOURCES.md).

## Status

Latest recorded verification: **92 automated tests passed; Flutter analysis clean**.
The application has been tested on a physical phone. Radio availability
depends on broadcasters and networks.

