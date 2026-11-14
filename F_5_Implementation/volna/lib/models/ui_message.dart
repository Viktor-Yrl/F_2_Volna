// Messages carry semantic IDs so errors can change language while visible.
enum MessageId {
  invalidAudioUrl,
  libraryLoadFailed,
  libraryScanFailed,
  folderOpenFailed,
  folderCleanupFailed,
  saveFailed,
  corruptBackup,
  stationUnavailable,
  playbackFailed,
  sourceUnavailable,
  toggleFailed,
  stopFailed,
  playerCommandFailed,
  radioRedirects,
  radioPageTooLarge,
  radioWebsite,
  settingsSaveFailed,
  foldersUnavailable,
  radioHttp,
}

// Immutable message data keeps business errors independent of translated UI text.
class UiMessage {
  const UiMessage(this.id, {this.names = '', this.status = 0});
  final MessageId id;
  final int status;
  final String names;
}

// Preserve the FormatException contract used by URL validation.
class LocalizedException extends FormatException {
  const LocalizedException(this.localized) : super('localized');
  final UiMessage localized;
}

