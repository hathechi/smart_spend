import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:smart_spend/services/settings_service.dart';
import 'package:intl/intl.dart';
import 'package:smart_spend/services/reminder_service.dart';
import 'package:smart_spend/services/reminder_notification_service.dart';
import 'package:smart_spend/services/ai_analysis_service.dart';
import 'package:smart_spend/services/telegram_service.dart';
import 'package:smart_spend/services/storage_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);

    return Scaffold(
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
          const Divider(),
          _ReminderSettingsSection(),
        ],
      ),
    );
  }
}

class _ReminderSettingsSection extends StatefulWidget {
  @override
  State<_ReminderSettingsSection> createState() =>
      _ReminderSettingsSectionState();
}

class _ReminderSettingsSectionState extends State<_ReminderSettingsSection> {
  final ReminderService _reminderService = ReminderService();
  List<TimeOfDay> _reminderTimes = [];
  DateTime _startDate = DateTime.now();
  bool _enabled = true;
  bool _loading = true;
  late final AIAnalysisService _aiService;

  // Thêm biến cho kiểu nhắc nhở
  String _reminderType = 'times'; // 'times' hoặc 'interval'
  int _intervalHours = 3;

  @override
  void initState() {
    super.initState();
    _aiService = AIAnalysisService(
        StorageService(), TelegramService(botToken: '', chatId: ''));
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _reminderService.loadConfig();
    if (config != null) {
      setState(() {
        _reminderTimes = List.from(config.times);
        _startDate = config.startDate;
        _enabled = config.enabled;
        if (config.intervalHours != null) {
          _reminderType = 'interval';
          _intervalHours = config.intervalHours!;
        } else {
          _reminderType = 'times';
        }
        _loading = false;
      });
    } else {
      setState(() {
        _reminderTimes = [const TimeOfDay(hour: 8, minute: 0)];
        _startDate = DateTime.now();
        _enabled = true;
        _reminderType = 'times';
        _intervalHours = 3;
        _loading = false;
      });
    }
  }

  void _onReminderTypeChanged(String? v) {
    setState(() => _reminderType = v!);
    print('Reminder type changed: $_reminderType');
  }

  Future<void> _saveConfig() async {
    print(
        'Saving reminder config: type=$_reminderType, intervalHours=$_intervalHours, times=$_reminderTimes');
    final config = ReminderConfig(
      times: _reminderType == 'times' ? _reminderTimes : [],
      startDate: _startDate,
      enabled: _enabled,
      intervalHours: _reminderType == 'interval' ? _intervalHours : null,
    );
    await _reminderService.saveConfig(config);
    await ReminderNotificationService(_aiService).scheduleAllReminders();
  }

  void _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && !_reminderTimes.contains(picked)) {
      setState(() => _reminderTimes.add(picked));
      _saveConfig();
    }
  }

  void _removeTime(int index) {
    setState(() => _reminderTimes.removeAt(index));
    _saveConfig();
  }

  void _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
      _saveConfig();
    }
  }

  Future<void> _testNotification() async {
    print('Test notification button pressed');
    await ReminderNotificationService(_aiService).testScheduleReminderNow();
    print('Notification scheduled');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Nhắc nhở chi tiêu',
                    style: Theme.of(context).textTheme.titleMedium),
                Switch(
                  value: _enabled,
                  onChanged: (v) {
                    setState(() => _enabled = v);
                    _saveConfig();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Ngày bắt đầu: '),
                TextButton(
                  onPressed: _pickStartDate,
                  child: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Chọn kiểu nhắc nhở
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Radio<String>(
                            value: 'times',
                            groupValue: _reminderType,
                            onChanged: _onReminderTypeChanged,
                          ),
                          const Text('Chọn khung giờ cụ thể'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          Radio<String>(
                            value: 'interval',
                            groupValue: _reminderType,
                            onChanged: _onReminderTypeChanged,
                          ),
                          const Text('Lặp lại mỗi'),
                        ],
                      ),
                    )
                  ],
                ),
                if (_reminderType == 'interval') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            hintText: 'giờ',
                          ),
                          onChanged: (val) {
                            final n = int.tryParse(val);
                            if (n != null && n > 0) {
                              setState(() => _intervalHours = n);
                            }
                          },
                          controller: TextEditingController(
                              text: _intervalHours.toString()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('giờ'),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _saveConfig();
                        },
                        child: const Text('Xong'),
                      ),
                    ],
                  ),
                ],
                if (_reminderType == 'times') ...[
                  const SizedBox(height: 8),
                  const Text('Các khung giờ nhắc nhở:'),
                  ..._reminderTimes.asMap().entries.map((entry) => ListTile(
                        title: Text(entry.value.format(context)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeTime(entry.key),
                        ),
                      )),
                  TextButton.icon(
                    onPressed: _addTime,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm khung giờ'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
