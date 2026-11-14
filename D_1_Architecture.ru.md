# Архитектура

[English version](D_1_Architecture.md)

## Принцип MVC

View показывает состояние Model и отправляет действия Controller.
Controller вызывает операции Model. Model хранит состояние и правила работы,
не импортируя View и Controller. Сервисы входят в блок Model.

Пример: нажатие на песню -> PlaybackController -> PlayerModel -> звуковой движок ->
уведомление модели -> обновление интерфейса.
Прогресс воспроизведения обновляется отдельно от списка песен.

## Назначение файлов

Пути относительно `F_5_Implementation/volna/lib`.

| Файл | Назначение |
| --- | --- |
| main.dart | Настройка звука и сборка приложения |
| controllers/app_controller.dart | AppController связывает части; LibraryController управляет папками; SettingsController настройками |
| controllers/playback_controller.dart | Команды плеера, разрешение уведомлений, повтор и случайный порядок |
| models/app_model.dart | Запуск, восстановление и сохранение состояния плеера |
| models/media.dart | Данные трека, папки и вспомогательное форматирование |
| models/library_model.dart | Папки, треки, статистика и Top 100 |
| models/player_model.dart | Звуковой движок, неизменяемая очередь, команды и состояние |
| models/listening_tracker.dart | Подсчёт реального прослушивания без паузы, буферизации, перемотки и радио |
| models/settings_model.dart | Хранение языка и темы |
| models/radio_catalog.dart | Готовый каталог радио и пути логотипов |
| models/ui_message.dart | Идентификаторы сообщений без привязки к языку |
| models/services/audio_bootstrap.dart | Настройка фонового звука и аудиосессии |
| models/services/library_store.dart | Последовательное сохранение JSON |
| models/services/media_library.dart | Связь с Android: выбор папки, сканирование и разрешения |
| models/services/radio_resolver.dart | Перенаправления потоков и поддерживаемые плейлисты |
| models/services/radio_artwork_cache.dart | Логотипы для системного уведомления |
| views/app_view.dart | Корневой виджет, темы и язык |
| views/home_screen.dart | Четыре вкладки и навигация |
| views/folder_tracks_screen.dart | Треки выбранной папки |
| views/player_screen.dart | Полный и мини-плеер, перемотка и очередь |
| views/settings_screen.dart | Выбор языка и темы |
| views/track_tile.dart | Общие списки, строки треков и сообщения ошибок |
| views/track_artwork.dart | Обложка или логотип радио |
| views/l10n/strings.dart | Перевод названий и сообщений |
| views/l10n/app_en.arb, app_ru.arb | Редактируемые переводы |
| views/l10n/app_localizations*.dart | Три автоматически созданных файла переводов |

## Ресурсы и данные

`android/` — Android-часть, `assets/` — изображения, `test/` — тесты.
Музыка остаётся в выбранных папках. Ссылки на папки, статистика, настройки и
состояние плеера сохраняются локально в JSON. Удаление выбора папки не удаляет музыку.

После изменения ARB выполни `flutter gen-l10n`.
В lib **24 рукописных Dart-файла** и три сгенерированных файла переводов.
Контроллеры папок и настроек находятся в одном файле. Очередь неизменяемая.


