class MoodEntry {
  final String id;
  final DateTime date;
  final List<String> emojis;
  final String note;
  final String? imageFileName;

  const MoodEntry({
    required this.id,
    required this.date,
    required this.emojis,
    this.note = '',
    this.imageFileName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'emojis': emojis,
    'note': note,
    'imageFileName': imageFileName,
  };

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    // 'emoji'(단일)는 복수 선택 이전에 저장된 기록의 형식이다.
    emojis: json['emojis'] != null
        ? (json['emojis'] as List).cast<String>()
        : [json['emoji'] as String],
    note: json['note'] as String? ?? '',
    imageFileName: json['imageFileName'] as String?,
  );

  /// 오늘부터 거꾸로 하루도 빠짐없이 기록한 날 수. 오늘 기록이 없으면 0이다.
  ///
  /// 홈의 "오늘도 기록 완료!" 배너와 마이 페이지의 연속 출석이 같은 값을 쓴다.
  static int streak(Iterable<MoodEntry> entries, {DateTime? today}) {
    final days = entries
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet();
    final now = today ?? DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    var count = 0;
    while (days.contains(day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }
}
