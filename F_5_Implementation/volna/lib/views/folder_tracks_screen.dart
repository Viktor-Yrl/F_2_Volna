import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
import '../models/media.dart';
import 'l10n/strings.dart';
import 'player_screen.dart';
import 'track_tile.dart';

/// Reads the current folder snapshot so refreshes never leave a stale queue.
class FolderTracksScreen extends StatelessWidget {
  const FolderTracksScreen({
    super.key,
    required this.app,
    required this.title,
    required this.tracks,
  });
  final AppController app;
  final String title;
  final List<Track> Function() tracks;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([app.model.library, app.model.playback]),
    builder: (context, _) {
      // Read the current folder snapshot so a refresh is reflected when rebuilding.
      final queue = tracks();
      return Scaffold(
        appBar: AppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: context.l10n.play,
              onPressed: queue.isEmpty
                  ? null
                  : () => unawaited(
                      app.playback.playTracks(queue, startIndex: 0),
                    ),
              icon: const Icon(Icons.play_arrow),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (app.model.library.error != null)
                ErrorBanner(
                  message: app.model.library.error!,
                  onDismiss: app.library.clearError,
                ),
              if (app.model.playback.error != null)
                ErrorBanner(
                  message: app.model.playback.error!,
                  onDismiss: app.playback.clearError,
                ),
              if (app.model.library.busy) const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(context.l10n.trackCount(queue.length)),
                ),
              ),
              Expanded(
                child: queue.isEmpty
                    ? Center(child: Text(context.l10n.noTracksAvailable))
                    : TrackList(app: app, tracks: queue),
              ),
              MiniPlayer(app: app),
            ],
          ),
        ),
      );
    },
  );
}

