import 'dart:async';

import 'services/library_store.dart';
import 'media.dart';
import 'library_model.dart';
import 'player_model.dart';
import 'settings_model.dart';

/// Coordinates domain state, persistence and playback restoration.
class AppModel {
  AppModel({required this.library, required this.playback}) {
    // Listeners connect Model events to persistence without referencing a screen.
    playback.addListener(_scheduleCheckpoint);
    playback.progress.addListener(_scheduleCheckpoint);
    playback.onQualifiedPlay = (track) => unawaited(library.recordPlay(track));
    playback.onQueueChanged = (tracks) =>
        unawaited(library.updateQueueRoots(tracks));
    library.addListener(_retryRestore);
  }
  final LibraryModel library;
  final PlayerModel playback;
  LibraryStore get store => library.store;
  late final settings = SettingsModel(store);
  Timer? _checkpointTimer;
  bool _disposed = false, _restoring = true;
  Future<void>? _initialization;
  Future<void>? _disposal;
  Map<String, dynamic>? _deferredPlayback;

  // Cache the initialization Future so concurrent callers share one startup.
  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    await settings.initialize();
    if (_disposed) return;
    await library.initialize();
    try {
      if (_disposed || playback.hasQueueIntent) return;
      final data = await store.read('playback');
      if (_disposed || playback.hasQueueIntent) return;
      await playback.setRepeat(
        RepeatMode.values.firstWhere(
          (e) => e.name == data['repeat'],
          orElse: () => RepeatMode.off,
        ),
      );
      if (_disposed || playback.hasQueueIntent) return;
      await playback.setShuffle(data['shuffle'] == true);
      await _restoreQueue(data);
    } catch (_) {
      // A damaged checkpoint must not prevent selecting new music.
    } finally {
      _restoring = false;
    }
  }

  Future<void> _restoreQueue(Map<String, dynamic> data) async {
    if (_disposed || playback.hasQueueIntent) return;
    final ids = (data['ids'] as List? ?? []).cast<String>();
    if (library.incompleteScan &&
        ids.any((id) => id.startsWith('folder:') && library.find(id) == null)) {
      // Keep even a partially resolvable queue intact until access returns.
      _deferredPlayback = data;
      return;
    }
    final tracks = <Track>[
      for (final id in ids)
        if (library.find(id) case final Track track) track,
    ];
    if (tracks.isNotEmpty && !_disposed) {
      final index = tracks.indexWhere((e) => e.id == data['currentId']);
      await playback.playTracks(
        tracks,
        startIndex: index < 0 ? 0 : index,
        // Restore the selection silently; startup must not unexpectedly play audio.
        autoplay: false,
        initialPosition: Duration(
          milliseconds: index < 0
              ? 0
              : ((data['positionMs'] as num?)?.toInt() ?? 0).clamp(0, 86400000),
        ),
      );
    }
  }

  void _retryRestore() {
    final data = _deferredPlayback;
    if (_disposed ||
        _restoring ||
        library.busy ||
        library.incompleteScan ||
        data == null) {
      return;
    }
    _deferredPlayback = null;
    if (playback.hasQueueIntent) return;
    _restoring = true;
    unawaited(_retryQueue(data));
  }

  Future<void> _retryQueue(Map<String, dynamic> data) async {
    try {
      await _restoreQueue(data);
    } catch (_) {
      // A malformed saved position must not interrupt a later folder refresh.
    } finally {
      _restoring = false;
    }
  }

  void _scheduleCheckpoint() {
    // Throttle position writes instead of writing on every player stream event.
    if (_disposed || _restoring || _checkpointTimer != null) return;
    _checkpointTimer = Timer(const Duration(seconds: 10), () {
      _checkpointTimer = null;
      unawaited(savePlayback());
    });
  }

  Future<void> savePlayback() async {
    if (_disposed ||
        _restoring ||
        playback.busy ||
        (_deferredPlayback != null && !playback.hasQueueIntent)) {
      return;
    }
    try {
      await store.write('playback', playback.checkpoint());
    } catch (_) {
      // A checkpoint write failure must not interrupt the current audio.
    }
  }

  // Share one cleanup Future when several owners request shutdown.
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    if (_disposed) return;
    await savePlayback();
    _disposed = true;
    _checkpointTimer?.cancel();
    playback.removeListener(_scheduleCheckpoint);
    playback.progress.removeListener(_scheduleCheckpoint);
    playback.onQualifiedPlay = null;
    playback.onQueueChanged = null;
    library.removeListener(_retryRestore);
    playback.dispose();
    library.dispose();
    settings.dispose();
    await store.flush();
  }
}

