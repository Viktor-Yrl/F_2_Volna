import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player_full/controllers/playback_controller.dart';
import 'package:music_player_full/models/app_model.dart';
import 'package:music_player_full/models/library_model.dart';
import 'package:music_player_full/models/media.dart';
import 'package:music_player_full/models/player_model.dart';
import 'package:music_player_full/models/settings_model.dart';
import 'package:music_player_full/models/services/library_store.dart';
import 'package:music_player_full/models/services/media_library.dart';

import 'fake_player.dart';
import 'playback_test.dart' show OfflineRadio;

class MemoryStore extends LibraryStore {
  MemoryStore() : super(directory: Future.value(Directory.systemTemp));
  final data = <String, Map<String, dynamic>>{};
  Completer<Map<String, dynamic>>? pendingSettings, pendingPlayback;
  int writes = 0;
  @override
  Future<Map<String, dynamic>> read(String name) async {
    if (name == 'settings' && pendingSettings != null) {
      return pendingSettings!.future;
    }
    if (name == 'playback' && pendingPlayback != null) {
      return pendingPlayback!.future;
    }
    return Map.of(data[name] ?? {});
  }

  @override
  Future<void> write(String name, Map<String, dynamic> value) async {
    writes++;
    data[name] = value;
  }
}

class DelayedMedia extends MediaLibrary {
  final permission = Completer<void>();
  Completer<MusicFolder?>? picker;
  Completer<List<Track>>? scan;
  int requests = 0, scans = 0;
  @override
  bool get supported => true;
  @override
  Future<void> requestNotifications() {
    requests++;
    return permission.future;
  }

  @override
  Future<MusicFolder?> pickFolder() async => picker?.future;
  @override
  Future<List<Track>> scanFolder(String uri) async {
    scans++;
    return scan == null ? [] : await scan!.future;
  }

  @override
  Future<void> keepFolderGrants(Set<String> roots) async {}
}

class DelayedStopPlayer extends FakePlayer {
  bool delayNextStop = false;
  final releaseStop = Completer<void>();
  @override
  Future<void> stop() async {
    final delay = delayNextStop;
    delayNextStop = false;
    await super.stop();
    if (delay) await releaseStop.future;
  }
}

