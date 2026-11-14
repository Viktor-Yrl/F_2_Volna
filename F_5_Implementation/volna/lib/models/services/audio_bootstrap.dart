import 'package:audio_session/audio_session.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Sets up Android media controls before constructing the audio engine.
Future<void> initializeAudio() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'dev.viktoryarmarkin.music_player_full.audio',
    androidNotificationChannelName: 'Music playback',
    androidNotificationOngoing: true,
  );
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
}
