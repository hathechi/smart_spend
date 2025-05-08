import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:smart_spend/services/settings_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('settings.title'.tr()),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text('settings.appearance.title'.tr()),
            subtitle: Text('settings.appearance.subtitle'.tr()),
          ),
          SwitchListTile(
            title: Text('settings.appearance.use_system'.tr()),
            subtitle: Text('settings.appearance.subtitle'.tr()),
            value: settingsService.useSystemTheme,
            onChanged: (bool value) {
              settingsService.useSystemTheme = value;
            },
          ),
          if (!settingsService.useSystemTheme)
            SwitchListTile(
              title: Text('settings.appearance.dark_mode'.tr()),
              subtitle: Text('settings.appearance.subtitle'.tr()),
              value: settingsService.isDarkMode,
              onChanged: (bool value) {
                settingsService.isDarkMode = value;
              },
            ),
          const Divider(),
          ListTile(
            title: Text('settings.language.title'.tr()),
            subtitle: Text('settings.language.subtitle'.tr()),
          ),
          RadioListTile<String>(
            title: Text('settings.language.vi'.tr()),
            value: 'vi',
            groupValue: context.locale.languageCode,
            onChanged: (String? value) {
              if (value != null) {
                context.setLocale(const Locale('vi'));
                settingsService.setLanguage(value);
              }
            },
          ),
          RadioListTile<String>(
            title: Text('settings.language.en'.tr()),
            value: 'en',
            groupValue: context.locale.languageCode,
            onChanged: (String? value) {
              if (value != null) {
                context.setLocale(const Locale('en'));
                settingsService.setLanguage(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
