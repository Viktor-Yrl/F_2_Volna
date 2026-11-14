import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/media.dart';
import 'track_tile.dart';
import 'track_artwork.dart';
import 'l10n/strings.dart';
import '../models/player_model.dart';

/// Full player view; transport actions delegate to the playback controller.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.app});
  final AppController app;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // Open a modal view of the Model queue; selecting a row sends a Controller command.
  void _queue() {
    final player = widget.app.model.playback;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListenableBuilder(
            listenable: player,
            builder: (context, _) {
              final queue = player.queue;
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      context.l10n.playbackQueue,
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: queue.length,
                      itemBuilder: (context, i) => TrackTile(
                        track: queue[i],
                        app: widget.app,
                        onTap: () {
                          unawaited(widget.app.playback.selectQueueIndex(i));
                          Navigator.pop(context);
                        },
                        trailing: i == player.index
                            ? const Icon(Icons.equalizer_rounded)
                            : Text('${i + 1}'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.app.model.playback,
      widget.app.model.library,
    ]),
    builder: (context, _) {
      final player = widget.app.model.playback;
      final track = player.current;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            context.l10n.nowPlaying,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: context.l10n.queue,
              onPressed: track == null ? null : _queue,
              icon: const Icon(Icons.queue_music),
            ),
            IconButton(
              tooltip: context.l10n.stop,
              onPressed: track == null
                  ? null
                  : () => unawaited(widget.app.playback.stop(clearQueue: true)),
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth <= 48 || constraints.maxHeight <= 0) {
                // Android may report a zero-sized viewport during the first frame.
                return const SizedBox.shrink();
              }
              // Choose layout from the available viewport, including landscape and larger screens.
              final wide =
                  MediaQuery.orientationOf(context) == Orientation.landscape ||
                  constraints.maxWidth >= 760;
              final compact =
                  constraints.maxHeight < 520 ||
                  MediaQuery.textScalerOf(context).scale(24) > 30;
              final inlineModes = constraints.maxHeight < 380;
              final gap = inlineModes ? 4.0 : (compact ? 8.0 : 16.0);
              final controls = _controls(
                track,
                compact: compact,
                inlineModes: inlineModes,
              );
              final artwork = Column(
                children: [
                  Expanded(child: _artwork(track)),
                  if (wide && player.error != null) ...[
                    SizedBox(height: gap),
                    _error(compact: inlineModes),
                  ],
                ],
              );
              // Reserve the controls' natural height; only artwork gives up space.
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth < 360 ? 16 : 24,
                  vertical: wide && inlineModes
                      ? 0
                      : (inlineModes ? 4 : (compact ? 8 : 16)),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 940),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 4, child: artwork),
                              SizedBox(width: gap),
                              Expanded(flex: 6, child: Center(child: controls)),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(child: artwork),
                              SizedBox(height: gap),
                              controls,
                              if (player.error != null) ...[
                                SizedBox(height: gap),
                                _error(compact: inlineModes),
                              ],
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
  Widget _artwork(Track? track) => LayoutBuilder(
    builder: (context, constraints) {
      final side = math.min(constraints.maxWidth, constraints.maxHeight);
      if (side <= 0) return const SizedBox.shrink();
      return Center(
        child: SizedBox.square(
          dimension: side,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                TrackArtwork(track: track),
                if (widget.app.model.playback.busy ||
                    widget.app.model.playback.buffering)
                  const ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _error({required bool compact}) => ErrorBanner(
    message: widget.app.model.playback.error!,
    onDismiss: widget.app.playback.clearError,
    maxLines: compact ? 1 : 2,
  );

  Widget _controls(
    Track? track, {
    required bool compact,
    required bool inlineModes,
  }) {
    final app = widget.app;
    final player = app.model.playback;
    final repeatIcon = player.repeat == RepeatMode.one
        ? Icons.repeat_one_rounded
        : Icons.repeat_rounded;
    final repeatLabel = switch (player.repeat) {
      RepeatMode.off => context.l10n.repeatOff,
      RepeatMode.all => context.l10n.repeatAll,
      RepeatMode.one => context.l10n.repeatOne,
    };
    final shuffle = IconButton(
      tooltip: context.l10n.shuffle,
      isSelected: player.shuffle,
      onPressed: track != null && !track.isRadio && !player.busy
          ? () => unawaited(app.playback.toggleShuffle())
          : null,
      icon: const Icon(Icons.shuffle_rounded),
    );
    final repeat = IconButton(
      tooltip: repeatLabel,
      isSelected: player.repeat != RepeatMode.off,
      onPressed: track != null && !track.isRadio && !player.busy
          ? () => unawaited(app.playback.cycleRepeat())
          : null,
      icon: Icon(repeatIcon),
    );
    final title = track?.titleLabel(context) ?? context.l10n.noTrackSelected;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: title,
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          track?.artistLabel(context) ?? '',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            height: 1.25,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (track?.isRadio == true)
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
            child: Text(
              context.l10n.live,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          )
        else ...[
          SizedBox(height: compact ? 4 : 8),
          _SeekBar(
            key: ValueKey(track?.id),
            player: player,
            onSeek: app.playback.seek,
            inlineLabels: inlineModes,
          ),
        ],
        SizedBox(height: compact ? 4 : 8),
        Row(
          mainAxisAlignment: inlineModes
              ? MainAxisAlignment.spaceEvenly
              : MainAxisAlignment.center,
          children: [
            if (inlineModes) shuffle,
            _skipButton(context, app, forward: false, size: 34),
            if (!inlineModes) const SizedBox(width: 16),
            _playButton(context, app, size: compact ? 64 : 80),
            if (!inlineModes) const SizedBox(width: 16),
            _skipButton(context, app, size: 34),
            if (inlineModes) repeat,
          ],
        ),
        if (!inlineModes) ...[
          SizedBox(height: compact ? 4 : 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [shuffle, repeat],
          ),
        ],
      ],
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({
    super.key,
    required this.player,
    required this.onSeek,
    this.inlineLabels = false,
  });
  final PlayerModel player;
  final Future<void> Function(Duration) onSeek;
  final bool inlineLabels;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  // Local widget state: preview the thumb position while the user drags the slider.
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    return ValueListenableBuilder<Duration>(
      valueListenable: player.progress,
      builder: (context, position, _) {
        final max = math.max(1, player.duration.inMilliseconds).toDouble();
        final value = _drag ?? position.inMilliseconds.toDouble();
        final elapsed = formatTime(Duration(milliseconds: value.toInt()));
        final slider = Slider(
          value: value.clamp(0.0, max),
          max: max,
          label: elapsed,
          onChanged: player.canSeek ? (v) => setState(() => _drag = v) : null,
          onChangeEnd: player.canSeek
              ? (v) async {
                  await widget.onSeek(Duration(milliseconds: v.toInt()));
                  // After await, check that this State is still attached before requesting a rebuild.
                  if (mounted) setState(() => _drag = null);
                }
              : null,
        );
        final elapsedLabel = Text(
          elapsed,
          style: const TextStyle(fontSize: 14),
        );
        final durationLabel = Text(
          formatTime(player.duration),
          style: const TextStyle(fontSize: 14),
        );
        if (widget.inlineLabels) {
          return Row(
            children: [
              elapsedLabel,
              Expanded(child: slider),
              durationLabel,
            ],
          );
        }
        return Column(
          children: [
            slider,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [elapsedLabel, durationLabel],
            ),
          ],
        );
      },
    );
  }
}

// Shared controls preserve full-player sizing and mini-player buffering feedback.
Widget _skipButton(
  BuildContext context,
  AppController app, {
  bool forward = true,
  double? size,
}) {
  final player = app.model.playback;
  final enabled = forward ? player.hasNext : player.hasPrevious;
  return IconButton(
    tooltip: forward ? context.l10n.nextTrack : context.l10n.previousTrack,
    onPressed: enabled
        ? () =>
              unawaited(forward ? app.playback.next() : app.playback.previous())
        : null,
    icon: Icon(
      forward ? Icons.skip_next_rounded : Icons.skip_previous_rounded,
      size: size,
    ),
  );
}

Widget _playButton(BuildContext context, AppController app, {double? size}) {
  final player = app.model.playback;
  final mini = size == null;
  final label = player.playing
      ? context.l10n.pause
      : !mini && player.completed
      ? context.l10n.replay
      : context.l10n.play;
  final action = player.current != null && !player.busy
      ? () => unawaited(app.playback.toggle())
      : null;
  final icon = mini && player.busy
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Icon(
          player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: mini ? null : 44,
        );
  return mini
      ? IconButton(tooltip: label, onPressed: action, icon: icon)
      : IconButton.filled(
          tooltip: label,
          onPressed: action,
          style: IconButton.styleFrom(fixedSize: Size.square(size)),
          icon: icon,
        );
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app.model.playback,
    builder: (context, _) {
      final player = app.model.playback;
      final track = player.current;
      if (track == null) return const SizedBox.shrink();
      return Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF303638)
            : Theme.of(context).colorScheme.surfaceContainer,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 16, right: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: TrackArtwork(track: track, cacheWidth: 192),
                ),
              ),
              title: Text(
                track.titleLabel(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                track.isRadio
                    ? context.l10n.liveRadio
                    : track.artistLabel(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => PlayerScreen(app: app)),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _skipButton(context, app, forward: false),
                  _playButton(context, app),
                  _skipButton(context, app),
                ],
              ),
            ),
            if (!track.isRadio)
              ValueListenableBuilder<Duration>(
                valueListenable: player.progress,
                builder: (context, position, _) => LinearProgressIndicator(
                  minHeight: 2,
                  value: player.duration.inMilliseconds > 0
                      ? (position.inMilliseconds /
                                player.duration.inMilliseconds)
                            .clamp(0, 1)
                      : 0,
                ),
              ),
          ],
        ),
      );
    },
  );
}

