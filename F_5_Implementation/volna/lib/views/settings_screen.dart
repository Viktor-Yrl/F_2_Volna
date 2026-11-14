import 'package:flutter/material.dart';
import 'l10n/strings.dart';
import 'track_tile.dart';
import '../models/settings_model.dart';
import '../controllers/app_controller.dart';

// View: display preference state and delegate changes to SettingsController.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final SettingsController controller;
  SettingsModel get settings => controller.model;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => SafeArea(
      child: ListView(
        children: [
          ..._section(
            context,
            context.l10n.appearance,
            settings.lightTheme,
            {false: context.l10n.darkTheme, true: context.l10n.lightTheme},
            controller.setLightTheme,
          ),
          if (settings.saving) const LinearProgressIndicator(),
          if (settings.error != null)
            ErrorBanner(
              message: settings.error!,
              onDismiss: controller.clearError,
            ),
          ..._section(
            context,
            context.l10n.language,
            settings.languageCode,
            const {'en': 'English', 'ru': 'Русский'},
            controller.setLanguage,
          ),
        ],
      ),
    ),
  );

  List<Widget> _section<T>(
    BuildContext context,
    String title,
    T selected,
    Map<T, String> options,
    ValueChanged<T> onChanged,
  ) => [
    Padding(
      padding: const EdgeInsets.all(20),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    ),
    RadioGroup<T>(
      groupValue: selected,
      onChanged: (value) {
        if (value != null && !settings.saving) onChanged(value);
      },
      child: Column(
        children: [
          for (final option in options.entries)
            RadioListTile<T>(
              title: Text(option.value),
              value: option.key,
              enabled: !settings.saving,
            ),
        ],
      ),
    ),
  ];
}

