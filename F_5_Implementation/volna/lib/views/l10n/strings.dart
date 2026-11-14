import 'package:flutter/widgets.dart';
import '../../models/media.dart';
import '../../models/ui_message.dart';
import 'app_localizations.dart';
import 'app_localizations_en.dart';

// Extension: add a convenient l10n getter to BuildContext without modifying Flutter.
extension LocalizedContext on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? AppLocalizationsEn();
}

// Only app-owned placeholders and catalog labels are translated, never user data.
extension TrackLabels on Track {
  String titleLabel(BuildContext context) => switch (id) {
    'radio:marusya' => context.l10n.marusyaTitle,
    'radio:europa-plus' => context.l10n.europaTitle,
    'radio:retro-fm' => context.l10n.retroTitle,
    'radio:shanson' => context.l10n.shansonTitle,
    'radio:humor-fm' => context.l10n.humorTitle,
    _ =>
      title.isEmpty || title == 'Без названия' ? context.l10n.untitled : title,
  };
  String artistLabel(BuildContext context) => switch (id) {
    'radio:marusya' => context.l10n.marusyaDescription,
    'radio:europa-plus' => context.l10n.europaDescription,
    'radio:bbc-world-service' => context.l10n.bbcDescription,
    'radio:comedy-uk' => context.l10n.comedyUkDescription,
    'radio:181-comedy-club' => context.l10n.comedyUsDescription,
    'radio:capital' => context.l10n.capitalDescription,
    'radio:heart' => context.l10n.heartDescription,
    'radio:lbc' => context.l10n.lbcDescription,
    'radio:wbur' => context.l10n.wburDescription,
    'radio:retro-fm' => context.l10n.retroDescription,
    'radio:shanson' => context.l10n.shansonDescription,
    'radio:humor-fm' => context.l10n.humorDescription,
    _ =>
      [
            '',
            'Unknown artist',
            'Неизвестный исполнитель',
            '<unknown>',
          ].contains(artist)
          ? context.l10n.unknownArtist
          : artist,
  };
}

extension UiMessageLabels on UiMessage {
  String localize(AppLocalizations strings) => switch (id) {
    MessageId.invalidAudioUrl => strings.invalidAudioUrl,
    MessageId.libraryLoadFailed => strings.libraryLoadFailed,
    MessageId.libraryScanFailed => strings.libraryScanFailed,
    MessageId.folderOpenFailed => strings.folderOpenFailed,
    MessageId.folderCleanupFailed => strings.folderCleanupFailed,
    MessageId.saveFailed => strings.saveFailed,
    MessageId.corruptBackup => strings.corruptBackup,
    MessageId.stationUnavailable => strings.stationUnavailable,
    MessageId.playbackFailed => strings.playbackFailed,
    MessageId.sourceUnavailable => strings.sourceUnavailable,
    MessageId.toggleFailed => strings.toggleFailed,
    MessageId.stopFailed => strings.stopFailed,
    MessageId.playerCommandFailed => strings.playerCommandFailed,
    MessageId.radioRedirects => strings.radioRedirects,
    MessageId.radioPageTooLarge => strings.radioPageTooLarge,
    MessageId.radioWebsite => strings.radioWebsite,
    MessageId.settingsSaveFailed => strings.settingsSaveFailed,
    MessageId.foldersUnavailable => strings.foldersUnavailable(names),
    MessageId.radioHttp => strings.radioHttp(status),
  };
}

