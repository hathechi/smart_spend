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
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsService _settingsService;
  late final AIAnalysisService _aiService;
  final _telegramChatIdController = TextEditingController();
  final _telegramBotTokenController = TextEditingController();
  final _openAiApiKeyController = TextEditingController();
  final _webhookUrlController = TextEditingController();
  bool _isTestingTelegram = false;
  final bool _isTestingOpenAI = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _settingsService = SettingsService(prefs);
    _aiService = AIAnalysisService(
        StorageService(), TelegramService(_settingsService), _settingsService);
    await _loadSettings();
    setState(() {
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _telegramChatIdController.dispose();
    _telegramBotTokenController.dispose();
    _openAiApiKeyController.dispose();
    _webhookUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    _telegramChatIdController.text = _settingsService.getTelegramChatId() ?? '';
    _telegramBotTokenController.text =
        _settingsService.getTelegramBotToken() ?? '';
    _openAiApiKeyController.text = _settingsService.getOpenAiApiKey() ?? '';
    _webhookUrlController.text = _settingsService.getWebhookUrl() ?? '';
  }

  bool _validateTelegramConfig() {
    if (_telegramChatIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.api.telegram.chat_id_required'.tr())),
      );
      return false;
    }
    if (_telegramBotTokenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('settings.api.telegram.bot_token_required'.tr())),
      );
      return false;
    }
    return true;
  }

  bool _validateOpenAIConfig() {
    if (_openAiApiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.api.openai.api_key_required'.tr())),
      );
      return false;
    }
    return true;
  }

  Future<void> _saveTelegramConfig() async {
    if (!_validateTelegramConfig()) return;

    try {
      await _settingsService.setTelegramConfig(
        chatId: _telegramChatIdController.text,
        botToken: _telegramBotTokenController.text,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.api.telegram.save_success'.tr())),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.api.telegram.save_error'.tr())),
      );
    }
  }

  Future<void> _saveOpenAiApiKey() async {
    if (!_validateOpenAIConfig()) return;

    try {
      await _settingsService.setOpenAiApiKey(_openAiApiKeyController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.api.openai.save_success'.tr())),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.api.openai.save_error'.tr())),
      );
    }
  }

  Future<void> _saveWebhookUrl() async {
    try {
      await _settingsService.setWebhookUrl(_webhookUrlController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu Webhook URL thành công!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể lưu Webhook URL')),
      );
    }
  }

  Future<void> _testTelegramConnection() async {
    if (!_validateTelegramConfig()) return;

    setState(() => _isTestingTelegram = true);
    try {
      final telegramService = TelegramService(_settingsService);
      final success = await telegramService.testConnection();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'settings.api.telegram.test_success'.tr()
              : 'settings.api.telegram.test_error'.tr()),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.api.telegram.test_error'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isTestingTelegram = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);

    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }
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
          _initialized
              ? _ReminderSettingsSection(aiService: _aiService)
              : const Center(child: CircularProgressIndicator()),
          // API Configuration Section
          Card(
            margin: const EdgeInsets.all(8.0),
            child: ExpansionTile(
              title: Text(
                'settings.api.title'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Text('settings.api.subtitle'.tr()),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Telegram Configuration
                      ExpansionTile(
                        title: Text(
                          'settings.api.telegram.title'.tr(),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        subtitle: Text('settings.api.telegram.subtitle'.tr()),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _telegramChatIdController,
                                  decoration: InputDecoration(
                                    labelText:
                                        'settings.api.telegram.chat_id'.tr(),
                                    hintText:
                                        'settings.api.telegram.chat_id_hint'
                                            .tr(),
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.chat),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _telegramBotTokenController,
                                  decoration: InputDecoration(
                                    labelText:
                                        'settings.api.telegram.bot_token'.tr(),
                                    hintText:
                                        'settings.api.telegram.bot_token_hint'
                                            .tr(),
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.security),
                                  ),
                                  obscureText: true,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  // spacing: 8,
                                  // runSpacing: 8,
                                  alignment: WrapAlignment.start,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _isTestingTelegram
                                          ? null
                                          : _testTelegramConnection,
                                      icon: _isTestingTelegram
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          : const Icon(Icons.send),
                                      label: Text(_isTestingTelegram
                                          ? 'settings.api.telegram.testing'.tr()
                                          : 'settings.api.telegram.test'.tr()),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _saveTelegramConfig,
                                      icon: const Icon(Icons.save),
                                      label: Text('settings.api.save'.tr()),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      // OpenAI API Key
                      ExpansionTile(
                        title: Text(
                          'settings.api.openai.title'.tr(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text('settings.api.openai.subtitle'.tr()),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _openAiApiKeyController,
                                  decoration: InputDecoration(
                                    labelText:
                                        'settings.api.openai.api_key'.tr(),
                                    hintText:
                                        'settings.api.openai.api_key_hint'.tr(),
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.key),
                                  ),
                                  obscureText: true,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _saveOpenAiApiKey,
                                      icon: const Icon(Icons.save),
                                      label: Text('settings.api.save'.tr()),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _webhookUrlController,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Webhook URL (n8n, Google Sheets)',
                                    hintText: 'Nhập link webhook của bạn',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.link),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _saveWebhookUrl,
                                      icon: const Icon(Icons.save),
                                      label: const Text('Lưu Webhook'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderSettingsSection extends StatefulWidget {
  final AIAnalysisService aiService;

  const _ReminderSettingsSection({
    required this.aiService,
  });

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

  // Thêm biến cho kiểu nhắc nhở
  String _reminderType = 'times'; // 'times' hoặc 'interval'
  int _intervalHours = 3;

  @override
  void initState() {
    super.initState();
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
    await ReminderNotificationService(widget.aiService).scheduleAllReminders();
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
    await ReminderNotificationService(widget.aiService)
        .testScheduleReminderNow();
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
                Text('reminder.title'.tr(),
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
                Text('${'reminder.start_date'.tr()}: '),
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
                          Text('reminder.choose_times'.tr()),
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
                          Text('reminder.repeat_every'.tr()),
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
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            hintText: 'reminder.hour'.tr(),
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
                      Text('reminder.hour'.tr()),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _saveConfig();
                        },
                        child: Text('reminder.done'.tr()),
                      ),
                    ],
                  ),
                ],
                if (_reminderType == 'times') ...[
                  const SizedBox(height: 8),
                  Text('${'reminder.reminder_times'.tr()}:'),
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
                    label: Text('reminder.add_time'.tr()),
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
