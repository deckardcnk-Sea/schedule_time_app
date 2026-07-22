import 'package:flutter/material.dart';

/// 任务 / 时间块数据模型
class Task {
  final int? id;
  String title;
  String note;
  DateTime start;
  DateTime end;
  int colorValue; // Color.value
  bool isAllDay;
  bool isDone;
  bool isReminder; // true=提醒事项(可勾选), false=日历事件
  bool isFlagged; // 旗标
  String category; // 所属日历/分类（用于事件颜色/日历）
  String listName; // 所属提醒事项列表（年计划/月计划/开心清单…）
  String repeatRule; // 重复规则：永不/每天/每周/每两周/每月/每年
  String reminderOffset; // 提醒提前量：无/日程当天(09:00)/1天前(09:00)/2天前(09:00)/1周前
  final DateTime createdAt;
  final int? seriesId; // 重复派生实例的源任务 id（源任务自身为 null）
  final DateTime? occurrenceDate; // 重复派生实例实际发生的日期（源任务自身为 null）

  Task({
    this.id,
    required this.title,
    this.note = '',
    required this.start,
    required this.end,
    required this.colorValue,
    this.isAllDay = false,
    this.isDone = false,
    this.isReminder = false,
    this.isFlagged = false,
    this.category = '',
    this.listName = '',
    this.repeatRule = '永不',
    this.reminderOffset = '无',
    DateTime? createdAt,
    this.seriesId,
    this.occurrenceDate,
  }) : createdAt = createdAt ?? DateTime.now();

  Color get color => Color(colorValue);

  Duration get duration => end.difference(start);

  /// 任务栏展示标题：仅标题。
  /// 备注不再拼进标题（去掉「（备注）」形式），改为在名称/时间下方
  /// 用更小字体、与时间段标识同色的独立行显示（见各视图渲染）。
  String get displayTitle => title;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'note': note,
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
        'colorValue': colorValue,
        'isAllDay': isAllDay ? 1 : 0,
        'isDone': isDone ? 1 : 0,
        'isReminder': isReminder ? 1 : 0,
        'isFlagged': isFlagged ? 1 : 0,
        'category': category,
        'listName': listName,
        'repeatRule': repeatRule,
        'reminderOffset': reminderOffset,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'seriesId': seriesId,
        'occurrenceDate': occurrenceDate?.millisecondsSinceEpoch,
      };

  factory Task.fromMap(Map<String, dynamic> m) => Task(
        id: m['id'] as int?,
        title: m['title'] as String? ?? '',
        note: m['note'] as String? ?? '',
        start: DateTime.fromMillisecondsSinceEpoch(m['start'] as int),
        end: DateTime.fromMillisecondsSinceEpoch(m['end'] as int),
        colorValue: m['colorValue'] as int,
        isAllDay: (m['isAllDay'] as int? ?? 0) == 1,
        isDone: (m['isDone'] as int? ?? 0) == 1,
        isReminder: (m['isReminder'] as int? ?? 0) == 1,
        isFlagged: (m['isFlagged'] as int? ?? 0) == 1,
        category: m['category'] as String? ?? '',
        listName: m['listName'] as String? ?? '',
        repeatRule: m['repeatRule'] as String? ?? '永不',
        reminderOffset: m['reminderOffset'] as String? ?? '无',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            m['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
        seriesId: m['seriesId'] as int?,
        occurrenceDate: m['occurrenceDate'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['occurrenceDate'] as int),
      );

  Task copyWith({
    int? id,
    String? title,
    String? note,
    DateTime? start,
    DateTime? end,
    int? colorValue,
    bool? isAllDay,
    bool? isDone,
    bool? isReminder,
    bool? isFlagged,
    String? category,
    String? listName,
    String? repeatRule,
    String? reminderOffset,
    int? seriesId,
    DateTime? occurrenceDate,
  }) =>
      Task(
        id: id ?? this.id,
        title: title ?? this.title,
        note: note ?? this.note,
        start: start ?? this.start,
        end: end ?? this.end,
        colorValue: colorValue ?? this.colorValue,
        isAllDay: isAllDay ?? this.isAllDay,
        isDone: isDone ?? this.isDone,
        isReminder: isReminder ?? this.isReminder,
        isFlagged: isFlagged ?? this.isFlagged,
        category: category ?? this.category,
        listName: listName ?? this.listName,
        repeatRule: repeatRule ?? this.repeatRule,
        reminderOffset: reminderOffset ?? this.reminderOffset,
        createdAt: createdAt,
        seriesId: seriesId ?? this.seriesId,
        occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      );
}
