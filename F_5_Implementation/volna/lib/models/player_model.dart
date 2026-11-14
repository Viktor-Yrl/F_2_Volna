import 'dart:async';

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'media.dart';
import 'services/radio_resolver.dart';
import 'services/radio_artwork_cache.dart';
import 'listening_tracker.dart';
import 'ui_message.dart';

/// Owns the single audio engine and exposes stream-driven state to the UI.
class PlayerModel extends ChangeNotifier {
  PlayerModel({AudioPlayer? player, RadioResolver? radioResolver})
    : _player = player ?? AudioPlayer(),
      _radioResolver = radioResolver ?? RadioResolver() {
    // Streams push engine events asynchronously; subscriptions are cancelled on dispose.
    _subscriptions.addAll([
      _player.playerStateStream.listen((state) {
        if (_disposed) return;
        playing =
            !_failed &&
            state.playing &&
            state.processingState != ProcessingState.completed;
        completed = state.processingState == ProcessingState.completed;
        buffering =
            state.processingState == ProcessingState.buffering ||
            state.processingState == ProcessingState.loading;
        if (completed && duration > Duration.zero) _position.value = duration;
        _sampleListening(position);
        _notify();
      }),
      _player.positionStream.listen((value) {
        if (!_disposed) {
          _sampleListening(value);
          _position.value = value;
        }
      }),
      _player.durationStream.listen((value) {
        if (_disposed) return;
        duration = current?.isRadio == true
            ? Duration.zero
            : value ?? Duration(milliseconds: current?.durationMs ?? 0);
        _notify();
      }),
      _player.currentIndexStream.listen((value) {
        if (_disposed || value == null || value < 0 || value >= _queue.length) {
          return;
        }
        if (index != value) _listening.reset();
        index = value;
        _notify();
      }),
      _player.errorStream.listen((failure) {
        if (_disposed) return;
        debugPrint('Audio playback error: $failure');
        _fail(MessageId.playbackFailed);
        _notify();
      }),
    ]);
  }
  final AudioPlayer _player;
  final RadioResolver _radioResolver;
  final _artwork = RadioArtworkCache();
  void Function(Track)? onQualifiedPlay;
  void Function(List<Track>)? onQueueChanged;
  bool _hasQueueIntent = false;
  bool get hasQueueIntent => _hasQueueIntent;
  late final _listening = ListeningTracker(
    (track) => onQualifiedPlay?.call(track),
  );
  final _subscriptions = <StreamSubscription<dynamic>>[];
  List<Track> _queue = const [];
  // Getter: expose the immutable queue without allocating a copy for each read.
  List<Track> get queue => _queue;
  int index = 0;
  Track? get current =>
      index >= 0 && index < _queue.length ? _queue[index] : null;
  bool _disposed = false, _failed = false, _command = false;
  int _generation = 0;
  bool playing = false, completed = false, buffering = false, busy = false;
  bool shuffle = false;
  RepeatMode repeat = RepeatMode.off;
  // Position ticks update progress views and checkpoints, not track lists.
  // Separate progress notifications keep frequent timer ticks away from track lists.
  final _position = ValueNotifier(Duration.zero);
  ValueListenable<Duration> get progress => _position;
  Duration get position => _position.value;
  Duration duration = Duration.zero;
  UiMessage? error;
  bool get canSeek =>
      !_disposed &&
      current != null &&
      !current!.isRadio &&
      duration > Duration.zero &&
      !busy &&
      !_command;
  bool get hasNext =>
      !_disposed && !busy && _queue.length > 1 && _player.hasNext;
  bool get hasPrevious =>
      !_disposed && !busy && current != null && !current!.isRadio;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // Use one eligibility rule for both position events and playback-state changes.
  void _sampleListening(Duration at) => _listening.sample(
    current,
    at,
    duration,
    active: playing && !buffering && !busy && !_command,
  );

  void _fail(MessageId fallback, {UiMessage? message}) {
    _failed = true;
    playing = false;
    error =
        message ??
        UiMessage(
          current?.isRadio == true ? MessageId.stationUnavailable : fallback,
        );
  }

  void clearError() {
    error = null;
    _notify();
  }

