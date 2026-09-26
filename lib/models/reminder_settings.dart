import 'package:shared_preferences/shared_preferences.dart';

enum ReminderMode { once, repeat }

class ReminderSettings {
  final bool enabled;
  final ReminderMode mode;
  final int hour;
  final int minute;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int intervalMinutes;
  final Set<int> weekdays; // DateTime.monday(1) ~ DateTime.sunday(7)

  const ReminderSettings({
    required this.enabled,
    required this.mode,
    required this.hour,
    required this.minute,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.intervalMinutes,
    required this.weekdays,
  });

  static const defaults = ReminderSettings(
    enabled: false,
    mode: ReminderMode.once,
    hour: 21,
    minute: 0,
    startHour: 9,
    startMinute: 0,
    endHour: 22,
    endMinute: 0,
    intervalMinutes: 60,
    weekdays: {1, 2, 3, 4, 5, 6, 7},
  );

  bool get endAfterStart =>
      endHour * 60 + endMinute > startHour * 60 + startMinute;

  ReminderSettings copyWith({
    bool? enabled,
    ReminderMode? mode,
    int? hour,
    int? minute,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    int? intervalMinutes,
    Set<int>? weekdays,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      weekdays: weekdays ?? this.weekdays,
    );
  }

  static Future<ReminderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderSettings(
      enabled: prefs.getBool('reminder_enabled') ?? defaults.enabled,
      mode:
          prefs.getString('reminder_mode') == 'repeat'
              ? ReminderMode.repeat
              : ReminderMode.once,
      hour: prefs.getInt('reminder_hour') ?? defaults.hour,
      minute: prefs.getInt('reminder_minute') ?? defaults.minute,
      startHour: prefs.getInt('reminder_start_hour') ?? defaults.startHour,
      startMinute:
          prefs.getInt('reminder_start_minute') ?? defaults.startMinute,
      endHour: prefs.getInt('reminder_end_hour') ?? defaults.endHour,
      endMinute: prefs.getInt('reminder_end_minute') ?? defaults.endMinute,
      intervalMinutes:
          prefs.getInt('reminder_interval') ?? defaults.intervalMinutes,
      weekdays:
          prefs
              .getStringList('reminder_weekdays')
              ?.map(int.parse)
              .toSet() ??
          defaults.weekdays,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', enabled);
    await prefs.setString('reminder_mode', mode.name);
    await prefs.setInt('reminder_hour', hour);
    await prefs.setInt('reminder_minute', minute);
    await prefs.setInt('reminder_start_hour', startHour);
    await prefs.setInt('reminder_start_minute', startMinute);
    await prefs.setInt('reminder_end_hour', endHour);
    await prefs.setInt('reminder_end_minute', endMinute);
    await prefs.setInt('reminder_interval', intervalMinutes);
    await prefs.setStringList(
      'reminder_weekdays',
      weekdays.map((d) => d.toString()).toList(),
    );
  }
}
