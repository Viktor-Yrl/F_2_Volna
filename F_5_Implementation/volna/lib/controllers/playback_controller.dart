import '../models/library_model.dart';
import '../models/media.dart';
import '../models/player_model.dart';

/// Handles user commands; audio state and engine access stay in the Model.
class PlaybackController {
  PlaybackController(this._model, this._library);
  final PlayerModel _model;
  final LibraryModel _library;
  Future<void>? _notificationRequest;
  int _selection = 0;

  Future<void> playTracks(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    // Capture this command's ID before awaiting permission.
    // A newer command invalidates this ID so delayed work cannot start stale music.
    final selection = ++_selection;
    // Copy the selection before await so caller changes cannot alter this request.
    final queue = List<Track>.of(tracks);
    // Notification permission is optional and must not block playback.
    await (_notificationRequest ??= _requestNotifications());
    if (selection != _selection) return;
    await _model.playTracks(queue, startIndex: startIndex);
  }

  Future<void> _requestNotifications() async {
    try {
      await _library.media.requestNotifications();
    } catch (_) {
      // Android may reject or dismiss the permission request.
    } finally {
      _notificationRequest = null;
    }
  }

  // A newer transport command supersedes selection awaiting permission.
  Future<void> _transport(Future<void> Function() action) {
    ++_selection;
    return action();
  }

  Future<void> toggle() => _transport(_model.toggle);
  Future<void> seek(Duration position) =>
      _transport(() => _model.seek(position));
  Future<void> previous() => _transport(_model.previous);
  Future<void> next() => _transport(_model.next);
  Future<void> selectQueueIndex(int index) =>
      _transport(() => _model.selectQueueIndex(index));
  Future<void> stop({bool clearQueue = false}) =>
      _transport(() => _model.stop(clearQueue: clearQueue));

  Future<void> toggleShuffle() => _model.setShuffle(!_model.shuffle);
  // Cycle the domain enum: off -> repeat queue -> repeat one -> off.
  Future<void> cycleRepeat() => _model.setRepeat(switch (_model.repeat) {
    RepeatMode.off => RepeatMode.all,
    RepeatMode.all => RepeatMode.one,
    RepeatMode.one => RepeatMode.off,
  });
  void clearError() => _model.clearError();
}

