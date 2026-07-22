/// 进行中的时间记录会话（持久化用）。
///
/// 设计要点：
/// - 所有时间段都使用真实墙钟时间（DateTime.now()），不依赖累加时长。
/// - [segments] 是已经发生、已闭合的时段（每次暂停产生一段）。
/// - [runningStart] 是当前正在进行、尚未闭合的时段起点；
///   为 null 表示当前处于「暂停中」且没有其他正在跑的段。
/// - 停止时：用 [segments] + 当前 runningStart 合并生成若干条 Task，
///   每段对应一个真实时间区间。
class RecordingSession {
  final String activity;
  final String category;
  final String note;
  final List<TimeSegment> segments;
  final DateTime? runningStart; // 当前正在计时的段起点
  final bool paused; // 当前是否暂停（runningStart == null 时一般为 true）
  final DateTime savedAt; // 最后持久化时刻，用于恢复时校验

  const RecordingSession({
    required this.activity,
    required this.category,
    required this.note,
    required this.segments,
    required this.runningStart,
    required this.paused,
    required this.savedAt,
  });

  /// 当前累计显示时长（含已闭合段 + 正在跑的段）
  Duration get elapsed {
    Duration total = Duration.zero;
    for (final s in segments) {
      total += s.end.difference(s.start);
    }
    if (runningStart != null) {
      total += DateTime.now().difference(runningStart!);
    }
    return total;
  }

  /// 是否处于「正在计时」状态（用于 UI 判断是否显示计时面板）
  bool get isActive => runningStart != null || segments.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'activity': activity,
        'category': category,
        'note': note,
        'segments': segments.map((s) => s.toMap()).toList(),
        'runningStart': runningStart?.millisecondsSinceEpoch,
        'paused': paused ? 1 : 0,
        'savedAt': savedAt.millisecondsSinceEpoch,
      };

  factory RecordingSession.fromMap(Map<String, dynamic> m) {
    final segRaw = (m['segments'] as List?) ?? [];
    final segments = segRaw
        .map((e) => TimeSegment.fromMap(e as Map<String, dynamic>))
        .toList();
    final rs = m['runningStart'];
    return RecordingSession(
      activity: m['activity'] as String? ?? '',
      category: m['category'] as String? ?? '',
      note: m['note'] as String? ?? '',
      segments: segments,
      runningStart: rs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(rs as int),
      paused: (m['paused'] as int? ?? 0) == 1,
      savedAt: DateTime.fromMillisecondsSinceEpoch(
          m['savedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
    );
  }
}

/// 单个已闭合的时间段
class TimeSegment {
  final DateTime start;
  final DateTime end;
  const TimeSegment({required this.start, required this.end});

  Map<String, dynamic> toMap() => {
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
      };

  factory TimeSegment.fromMap(Map<String, dynamic> m) => TimeSegment(
        start:
            DateTime.fromMillisecondsSinceEpoch(m['start'] as int),
        end: DateTime.fromMillisecondsSinceEpoch(m['end'] as int),
      );
}
