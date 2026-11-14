import 'package:music_player_full/controllers/app_controller.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_full/views/app_view.dart';
import 'package:music_player_full/models/app_model.dart';
import 'package:music_player_full/models/services/library_store.dart';
import 'package:music_player_full/models/services/media_library.dart';
import 'package:music_player_full/models/media.dart';
import 'package:music_player_full/models/radio_catalog.dart';
import 'package:music_player_full/views/l10n/strings.dart';
import 'package:music_player_full/views/l10n/app_localizations.dart';
import 'package:music_player_full/models/ui_message.dart';
import 'package:music_player_full/models/library_model.dart';
import 'package:music_player_full/models/player_model.dart';
import 'package:music_player_full/views/player_screen.dart';
import 'package:music_player_full/views/track_artwork.dart';

import 'fake_player.dart';

class _NoDeviceMedia extends MediaLibrary {
  @override
  bool get supported => false;
}

const _capture = bool.fromEnvironment('CAPTURE_PLAYER');
const _fontDirectory = String.fromEnvironment('QA_FONT_DIRECTORY');
const _captureKey = ValueKey('player-capture');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Optional real fonts make local QA captures readable; CI needs neither
    // these files nor a device, network connection or platform audio plugin.
    if (_capture && _fontDirectory.isNotEmpty) {
      for (final family in ['Roboto', 'MaterialIcons']) {
        final loader = FontLoader(family);
        final names = family == 'MaterialIcons'
            ? ['materialicons-regular.otf']
            : ['roboto-regular.ttf', 'roboto-bold.ttf'];
        for (final name in names) {
          loader.addFont(
            File(
              '$_fontDirectory/$name',
            ).readAsBytes().then(ByteData.sublistView),
          );
        }
        await loader.load();
      }
    }
  });

  late Directory root;
  late AppModel app;
  late FakePlayer native;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('volna_player_layout_');
    app = AppModel(
      library: LibraryModel(
        store: LibraryStore(directory: Future.value(root)),
        media: _NoDeviceMedia(),
      ),
      playback: PlayerModel(player: native = FakePlayer()),
    );
  });
  tearDown(() async {
    await app.dispose();
    await root.delete(recursive: true);
  });

  for (final size in [
    const Size(320, 400),
    const Size(320, 480),
    const Size(320, 568),
    const Size(360, 760),
    const Size(412, 915),
    const Size(568, 320),
    const Size(760, 360),
    const Size(1024, 768),
  ]) {
    for (final scenario in ['local', 'radio', 'large-text-error']) {
      testWidgets('all player controls fit $size / $scenario', (tester) async {
        tester.view.devicePixelRatio = 1;
        // Obtain the real app theme without laying out the unrelated home screen
        // at the player's deliberately extreme test sizes.
        tester.view.physicalSize = const Size(412, 915);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
        tester.platformDispatcher.textScaleFactorTestValue =
            scenario == 'large-text-error' ? 2 : 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final track = scenario == 'radio'
            ? RadioCatalog.stations.first
            : const Track(
                id: 'folder:long',
                uri: 'file:///music.mp3',
                title:
                    'Eminem - Lose Yourself(playvk.com) - A long track title',
                artist:
                    'A very long artist name that must not move the buttons',
                durationMs: 326000,
              );
        await tester.runAsync(() async {
          await app.initialize();
          await app.settings.setLightTheme(scenario == 'radio');
          if (scenario == 'large-text-error') {
            await app.settings.setLanguage('ru');
          }
          await app.playback.playTracks([track], autoplay: false);
        });
        await tester.pumpWidget(MusicApp(controller: AppController(app)));
        await tester.pumpAndSettle();
        var theme = Theme.of(tester.element(find.byType(Scaffold)));
        if (_capture && _fontDirectory.isNotEmpty) {
          // The test runner otherwise substitutes Ahem for unqualified app-bar
          // text; use the same Roboto family supplied by Android in real builds.
          theme = theme.copyWith(
            appBarTheme: theme.appBarTheme.copyWith(
              titleTextStyle:
                  (theme.appBarTheme.titleTextStyle ??
                          theme.textTheme.titleLarge!)
                      .copyWith(fontFamily: 'Roboto'),
            ),
          );
        }
        if (scenario == 'large-text-error') {
          app.playback.error = const UiMessage(MessageId.stationUnavailable);
        }
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('isolated-player'),
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => const SizedBox()),
            theme: theme,
            locale: Locale(app.settings.languageCode),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            onGenerateInitialRoutes: (_) => [
              MaterialPageRoute<void>(builder: (_) => const SizedBox()),
              MaterialPageRoute<void>(
                builder: (_) => RepaintBoundary(
                  key: _captureKey,
                  child: PlayerScreen(app: AppController(app)),
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(PlayerScreen));
        if (_capture) {
          await tester.runAsync(() async {
            for (final image in tester.widgetList<Image>(find.byType(Image))) {
              await precacheImage(image.image, context);
            }
          });
          await tester.pumpAndSettle();
          tester
              .renderObject<RenderRepaintBoundary>(find.byKey(_captureKey))
              .markNeedsPaint();
          await tester.pump();
        }
        final labels = context.l10n;
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.byType(Scrollable), findsNothing);
        for (final label in [
          labels.previousTrack,
          labels.play,
          labels.nextTrack,
          labels.shuffle,
          labels.repeatOff,
        ]) {
          final control = find.byTooltip(label);
          expect(control, findsOneWidget);
          final rect = tester.getRect(control);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.top, greaterThanOrEqualTo(24 + kToolbarHeight));
          expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
        }
        final art = tester.getSize(find.byType(TrackArtwork));
        expect(art.width, art.height);
        expect(tester.takeException(), isNull);

        if (_capture) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(_captureKey),
            );
            final rendered = await boundary.toImage(pixelRatio: 2);
            try {
              final bytes = await rendered.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final output = File(
                'build/player_layout_qa/${size.width.toInt()}x'
                '${size.height.toInt()}-$scenario.png',
              );
              await output.parent.create(recursive: true);
              await output.writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              rendered.dispose();
            }
          });
        }

        if (scenario == 'local') {
          await tester.tap(find.byTooltip(labels.play));
          await tester.pumpAndSettle();
          expect(native.active, isTrue);
          await tester.tap(find.byTooltip(labels.pause));
          await tester.pumpAndSettle();
          expect(native.active, isFalse);
          await tester.tap(find.byTooltip(labels.shuffle));
          await tester.pumpAndSettle();
          expect(app.playback.shuffle, isTrue);
          await tester.tap(find.byTooltip(labels.repeatOff));
          await tester.pumpAndSettle();
          expect(app.playback.repeat.name, 'all');
        } else if (scenario == 'large-text-error') {
          await tester.tap(find.byTooltip(labels.closeMessage));
          await tester.pumpAndSettle();
          expect(app.playback.error, isNull);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
