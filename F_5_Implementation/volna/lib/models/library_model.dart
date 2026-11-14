import 'package:flutter/foundation.dart';

import 'services/library_store.dart';
import 'services/media_library.dart';
import 'media.dart';
import 'radio_catalog.dart';
import 'ui_message.dart';

/// Owns library metadata; device files and selected folders remain external.
class LibraryModel extends ChangeNotifier {
  LibraryModel({required this.store, MediaLibrary? media})
    : media = media ?? MediaLibrary();
  final LibraryStore store;
  final MediaLibrary media;
  bool get supportsFolders => media.supported;
  final List<MusicFolder> _folders = [];
  Set<String>? _savedRoots;
  Set<String> _queueRoots = {};
  bool _incompleteScan = false;
  bool get incompleteScan => _incompleteScan;
  Map<String, Track> _tracksById = {};
  // Membership is kept per selected root; overlapping roots share track IDs.
  final Map<String, List<Track>> _tracksByFolder = {};
  List<Track> tracksForFolder(String uri) =>
      List.unmodifiable(_tracksByFolder[uri] ?? const <Track>[]);
  final Map<String, int> _playCounts = {};
  List<MusicFolder> get folders => List.unmodifiable(_folders);
  int playCount(String id) => _playCounts[id] ?? 0;
  // Compute ranking from local track counts; radio is not part of this chart.
  List<Track> get topTracks {
    final ranked = tracks
        .where((e) => !e.isRadio && playCount(e.id) > 0)
        .toList();
    ranked.sort((a, b) {
      final count = playCount(b.id).compareTo(playCount(a.id));
      return count != 0
          ? count
          : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return ranked.take(100).toList();
  }

  bool _disposed = false;
  Future<void>? _initialization;
  bool busy = false;
  UiMessage? error;
  List<Track> get tracks => List.unmodifiable(_tracksById.values);
  List<Track> get stations => RadioCatalog.stations;
  Track? find(String id) =>
      _tracksById[id] ??
      stations.where((station) => station.id == id).firstOrNull;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void clearError() {
    error = null;
    _notify();
  }

  // A document URI contains the exact tree grant used to open it. Overlapping
  // roots may expose the same song through different grants.
  Future<void> updateQueueRoots(List<Track> queue) async {
    _queueRoots = {
      for (final track in queue)
        if (track.uri.startsWith('content://') &&
            track.uri.contains('/document/'))
          track.uri.substring(0, track.uri.indexOf('/document/')),
    };
    if (!busy) await _syncGrants();
  }

  Future<void> _syncGrants() async {
    final saved = _savedRoots;
    if (saved == null || _disposed) return;
    try {
      await media.keepFolderGrants({
        ...saved,
        ..._folders.map((f) => f.uri),
        ..._queueRoots,
      });
    } catch (_) {
      error = const UiMessage(MessageId.folderCleanupFailed);
      _notify();
    }
  }

  Future<void> initialize() async {
    if (_disposed) return;
    await (_initialization ??= _initialize());
  }

  Future<void> _initialize() async {
    // Restore user metadata before scanning currently accessible audio sources.
    busy = true;
    _notify();
    try {
      final data = await store.read('library');
      if (_disposed) return;
      _folders.addAll(
        (data['folders'] as List? ?? []).map(
          (e) => MusicFolder.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
      final counts = Map<String, dynamic>.from(
        data['playCounts'] as Map? ?? {},
      );
      for (final entry in counts.entries) {
        if (entry.key.startsWith('folder:') &&
            entry.value is num &&
            (entry.value as num) > 0) {
          _playCounts[entry.key] = (entry.value as num).toInt();
        }
      }
      error = store.warning;
      if (error == null) _savedRoots = _folders.map((f) => f.uri).toSet();
      await _refreshFolders();
    } catch (_) {
      _incompleteScan = true;
      error = const UiMessage(MessageId.libraryLoadFailed);
    } finally {
      busy = false;
      await _syncGrants();
      _notify();
    }
  }

  Future<void> scan() async {
    if (!media.supported) return;
    await _runFolderAction(
      _refreshFolders,
      failure: MessageId.libraryScanFailed,
    );
  }

  // Shared async lifecycle: mark busy, run the action, then release busy state.
  // finally also runs on cancellation, early return or failure.
  Future<void> _runFolderAction(
    Future<void> Function() action, {
    MessageId? failure,
  }) async {
    if (_disposed || busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
    } catch (_) {
      if (failure == null) rethrow;
      error = UiMessage(failure);
    } finally {
      busy = false;
      await _syncGrants();
      _notify();
    }
  }

  // Build a complete scan snapshot before replacing visible library data.
  Future<void> _refreshFolders({
    Map<String, List<Track>> scanned = const {},
  }) async {
    final tracks = <String, Track>{};
    final failed = <String>[];
    final byFolder = <String, List<Track>>{};
    for (final folder in _folders) {
      try {
        final rows = scanned[folder.uri] ?? await media.scanFolder(folder.uri);
        if (_disposed) return;
        final found =
            {for (final track in rows) track.id: track}.values.toList()..sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
            );
        byFolder[folder.uri] = found;
        for (final track in found) {
          tracks.putIfAbsent(track.id, () => track);
        }
      } catch (_) {
        failed.add(folder.name);
      }
    }
    if (_disposed) return;
    _tracksByFolder
      ..clear()
      ..addAll(byFolder);
    _tracksById = tracks;
    _incompleteScan = failed.isNotEmpty;
    if (failed.isNotEmpty) {
      error = UiMessage(MessageId.foldersUnavailable, names: failed.join(', '));
    }
  }

  Future<void> addFolder() async {
    if (!media.supported) return;
    await _runFolderAction(() async {
      final folder = await media.pickFolder();
      if (_disposed || folder == null) return;
      // Keep the current library intact until the new folder is readable.
      final rows = await media.scanFolder(folder.uri);
      if (_disposed) return;
      _folders.removeWhere((e) => e.uri == folder.uri);
      _folders.add(folder);
      await _refreshFolders(scanned: {folder.uri: rows});
      await save();
    }, failure: MessageId.folderOpenFailed);
  }

  Future<void> removeFolder(String uri) => _runFolderAction(() async {
    _folders.removeWhere((e) => e.uri == uri);
    await _refreshFolders();
    await save();
  });

  // Called only when ListeningTracker qualifies a play, not on every tap.
  Future<void> recordPlay(Track track) async {
    if (_disposed || track.isRadio) return;
    _playCounts.update(track.id, (value) => value + 1, ifAbsent: () => 1);
    _notify();
    await save();
  }

  Future<void> save() async {
    if (_disposed) return;
    final roots = _folders.map((f) => f.uri).toSet();
    try {
      await store.write('library', {
        'version': 3,
        'folders': _folders.map((e) => e.toJson()).toList(),
        'playCounts': _playCounts,
      });
      _savedRoots = roots;
    } catch (_) {
      error = const UiMessage(MessageId.saveFailed);
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