  Future<void> playTracks(
    List<Track> tracks, {
    int startIndex = 0,
    bool autoplay = true,
    Duration initialPosition = Duration.zero,
  }) async {
    if (_disposed || busy || tracks.isEmpty) return;
    final queue = List<Track>.unmodifiable(tracks);
    // A later stop/load invalidates pending async work from this generation.
    // Generation token: after each await, verify that this operation still owns playback.
    final generation = ++_generation;
    // Commands from the previous queue no longer own the transport lock.
    _command = false;
    _hasQueueIntent = true;
    busy = true;
    error = null;
    _notify();
    try {
      await _player.stop();
      if (_disposed || generation != _generation) return;
      _queue = queue;
      onQueueChanged?.call(_queue);
      _listening.reset();
      index = startIndex.clamp(0, _queue.length - 1);
      _position.value = _queue[index].isRadio ? Duration.zero : initialPosition;
      duration = Duration(milliseconds: _queue[index].durationMs);
      completed = false;
      _notify();
      // Translate domain tracks into engine sources; media tags power system controls.
      final sources = <AudioSource>[];
      // Resolve station streams and attach local artwork for system media controls.
      for (final track in _queue) {
        final uri = track.isRadio && autoplay
            ? await _radioResolver.resolve(track.uri)
            : Uri.parse(track.uri);
        final artwork = track.isRadio ? await _artwork.uriFor(track) : null;
        if (_disposed || generation != _generation) return;
        sources.add(
          AudioSource.uri(
            uri,
            tag: MediaItem(
              id: track.id,
              title: track.title,
              artist: track.artist,
              album: track.isRadio ? 'Live radio' : track.album,
              duration: track.durationMs > 0
                  ? Duration(milliseconds: track.durationMs)
                  : null,
              isLive: track.isRadio,
              artUri: artwork,
            ),
          ),
        );
      }
      await _player
          .setAudioSources(
            sources,
            initialIndex: index,
            initialPosition: position,
            preload: autoplay,
          )
          .timeout(const Duration(seconds: 30));
      if (_disposed || generation != _generation) return;
      await _player.setLoopMode(
        current!.isRadio ? LoopMode.off : LoopMode.values.byName(repeat.name),
      );
      if (_disposed || generation != _generation) return;
      await _player.setShuffleModeEnabled(!current!.isRadio && shuffle);
      if (_disposed || generation != _generation) return;
      if (shuffle && !current!.isRadio) await _player.shuffle();
      if (_disposed || generation != _generation) return;
      _failed = false;
      if (autoplay) unawaited(_play());
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      debugPrint('Audio source load error: $failure');
      _fail(
        MessageId.sourceUnavailable,
        message: failure is LocalizedException ? failure.localized : null,
      );
      try {
        await _player.stop();
      } catch (_) {}
    } finally {
      if (generation == _generation) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> _play() async {
    final generation = _generation;
    try {
      await _player.play();
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _fail(MessageId.playbackFailed);
        _notify();
      }
    }
  }

  Future<void> toggle() async {
    if (_disposed || current == null || busy || _command) return;
    if (_failed || (current!.isRadio && !playing)) {
      await playTracks(_queue, startIndex: index);
      return;
    }
    final generation = _generation;
    await _safe(() async {
      if (playing) {
        await _player.pause();
      } else {
        if (completed) {
          _listening.reset();
          await _player.seek(Duration.zero);
        }
        if (!_disposed && generation == _generation) unawaited(_play());
      }
    }, failure: MessageId.toggleFailed);
  }

  Future<void> seek(Duration value) async {
    if (!canSeek) return;
    await _safe(
      () => _player.seek(
        Duration(
          milliseconds: value.inMilliseconds.clamp(0, duration.inMilliseconds),
        ),
      ),
    );
  }

  Future<void> next() async {
    if (hasNext) {
      if (_failed) {
        await playTracks(_queue, startIndex: _player.nextIndex ?? index);
      } else {
        await _safe(_player.seekToNext);
      }
    }
  }

  Future<void> previous() async {
    if (!hasPrevious) return;
    if (_failed) {
      await playTracks(_queue, startIndex: _player.previousIndex ?? index);
      return;
    }
    await _safe(
      () => _player.hasPrevious
          ? _player.seekToPrevious()
          : _player.seek(Duration.zero),
    );
  }

  Future<void> selectQueueIndex(int value) async {
    if (_disposed || busy || _command || value < 0 || value >= _queue.length) {
      return;
    }
    if (_failed || current?.isRadio == true) {
      await playTracks(_queue, startIndex: value);
      return;
    }
    final success = await _safe(
      () => _player.seek(Duration.zero, index: value),
    );
    if (!_disposed && success) unawaited(_play());
  }

  Future<void> setRepeat(RepeatMode value) async {
    final success = await _safe(
      () => _player.setLoopMode(
        current?.isRadio == true
            ? LoopMode.off
            : LoopMode.values.byName(value.name),
      ),
    );
    if (success) repeat = value;
    _notify();
  }

  Future<void> setShuffle(bool value) async {
    final generation = _generation;
    final success = await _safe(() async {
      await _player.setShuffleModeEnabled(current?.isRadio != true && value);
      if (value && !_disposed && generation == _generation) {
        await _player.shuffle();
      }
    });
    if (success) shuffle = value;
    _notify();
  }

  Future<void> stop({bool clearQueue = false}) async {
    if (_disposed) return;
    final generation = ++_generation;
    busy = true;
    _command = false;
    _notify();
    try {
      await _player.stop();
      if (_disposed || generation != _generation) return;
      if (clearQueue) await _player.clearAudioSources();
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error = const UiMessage(MessageId.stopFailed);
      }
    }
    if (_disposed || generation != _generation) return;
    if (clearQueue) {
      _hasQueueIntent = true;
      _queue = const [];
      onQueueChanged?.call(_queue);
      index = 0;
      _position.value = Duration.zero;
      duration = Duration.zero;
    }
    playing = false;
    buffering = false;
    completed = false;
    busy = false;
    _notify();
  }

  // Serialize transport commands and report failures without throwing into the UI.
  Future<bool> _safe(
    Future<void> Function() action, {
    MessageId failure = MessageId.playerCommandFailed,
  }) async {
    // Serialize transport commands and ignore results from superseded loads.
    if (_disposed || busy || _command) return false;
    final generation = _generation;
    _command = true;
    error = null;
    _notify();
    try {
      await action();
      return !_disposed && generation == _generation;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error = UiMessage(failure);
      }
      return false;
    } finally {
      if (generation == _generation) {
        _command = false;
        _notify();
      }
    }
  }

  Map<String, dynamic> checkpoint() => {
    'ids': _queue.map((e) => e.id).toList(),
    'currentId': current?.id,
    'positionMs': current?.isRadio == true ? 0 : position.inMilliseconds,
    'repeat': repeat.name,
    'shuffle': shuffle,
  };
  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    _position.dispose();
    super.dispose();
  }
}

