# Testing and Limitations

[Русская версия](D_2_Testing.ru.md)

## Recorded Verification

Scope: the first version of Volna. Latest recorded code check: 2026-11-14.

- 92 automated tests passed, including MVC boundaries, persistence, folder navigation,
  playback races, localization, themes and adaptive player layouts.
- `flutter analyze --no-pub` reported no issues.
- Tests cover stable immutable queue snapshots and excluding
  buffering from listening qualification.
- APK build and phone acceptance are not part of this recorded code check.

These are recorded results, not a claim that tests ran during this documentation update.

## Reproduce

From `F_5_Implementation/volna`:

```powershell
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

## Phone Acceptance Checklist

Record device, Android version, app version, APK hash and pass/fail evidence.

- Fresh install; select/cancel a folder; open nested tracks.
- Refresh after adding/removing files; remove a folder without deleting its music.
- Play/pause, stop, seek, previous/next, queue selection, repeat and shuffle.
- Confirm Top 100 ignores quick skips, seeks and radio.
- Change language and theme; restart and check saved state without autoplay.
- Check small screens, landscape, large text and long titles without clipped controls.
- Test background playback, lock-screen controls, calls, headphones and Bluetooth.
- Test offline playback, revoked folder access, unavailable files and radio errors.
- Check each station on the intended network and device.

## Release Checklist

- Run analysis and automated tests.
- Read the actual version from `F_5_Implementation/volna/pubspec.yaml`.
- Build the ARM64 APK using the [README instructions](README.md).
- Record the APK filename, architecture, version, SHA-256 and signing identity.
- Complete the phone acceptance checklist for that exact APK.
- Configure production signing before store distribution.
- Review radio stream/logo publication terms and document known limitations.
- The owner handles Git commits, pushes and publication.

This documentation does not certify an APK or establish store readiness.

## Known Limitations

- Recorded network checks returned HTTP 401 for Capital, Heart and LBC, and TLS
  failures for Retro FM, Radio Shanson and Humor FM. These have not been freshly
  retested here; availability remains broadcaster/network dependent.
- Local tracks use a shared cover; embedded album artwork is not extracted.
- MP3 is the main target; other codecs depend on platform support.
- Release signing uses a development key. Production signing and third-party
  stream/logo publication terms require review before store distribution.
- Full physical-device acceptance of current source is not recorded.
- Android only; no downloads, favorites, manual playlists, custom station editing,
  equalizer or cloud sync.

Report issues with reproduction steps, expected/actual behavior, version,
device/Android, network context and sanitized evidence. Do not include private files
or credentials. Passing automated tests does not establish Google Play readiness.


