import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player_full/models/media.dart';
import 'package:music_player_full/models/services/radio_resolver.dart';
import 'package:music_player_full/models/player_model.dart';
import 'fake_player.dart';

class OfflineRadio extends RadioResolver {
  @override
  Future<Uri> resolve(String input, {int depth = 0}) async => Uri.parse(input);
}

void main() {
  const tracks = [
    Track(id: '1', uri: 'file:///1.mp3', title: 'One', durationMs: 60000),
    Track(id: '2', uri: 'file:///2.mp3', title: 'Two', durationMs: 60000),
  ];
  late FakePlayer native;
  late PlayerModel player;
  setUp(() {
    native = FakePlayer();
    player = PlayerModel(player: native, radioResolver: OfflineRadio());
  });
  tearDown(() {
    player.dispose();
  });
  test('queue, pause, seek bounds and next', () async {
    await player.playTracks(tracks);
    expect(player.playing, isTrue);
    await player.toggle();
    expect(player.playing, isFalse);
    await player.seek(const Duration(seconds: 99));
    expect(native.lastSeek.inSeconds, 60);
    await player.next();
    expect(player.current!.id, '2');
    await player.selectQueueIndex(0);
    expect(player.current!.id, '1');
  });
  test('queue is a stable read-only snapshot until it is replaced', () async {
    final selection = tracks.toList();
    final loading = player.playTracks(selection);
    selection.clear();
    await loading;
    final snapshot = player.queue;
    expect(snapshot, tracks);
    expect(player.queue, same(snapshot));
    expect(snapshot.clear, throwsUnsupportedError);
    await player.next();
    expect(player.queue, same(snapshot));
    await player.stop(clearQueue: true);
    expect(player.queue, isEmpty);
    expect(snapshot, tracks);
  });
  test('buffering ticks do not advance the listening threshold', () async {
    final counted = <Track>[];
    player.onQualifiedPlay = counted.add;
    await player.playTracks(tracks);
    native.states.add(PlayerState(true, ProcessingState.buffering));
    for (var s = 0; s <= 30; s++) {
      native.positions.add(Duration(seconds: s));
    }
    native.states.add(PlayerState(true, ProcessingState.ready));
    for (var s = 31; s < 60; s++) {
      native.positions.add(Duration(seconds: s));
    }
    expect(counted, isEmpty);
    native.positions.add(const Duration(seconds: 60));
    expect(counted, [tracks.first]);
  });
  test('restoration does not preload network or autoplay', () async {
    await player.playTracks(tracks, autoplay: false);
    expect(native.preloaded, isFalse);
    expect(native.active, isFalse);
  });
  test(
    'position ticks reach progress and checkpoints but not track lists',
    () async {
      await player.playTracks(tracks);
      var states = 0, ticks = 0;
      player.addListener(() => states++);
      player.progress.addListener(() => ticks++);
      native.positions.add(const Duration(seconds: 4));
      native.positions.add(const Duration(seconds: 5));
      expect(ticks, 2);
      expect(states, 0);
      expect(player.checkpoint()['positionMs'], 5000);
      await player.toggle();
      expect(states, greaterThan(0));
    },
  );
  test('stop invalidates pending load and clears native queue', () async {
    native.pendingLoad = Completer<Duration?>();
    final loading = player.playTracks(tracks);
    await Future<void>.delayed(Duration.zero);
    await player.stop(clearQueue: true);
    native.pendingLoad!.complete(const Duration(seconds: 60));
    await loading;
    expect(player.queue, isEmpty);
    expect(native.active, isFalse);
    expect(native.cleared, isTrue);
    expect(player.busy, isFalse);
    expect(player.error, isNull);
  });
  test('failed setting does not change repeat state', () async {
    native.failLoop = true;
    await player.setRepeat(RepeatMode.all);
    expect(player.repeat, RepeatMode.off);
    expect(player.error, isNotNull);
  });
  test('radio cannot seek', () async {
    await player.playTracks([
      const Track(
        id: 'r',
        uri: 'https://example.com/live',
        title: 'Radio',
        isRadio: true,
      ),
    ]);
    expect(player.canSeek, isFalse);
  });
  test('decoder failure cannot leave a misleading playing indicator', () async {
    await player.playTracks(tracks);
    native.errors.add(PlayerException(1, 'Decoder failed', 0));
    native.states.add(PlayerState(true, ProcessingState.idle));
    expect(player.playing, isFalse);
    expect(player.error, isNotNull);
    await player.toggle();
    expect(player.playing, isTrue);
    expect(player.error, isNull);
  });
}
