import 'dart:io';

import 'package:flutter/services.dart';

import '../media.dart';

/// Reads Android document trees selected by the user.
class MediaLibrary {
  // MethodChannel connects Dart commands to the matching native Android handler.
  static const _channel = MethodChannel('music_player_full/library');
  bool get supported => Platform.isAndroid;
  // A nullable result represents cancellation of the Android folder picker.
  Future<MusicFolder?> pickFolder() async {
    if (!supported) return null;
    final data = await _channel.invokeMapMethod<String, dynamic>('pickFolder');
    return data == null
        ? null
        : MusicFolder.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<Track>> scanFolder(String uri) async {
    final rows =
        await _channel.invokeListMethod<dynamic>('scanFolder', {'uri': uri}) ??
        [];
    return rows
        .map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> requestNotifications() async {
    if (supported) await _channel.invokeMethod<bool>('requestNotifications');
  }

  Future<void> keepFolderGrants(Set<String> roots) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('keepFolderGrants', {
      'roots': roots.toList(),
    });
  }
}

