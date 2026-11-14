import 'package:music_player_full/controllers/app_controller.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_full/views/app_view.dart';
import 'package:music_player_full/models/app_model.dart';
import 'package:music_player_full/models/services/library_store.dart';
import 'package:music_player_full/models/services/media_library.dart';
import 'package:music_player_full/models/media.dart';
import 'package:music_player_full/models/library_model.dart';
import 'package:music_player_full/models/player_model.dart';
import 'package:music_player_full/views/player_screen.dart';
import 'package:music_player_full/views/track_tile.dart';
import 'package:music_player_full/models/ui_message.dart';
import 'package:music_player_full/views/l10n/strings.dart';
import 'fake_player.dart';

class OfflineMedia extends MediaLibrary {
  @override
  bool get supported => false;
  @override
  Future<List<Track>> scanFolder(String uri) async => [
    const Track(id: 'folder:one', uri: 'content://one', title: 'Local song'),
  ];
}

// Keep popup interaction tests independent of FakeAsync filesystem callbacks.
class MemoryLibraryStore extends LibraryStore {
  MemoryLibraryStore(Directory root) : super(directory: Future.value(root));
  final _data = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>> read(String name) async => _data[name] ?? {};
  @override
  Future<void> write(String name, Map<String, dynamic> data) async {
    _data[name] = data;
  }
}

void main() {
  late Directory root;
  late AppModel app;
  late FakePlayer native;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('music_widget_test_');
    final store = LibraryStore(directory: Future.value(root));
    app = AppModel(
      library: LibraryModel(store: store, media: OfflineMedia()),
      playback: PlayerModel(player: native = FakePlayer()),
    );
  });
  tearDown(() async {
    await app.dispose();
    await root.delete(recursive: true);
  });

  testWidgets(
    'shared mini-player controls retain transport and busy feedback',
    (tester) async {
      await app.playback.playTracks([
        const Track(
          id: 'a',
          uri: 'file:///a.mp3',
          title: 'A',
          durationMs: 60000,
        ),
        const Track(
          id: 'b',
          uri: 'file:///b.mp3',
          title: 'B',
          durationMs: 60000,
        ),
      ], autoplay: false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MiniPlayer(app: AppController(app))),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Play'));
      await tester.pumpAndSettle();
      expect(native.active, isTrue);
      await tester.tap(find.byTooltip('Next track'));
      await tester.pumpAndSettle();
      expect(app.playback.current?.id, 'b');
      await tester.tap(find.byTooltip('Previous track'));
      await tester.pumpAndSettle();
      expect(app.playback.current?.id, 'a');
      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();
      expect(native.active, isFalse);
      app.playback.busy = true;
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('busy'),
          home: Scaffold(body: MiniPlayer(app: AppController(app))),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      for (final button in tester.widgetList<IconButton>(
        find.byType(IconButton),
      )) {
        expect(button.onPressed, isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('shared error banner preserves bounded text and dismissal', (
    tester,
  ) async {
    var dismissed = 0;
    const message = UiMessage(MessageId.sourceUnavailable);
    for (final lines in <int?>[null, 1, 2]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorBanner(
              message: message,
              maxLines: lines,
              onDismiss: () => dismissed++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(ErrorBanner));
      final text = message.localize(context.l10n);
      expect(tester.widget<Text>(find.text(text)).maxLines, lines);
      expect(
        find.byTooltip(text),
        lines == null ? findsNothing : findsOneWidget,
      );
      await tester.tap(find.byTooltip(context.l10n.closeMessage));
      await tester.pump();
    }
    expect(dismissed, 3);
  });
  for (final size in [
    const Size(320, 640),
    const Size(412, 915),
    const Size(1024, 768),
  ]) {
    testWidgets('home and player layout at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(app.initialize);
      await tester.pumpWidget(MusicApp(controller: AppController(app)));
      await tester.pumpAndSettle();
      expect(find.text('Top 100'), findsWidgets);
      await tester.tap(find.text('Radio').last);
      await tester.pumpAndSettle();
      expect(find.text('BBC World Service'), findsOneWidget);
      // The catalog is longer than a phone viewport; verify its entire scroll.
      for (final station in app.library.stations) {
        await tester.scrollUntilVisible(
          find.text(station.title),
          160,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();
        expect(find.text(station.title), findsOneWidget);
        expect(find.text(station.artist), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(find.byTooltip('Добавить радио'), findsNothing);
      expect(find.byTooltip('Действия со станцией'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      await tester.tap(find.text('Playlists').last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add folder'), findsOneWidget);
      expect(find.text('Create playlist'), findsNothing);
      expect(find.text('Add files'), findsNothing);
      expect(tester.takeException(), isNull);
      await app.playback.playTracks([
        const Track(
          id: 't',
          uri: 'file:///one.mp3',
          title: 'Very long track name for layout validation',
          durationMs: 60000,
        ),
      ], autoplay: false);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Previous track'), findsOneWidget);
      native.positions.add(const Duration(seconds: 12));
      await tester.pump();
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .2,
      );
      await tester.tap(find.text('Top 100').last);
      await tester.pumpAndSettle();
      expect(find.text('No listening history yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: PlayerScreen(app: AppController(app)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsOneWidget);
      native.positions.add(const Duration(seconds: 15));
      await tester.pump();
      expect(find.text('0:15'), findsOneWidget);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 15000);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(app.dispose);
    });
  }
  testWidgets('ranking retains play counts without favorites', (tester) async {
    await tester.runAsync(app.dispose);
    await tester.runAsync(() async {
      final store = MemoryLibraryStore(root);
      app = AppModel(
        library: LibraryModel(store: store, media: OfflineMedia()),
        playback: PlayerModel(player: FakePlayer()),
      );
      await store.write('library', {
        'folders': [
          {'uri': 'tree:music', 'name': 'Music'},
        ],
      });
      await app.initialize();
      await app.library.recordPlay(app.library.tracks.single);
    });
    await tester.pumpWidget(MusicApp(controller: AppController(app)));
    await tester.pumpAndSettle();
    expect(find.text('Local song'), findsOneWidget);
    for (final light in [false, true]) {
      await tester.runAsync(() => app.settings.setLightTheme(light));
      await tester.pumpAndSettle();
      final count = find.text('1');
      final scheme = Theme.of(tester.element(count)).colorScheme;
      expect(tester.widget<Text>(count).style?.color, scheme.primary);
      expect(scheme.brightness, light ? Brightness.light : Brightness.dark);
    }
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.text('Add to playlist'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(app.dispose);
  });

  testWidgets('player tolerates zero first frame then normal screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size.zero;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: PlayerScreen(app: AppController(app))),
    );
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(412, 915);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
