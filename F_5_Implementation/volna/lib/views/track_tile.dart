import 'dart:async';
import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/media.dart';
import 'track_artwork.dart';
import 'l10n/strings.dart';
import '../models/ui_message.dart';

// Reusable View component: one row observes the active track and busy state.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.app,
    required this.onTap,
    this.trailing,
  });
  final Track track;
  final AppController app;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app.model.playback,
    builder: (context, _) {
      final active = app.model.playback.current?.id == track.id;
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
        leading: SizedBox(
          width: 46,
          height: 46,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TrackArtwork(track: track, cacheWidth: 192),
          ),
        ),
        title: Text(
          track.titleLabel(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? Theme.of(context).colorScheme.primary : null,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          track.artistLabel(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing:
            trailing ??
            (track.durationMs > 0
                ? Text(formatTime(Duration(milliseconds: track.durationMs)))
                : null),
        onTap: app.model.playback.busy ? null : onTap,
      );
    },
  );
}

/// Shared list keeps queue selection consistent across folders, ranking and radio.
class TrackList extends StatelessWidget {
  const TrackList({
    super.key,
    required this.app,
    required this.tracks,
    this.trailing,
  });
  final AppController app;
  final List<Track> tracks;
  final Widget Function(BuildContext, Track)? trailing;

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: tracks.length,
    itemBuilder: (context, index) {
      final track = tracks[index];
      return TrackTile(
        track: track,
        app: app,
        trailing: trailing == null
            ? null
            // Build the trailing widget in its own context so theme changes are observed.
            : Builder(builder: (context) => trailing!(context, track)),
        onTap: () => unawaited(
          app.playback.playTracks(
            track.isRadio ? [track] : tracks,
            startIndex: track.isRadio ? 0 : index,
          ),
        ),
      );
    },
  );
}

// Translate the message at render time so visible errors follow language changes.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
    this.maxLines,
  });
  final UiMessage message;
  final VoidCallback onDismiss;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final text = message.localize(context.l10n);
    final bounded = maxLines != null;
    Widget label = Text(
      text,
      maxLines: maxLines,
      overflow: bounded ? TextOverflow.ellipsis : null,
      semanticsLabel: bounded ? text : null,
      style: bounded
          ? TextStyle(
              fontSize: 14,
              height: 1.2,
              color: Theme.of(context).colorScheme.onErrorContainer,
            )
          : null,
    );
    if (bounded) label = Tooltip(message: text, child: label);
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: bounded
                  ? const EdgeInsets.all(8)
                  : const EdgeInsets.only(left: 16, top: 10, bottom: 10),
              child: Semantics(liveRegion: true, child: label),
            ),
          ),
          IconButton(
            tooltip: context.l10n.closeMessage,
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

