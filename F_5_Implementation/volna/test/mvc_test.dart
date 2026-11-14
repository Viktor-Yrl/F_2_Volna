import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_full/controllers/app_controller.dart';
import 'package:music_player_full/models/app_model.dart';
import 'package:music_player_full/models/library_model.dart';
import 'package:music_player_full/models/media.dart';
import 'package:music_player_full/models/player_model.dart';
import 'package:music_player_full/models/services/library_store.dart';
import 'package:music_player_full/models/services/media_library.dart';

import 'fake_player.dart';

class DeniedNotifications extends MediaLibrary {
  int requests = 0;
  @override
  Future<void> requestNotifications() async {
    requests++;
    throw StateError('Permission denied');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Model and Controller cannot depend on View or UI frameworks', () {
    for (final layer in ['models', 'controllers']) {
      for (final file
          in Directory('lib/$layer')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final imports = file.readAsLinesSync().where(
          (line) => line.startsWith('import ') || line.startsWith('export '),
        );
        for (final directive in imports) {
          expect(directive, isNot(contains('/views/')), reason: file.path);
          expect(
            directive,
            isNot(contains('/controllers/')),
            reason: file.path,
          );
          for (final ui in [
            'flutter/material.dart',
            'flutter/widgets.dart',
            'flutter/cupertino.dart',
          ]) {
            expect(directive, isNot(contains(ui)), reason: file.path);
          }
        }
      }
    }
  });

  test('Views cannot import technical services or audio engines', () {
    for (final file
        in Directory('lib/views')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      for (final line in file.readAsLinesSync().where(
        (line) => line.startsWith('import '),
      )) {
        for (final dependency in [
          '/services/',
          'just_audio/',
          'audio_session/',
          'path_provider/',
          'dart:io',
        ]) {
          expect(line, isNot(contains(dependency)), reason: file.path);
        }
      }
    }
  });

  test('lib contains exactly the three MVC layers and main.dart', () {
    expect(
      Directory('lib').listSync().whereType<Directory>().map(
        (d) => d.uri.pathSegments.where((p) => p.isNotEmpty).last,
      ),
      unorderedEquals(['models', 'views', 'controllers']),
    );
    expect(
      Directory(
        'lib',
      ).listSync().whereType<File>().map((f) => f.uri.pathSegments.last),
      ['main.dart'],
    );
  });

  group('Controller commands', () {
    late Directory root;
    late AppModel model;
    late AppController controller;
    late FakePlayer engine;
    late DeniedNotifications media;
    const tracks = [
      Track(id: 'one', uri: 'file:///one.mp3', title: 'One'),
      Track(id: 'two', uri: 'file:///two.mp3', title: 'Two'),
    ];
    setUp(() async {
      root = await Directory.systemTemp.createTemp('volna_mvc_');
      model = AppModel(
        library: LibraryModel(
          store: LibraryStore(directory: Future.value(root)),
          media: media = DeniedNotifications(),
        ),
        playback: PlayerModel(player: engine = FakePlayer()),
      );
      controller = AppController(model);
      await controller.initialize();
    });
    tearDown(() async {
      await model.dispose();
      await root.delete(recursive: true);
    });

    test('denied notifications do not block selected-track playback', () async {
      await controller.playback.playTracks(tracks, startIndex: 1);
      expect(media.requests, 1);
      expect(model.playback.current?.id, 'two');
      expect(engine.active, isTrue);
    });

    test(
      'repeat cycles off-all-one-off and shuffle updates the Model',
      () async {
        await controller.playback.playTracks(tracks);
        for (final mode in [RepeatMode.all, RepeatMode.one, RepeatMode.off]) {
          await controller.playback.cycleRepeat();
          expect(model.playback.repeat, mode);
        }
        await controller.playback.toggleShuffle();
        expect(model.playback.shuffle, isTrue);
        await controller.playback.toggleShuffle();
        expect(model.playback.shuffle, isFalse);
      },
    );

    test('seek, queue selection and stop reach the audio Model', () async {
      await controller.playback.playTracks(tracks);
      engine.durations.add(const Duration(seconds: 60));
      await controller.playback.seek(const Duration(seconds: 12));
      expect(engine.lastSeek, const Duration(seconds: 12));
      await controller.playback.selectQueueIndex(1);
      expect(model.playback.current?.id, 'two');
      await controller.playback.stop(clearQueue: true);
      expect(model.playback.current, isNull);
      expect(engine.cleared, isTrue);
    });

    test('settings commands persist language and appearance', () async {
      await controller.settings.setLanguage('ru');
      await controller.settings.setLightTheme(true);
      expect(model.settings.languageCode, 'ru');
      expect(model.settings.lightTheme, isTrue);
      expect(await model.store.read('settings'), {
        'language': 'ru',
        'theme': 'light',
      });
    });
  });
}