const tracks = [
  Track(id: 'folder:a', uri: 'file:///a.mp3', title: 'A', durationMs: 60000),
  Track(id: 'folder:b', uri: 'file:///b.mp3', title: 'B', durationMs: 60000),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'only latest selection plays after one shared permission request',
    () async {
      final media = DelayedMedia();
      final library = LibraryModel(store: MemoryStore(), media: media);
      final player = PlayerModel(player: FakePlayer());
      addTearDown(library.dispose);
      addTearDown(player.dispose);
      final controller = PlaybackController(player, library);
      final first = controller.playTracks(tracks);
      final second = controller.playTracks(tracks, startIndex: 1);
      expect(media.requests, 1);
      media.permission.complete();
      await Future.wait([first, second]);
      expect(player.current?.id, 'folder:b');
    },
  );

  test('Stop cancels playback awaiting notification permission', () async {
    final media = DelayedMedia();
    final library = LibraryModel(store: MemoryStore(), media: media);
    final native = FakePlayer();
    final player = PlayerModel(player: native);
    addTearDown(library.dispose);
    addTearDown(player.dispose);
    final controller = PlaybackController(player, library);
    final pending = controller.playTracks(tracks);
    await controller.stop(clearQueue: true);
    media.permission.complete();
    await pending;
    expect(player.current, isNull);
    expect(native.active, isFalse);
  });

  for (final pause in [true, false]) {
    test('new transport pause=$pause supersedes pending selection', () async {
      final media = DelayedMedia();
      final library = LibraryModel(store: MemoryStore(), media: media);
      final player = PlayerModel(player: FakePlayer());
      addTearDown(library.dispose);
      addTearDown(player.dispose);
      await player.playTracks(tracks);
      final controller = PlaybackController(player, library);
      final pending = controller.playTracks([tracks.first]);
      if (pause) {
        await controller.toggle();
      } else {
        await controller.selectQueueIndex(1);
      }
      media.permission.complete();
      await pending;
      expect(player.playing, !pause);
      expect(player.current?.id, pause ? 'folder:a' : 'folder:b');
    });
  }

  test('stale stop completion cannot clear a replacement queue', () async {
    final native = DelayedStopPlayer();
    final player = PlayerModel(player: native);
    addTearDown(player.dispose);
    await player.playTracks(tracks);
    native.delayNextStop = true;
    final pending = player.stop(clearQueue: true);
    await player.stop();
    await player.playTracks([tracks.last]);
    native.releaseStop.complete();
    await pending;
    expect(player.current?.id, 'folder:b');
    expect(native.length, 1);
    expect(native.cleared, isFalse);
  });

  test('queue selection recovers after a decoder error', () async {
    final native = FakePlayer();
    final player = PlayerModel(player: native);
    addTearDown(player.dispose);
    await player.playTracks(tracks);
    native.errors.add(PlayerException(1, 'Bad file', 0));
    await player.selectQueueIndex(1);
    expect(player.current?.id, 'folder:b');
    expect(player.playing, isTrue);
    expect(player.error, isNull);
  });

  for (final forward in [true, false]) {
    test('skip forward=$forward recovers after a decoder error', () async {
      final native = FakePlayer();
      final player = PlayerModel(player: native);
      addTearDown(player.dispose);
      await player.playTracks(tracks, startIndex: forward ? 0 : 1);
      native.errors.add(PlayerException(1, 'Bad file', 0));
      if (forward) {
        await player.next();
      } else {
        await player.previous();
      }
      expect(player.current?.id, forward ? 'folder:b' : 'folder:a');
      expect(player.playing, isTrue);
      expect(player.error, isNull);
    });
  }

  test(
    'restored radio queue selection resolves and loads the station',
    () async {
      final native = FakePlayer();
      final player = PlayerModel(player: native, radioResolver: OfflineRadio());
      addTearDown(player.dispose);
      await player.playTracks([
        const Track(
          id: 'radio:test',
          uri: 'https://example.com/live',
          title: 'Radio',
          isRadio: true,
        ),
      ], autoplay: false);
      expect(native.preloaded, isFalse);
      await player.selectQueueIndex(0);
      expect(native.preloaded, isTrue);
      expect(player.playing, isTrue);
    },
  );

  test('disposed player ignores transport and late index events', () async {
    final native = FakePlayer();
    final player = PlayerModel(player: native);
    await player.playTracks(tracks);
    native.indexes.add(-1);
    expect(player.current?.id, 'folder:a');
    player.dispose();
    await player.seek(const Duration(seconds: 4));
    await player.next();
    await player.previous();
    await player.selectQueueIndex(1);
    expect(native.lastSeek, Duration.zero);
  });

  test(
    'startup checkpoint cannot overwrite newly selected playback modes',
    () async {
      final store = MemoryStore()..pendingPlayback = Completer();
      final app = AppModel(
        library: LibraryModel(store: store, media: DelayedMedia()),
        playback: PlayerModel(player: FakePlayer()),
      );
      addTearDown(app.dispose);
      final initializing = app.initialize();
      await Future<void>.delayed(Duration.zero);
      await app.playback.playTracks(tracks);
      await app.playback.setRepeat(RepeatMode.one);
      await app.playback.setShuffle(true);
      store.pendingPlayback!.complete({'repeat': 'off', 'shuffle': false});
      await initializing;
      expect(app.playback.repeat, RepeatMode.one);
      expect(app.playback.shuffle, isTrue);
    },
  );

  test('concurrent AppModel disposal completes only once', () async {
    final app = AppModel(
      library: LibraryModel(store: MemoryStore(), media: DelayedMedia()),
      playback: PlayerModel(player: FakePlayer()),
    );
    await app.initialize();
    await Future.wait([app.dispose(), app.dispose()]);
  });

  test('early language change preserves the saved light theme', () async {
    final store = MemoryStore()..pendingSettings = Completer();
    final settings = SettingsModel(store);
    addTearDown(settings.dispose);
    final initializing = settings.initialize();
    final saving = settings.setLanguage('ru');
    store.pendingSettings!.complete({'language': 'en', 'theme': 'light'});
    await Future.wait([initializing, saving]);
    expect(settings.languageCode, 'ru');
    expect(settings.lightTheme, isTrue);
    expect(store.data['settings'], {'language': 'ru', 'theme': 'light'});
  });

  test('late settings reload cannot undo a completed user change', () async {
    final store = MemoryStore();
    final settings = SettingsModel(store);
    addTearDown(settings.dispose);
    await settings.initialize();
    store.pendingSettings = Completer();
    final loading = settings.initialize();
    await settings.setLanguage('ru');
    store.pendingSettings!.complete({'language': 'en'});
    await loading;
    expect(settings.languageCode, 'ru');
  });

  test('library initialization is idempotent', () async {
    final store = MemoryStore()
      ..data['library'] = {
        'folders': [
          {'uri': 'tree:a', 'name': 'A'},
        ],
      };
    final media = DelayedMedia();
    final library = LibraryModel(store: store, media: media);
    addTearDown(library.dispose);
    await Future.wait([library.initialize(), library.initialize()]);
    expect(library.folders, hasLength(1));
    expect(media.scans, 1);
  });

  test(
    'closing a picker after model disposal cannot persist a new folder',
    () async {
      final store = MemoryStore();
      final media = DelayedMedia()..picker = Completer();
      final library = LibraryModel(store: store, media: media);
      await library.initialize();
      final picking = library.addFolder();
      library.dispose();
      media.picker!.complete(const MusicFolder(uri: 'tree:a', name: 'A'));
      await picking;
      expect(media.scans, 0);
      expect(store.writes, 0);
    },
  );

  test(
    'refresh retains its visible snapshot until scanning completes',
    () async {
      final store = MemoryStore()
        ..data['library'] = {
          'folders': [
            {'uri': 'tree:a', 'name': 'A'},
          ],
        };
      final media = DelayedMedia()..scan = Completer();
      final library = LibraryModel(store: store, media: media);
      addTearDown(library.dispose);
      final loading = library.initialize();
      media.scan!.complete(tracks);
      await loading;
      media.scan = Completer();
      final refreshing = library.scan();
      expect(library.tracksForFolder('tree:a'), tracks);
      media.scan!.complete([tracks.last]);
      await refreshing;
      expect(library.tracksForFolder('tree:a'), [tracks.last]);
    },
  );

  test('reads wait for snapshots queued before the read', () async {
    final root = await Directory.systemTemp.createTemp('volna_read_order_');
    final store = LibraryStore(directory: Future.value(root));
    addTearDown(() async {
      await store.flush();
      await root.delete(recursive: true);
    });
    await store.write('settings', {'language': 'en'});
    final writing = store.write('settings', {'language': 'ru'});
    final data = await store.read('settings');
    await writing;
    expect(data['language'], 'ru');
  });
}
