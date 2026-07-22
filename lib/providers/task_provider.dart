import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
import '../models/activity_model.dart';
import '../models/recording_session.dart';
import '../services/database_service.dart';
import '../utils/colors.dart';
import '../utils/lists.dart';

/// 日历视图模式（对齐苹果：日/周/月/年）
enum CalendarViewMode { day, week, month, year }

/// 提醒事项列表筛选
enum ListFilter { today, planned, all, flagged, completed, assignedToMe }

/// 任务状态管理
class TaskProvider extends ChangeNotifier {
  final _db = DatabaseService.instance;

  // Web 预览模式（sqflite 不支持 Web）：使用内存存储 + 本地持久化
  final bool _memoryMode = kIsWeb;
  final List<Task> _memoryStore = [];
  SharedPreferences? _prefs;
  static const _kStoreKey = 'schedule_tasks_v1';
  static const _kCategoriesKey = 'schedule_categories_v1';
  static const _kActivitiesKey = 'schedule_activities_v1';
  static const _kRecordingKey = 'schedule_recording_v1';

  // 记录页活动配置（仅 Web 预览持久化；真机用内存默认种子）
  List<ActivityCategory> _categories = [];
  List<ActivityType> _activityTypes = [];
  bool _activitySeeded = false;

  List<ActivityCategory> get categories => List.unmodifiable(_categories);
  List<ActivityType> get activityTypes => List.unmodifiable(_activityTypes);

  /// 取某大类颜色；找不到回退 iOS 蓝
  Color categoryColor(String name) {
    try {
      return _categories
          .firstWhere((c) => c.name == name)
          .color;
    } catch (_) {
      return AppColors.taskPalette[6];
    }
  }

  /// Web 端启动时从本地恢复数据
  Future<void> initWebStore() async {
    if (!_memoryMode) return;
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_kStoreKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _memoryStore
          ..clear()
          ..addAll(list.map(Task.fromMap));
      } catch (_) {
        // 解析失败则用演示数据兜底
      }
    }
    _seedActivityIfEmpty();
    _seedDemoIfEmpty();
    await loadDay(_selectedDay);
  }

  /// 真机（Android/iOS）启动时初始化数据库 + 种子演示数据
  /// 问题6：用户要求电脑预览和真机上都要有演示数据，可自行删除。
  Future<void> initNativeStore() async {
    if (_memoryMode) return; // Web 走 initWebStore
    // 关键修复（问题3/6）：真机下也必须初始化 _prefs，
    // 否则活动配置（categories/activities）只能存内存、重启即丢。
    // Web 端在 initWebStore 已初始化 _prefs，这里补真机路径。
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null; // 极少数平台不支持，安全降级为纯内存
    }
    try {
      await _db.database; // 确保数据库已创建
      final existing = await _db.allTasks();
      if (existing.isEmpty) {
        // 数据库为空（首次安装），把演示数据写入数据库，用户可自行删除
        for (final t in _buildDemoTasks()) {
          await _db.insert(t);
        }
      } else {
        // 演示数据颜色等关键字段若与代码 demo 不一致，自动同步（如客户会议改色后生效）
        final demos = _buildDemoTasks();
        for (final d in demos) {
          final idx = existing.indexWhere((t) =>
              t.title == d.title &&
              t.start.millisecondsSinceEpoch ==
                  d.start.millisecondsSinceEpoch &&
              t.end.millisecondsSinceEpoch == d.end.millisecondsSinceEpoch);
          if (idx >= 0 && existing[idx].colorValue != d.colorValue) {
            final updated = existing[idx].copyWith(colorValue: d.colorValue);
            await _db.update(updated);
          }
        }
      }
      _seedActivityIfEmpty();
      _sourceCache = await _db.allTasks();
      await loadDay(_selectedDay);
    } catch (_) {
      // sqflite 在不支持的平台（如 Windows 桌面）会抛异常，安全跳过数据库，
      // 但活动配置仍从 _prefs/内存种子恢复，保证记录页可用。
      _seedActivityIfEmpty();
    }
  }

  void _seedDemoIfEmpty() {
    if (_memoryStore.isNotEmpty) return;
    _seedDemo();
    _persistMemory();
  }

  // ---- 活动配置：种子 + 持久化 ----
  void _seedActivityIfEmpty() {
    if (_activitySeeded) return;
    // 先用本地存储恢复
    if (_prefs != null) {
      final cRaw = _prefs!.getString(_kCategoriesKey);
      final aRaw = _prefs!.getString(_kActivitiesKey);
      if (cRaw != null && cRaw.isNotEmpty && aRaw != null && aRaw.isNotEmpty) {
        try {
          _categories = (jsonDecode(cRaw) as List)
              .cast<Map<String, dynamic>>()
              .map(ActivityCategory.fromMap)
              .toList();
          _activityTypes = (jsonDecode(aRaw) as List)
              .cast<Map<String, dynamic>>()
              .map(ActivityType.fromMap)
              .toList();
          _activitySeeded = true;
          return;
        } catch (_) {
          // 解析失败走默认种子
        }
      }
    }
    _seedActivityDefaults();
    _persistActivities();
    _activitySeeded = true;
  }

  void _seedActivityDefaults() {
    _categories = [
      ActivityCategory(name: '工作', colorValue: AppColors.taskPalette[6].value),
      ActivityCategory(name: '学习', colorValue: AppColors.taskPalette[7].value),
      ActivityCategory(name: '生活', colorValue: AppColors.taskPalette[3].value),
      ActivityCategory(name: '休闲', colorValue: AppColors.taskPalette[9].value),
    ];
    _activityTypes = [
      ActivityType(name: '工作', iconCodePoint: CupertinoIcons.briefcase_fill.codePoint, categoryName: '工作'),
      ActivityType(name: '会议', iconCodePoint: CupertinoIcons.person_2_fill.codePoint, categoryName: '工作'),
      ActivityType(name: '学习', iconCodePoint: CupertinoIcons.book_fill.codePoint, categoryName: '学习'),
      ActivityType(name: '阅读', iconCodePoint: CupertinoIcons.book.codePoint, categoryName: '学习'),
      ActivityType(name: '运动', iconCodePoint: CupertinoIcons.sportscourt_fill.codePoint, categoryName: '生活'),
      ActivityType(name: '用餐', iconCodePoint: CupertinoIcons.house_fill.codePoint, categoryName: '生活'),
      ActivityType(name: '休息', iconCodePoint: CupertinoIcons.moon_fill.codePoint, categoryName: '休闲'),
      ActivityType(name: '娱乐', iconCodePoint: CupertinoIcons.game_controller_solid.codePoint, categoryName: '休闲'),
    ];
  }

  /// 持久化活动配置（categories/activities）。
  /// 关键修复（问题3/6）：Web 与真机都写 SharedPreferences，
  /// 不再 `if (!_memoryMode) return`，否则真机活动配置只存内存、重启即丢。
  void _persistActivities() {
    if (_prefs == null) return;
    _prefs!.setString(_kCategoriesKey,
        jsonEncode(_categories.map((c) => c.toMap()).toList()));
    _prefs!.setString(_kActivitiesKey,
        jsonEncode(_activityTypes.map((a) => a.toMap()).toList()));
  }

  // ---- 大类 CRUD ----
  void addCategory(ActivityCategory c) {
    if (_categories.any((e) => e.name == c.name)) return;
    _categories.add(c);
    _persistActivities();
    notifyListeners();
  }

  void updateCategory(String oldName, ActivityCategory updated) {
    final i = _categories.indexWhere((e) => e.name == oldName);
    if (i < 0) return;
    _categories[i] = updated;
    // 同步更新该大类下活动的关联名
    if (oldName != updated.name) {
      for (final a in _activityTypes) {
        if (a.categoryName == oldName) a.categoryName = updated.name;
      }
    }
    _persistActivities();
    notifyListeners();
  }

  void deleteCategory(String name) {
    if (!_categories.any((e) => e.name == name)) return;
    _categories.removeWhere((e) => e.name == name);
    // 该大类下的活动一并删除（避免悬空引用）
    _activityTypes.removeWhere((a) => a.categoryName == name);
    _persistActivities();
    notifyListeners();
  }

  // ---- 活动 CRUD ----
  void addActivity(ActivityType a) {
    _activityTypes.add(a);
    _persistActivities();
    notifyListeners();
  }

  void updateActivity(String oldName, ActivityType updated) {
    final i = _activityTypes.indexWhere((e) => e.name == oldName);
    if (i < 0) return;
    _activityTypes[i] = updated;
    _persistActivities();
    notifyListeners();
  }

  void deleteActivity(String name) {
    _activityTypes.removeWhere((e) => e.name == name);
    _persistActivities();
    notifyListeners();
  }

  /// 持久化内存数据到本地（Web 专用；真机任务走 SQLite）
  void _persistMemory() {
    if (!_memoryMode || _prefs == null) return;
    final data = _memoryStore.map((t) => t.toMap()).toList();
    _prefs!.setString(_kStoreKey, jsonEncode(data));
  }

  // ---- 进行中计时会话的持久化 ----
  // 退出软件 / 切到其它 tab 再回来，会话状态都从本地恢复，绝不丢失。
  // 关键修复（需求4/问题3）：Web 与真机都写 SharedPreferences，
  // 不再 `if (!_memoryMode) return`，否则真机计时状态切 tab/重启即丢。
  Future<void> saveRecordingSession(RecordingSession s) async {
    if (_prefs == null) return;
    await _prefs!.setString(_kRecordingKey, jsonEncode(s.toMap()));
  }

  RecordingSession? loadRecordingSession() {
    if (_prefs == null) return null;
    final raw = _prefs!.getString(_kRecordingKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return RecordingSession.fromMap(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearRecordingSession() async {
    if (_prefs == null) return;
    await _prefs!.remove(_kRecordingKey);
  }

  /// 批量保存多条任务（用于分段计时停止后生成多段记录）
  Future<void> addTasks(List<Task> tasks) async {
    for (final t in tasks) {
      await addTask(t);
    }
  }

  List<Task> _tasks = []; // 当前选中日的任务
  DateTime _selectedDay = DateTime.now();
  CalendarViewMode _viewMode = CalendarViewMode.day;
  bool _seeded = false;
  bool _showReminders = true; // 是否在日历中显示提醒事项

  // 提醒事项列表视图状态
  String _selectedList = '今天';
  ListFilter _listFilter = ListFilter.all;

  List<Task> get tasks => _tasks;
  DateTime get selectedDay => _selectedDay;
  CalendarViewMode get viewMode => _viewMode;
  bool get showReminders => _showReminders;
  String get selectedList => _selectedList;
  ListFilter get listFilter => _listFilter;

  List<Task> get allDayTasks => _tasks.where((t) => t.isAllDay).toList();
  List<Task> get timedTasks =>
      _tasks.where((t) => !t.isAllDay && !t.isReminder).toList();
  List<Task> get dayReminders =>
      _tasks.where((t) => t.isReminder).toList();

  void setViewMode(CalendarViewMode m) {
    _viewMode = m;
    notifyListeners();
  }

  void setSelectedList(String name) {
    _selectedList = name;
    _listFilter = ListFilter.all;
    notifyListeners();
  }

  void setListFilter(ListFilter f) {
    _listFilter = f;
    notifyListeners();
  }

  void toggleShowReminders() {
    _showReminders = !_showReminders;
    loadDay(_selectedDay);
  }

  List<Task> filteredListTasks() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final all = _allTasksSync();
    // 基础范围：提醒事项或带 listName 的任务
    var base = all.where((t) => t.isReminder || t.listName.isNotEmpty).toList();

    // 按左侧选中列表过滤
    switch (_selectedList) {
      case '今天':
        base = base.where((t) => _isSameDay(t.start, now)).toList();
        break;
      case '计划':
        base = base.where((t) => t.start.isAfter(now) || _isSameDay(t.start, now)).toList();
        break;
      default:
        base = base.where((t) => t.listName == _selectedList).toList();
    }

    // 按顶部筛选
    switch (_listFilter) {
      case ListFilter.today:
        base = base.where((t) => _isSameDay(t.start, now)).toList();
        break;
      case ListFilter.planned:
        base = base.where((t) => t.start.isAfter(now) || _isSameDay(t.start, now)).toList();
        break;
      case ListFilter.flagged:
        base = base.where((t) => t.isFlagged).toList();
        break;
      case ListFilter.completed:
        base = base.where((t) => t.isDone).toList();
        break;
      case ListFilter.assignedToMe:
        base = base.where((t) => t.category.contains('分配')).toList();
        break;
      case ListFilter.all:
        break;
    }

    return base..sort((a, b) => a.start.compareTo(b.start));
  }


  /// 生成演示任务列表（Web 内存 和 真机数据库 共用）
  List<Task> _buildDemoTasks() {
    final now = DateTime.now();
    DateTime at(int d, int h, int m) =>
        DateTime(now.year, now.month, now.day + d, h, m);
    int cid = 1;
    Task ev(int d, int sh, int sm, int eh, int em, String title, int c,
            {bool reminder = false,
            bool allDay = false,
            String listName = '',
            String repeatRule = '永不'}) =>
        Task(
          id: cid++,
          title: title,
          start: at(d, sh, sm),
          end: at(d, eh, em),
          colorValue: AppColors.taskPalette[c].value,
          isReminder: reminder,
          isAllDay: allDay,
          listName: listName,
          repeatRule: repeatRule,
        );
    return [
      // 今天
      ev(0, 7, 0, 8, 0, '晨间锻炼', 3),
      ev(0, 9, 30, 10, 0, '团队晨会', 6),
      ev(0, 10, 0, 12, 0, '专注工作', 8),
      ev(0, 12, 0, 13, 0, '午餐', 1),
      ev(0, 14, 0, 15, 30, '阅读', 7),
      ev(0, 16, 0, 18, 0, '写代码', 4),
      ev(0, 20, 0, 20, 30, '回复邮件', 0, reminder: true, listName: '今天'),
      ev(0, 0, 0, 0, 0, '交周报', 9, reminder: true, allDay: true, listName: '周计划'),
      // 重复事件示例（用于验证重复展开）
      ev(-2, 18, 0, 19, 0, '每周瑜伽', 5, repeatRule: '每周'),
      ev(-3, 8, 0, 9, 0, '每日打卡', 2, repeatRule: '每天'),
      ev(0, 21, 0, 21, 30, '每月复盘', 0, repeatRule: '每月'),
      // 昨天/明天/本周其它
      ev(-1, 9, 0, 11, 0, '产品评审', 6),
      ev(-1, 15, 0, 16, 0, '健身', 3),
      ev(1, 10, 0, 12, 0, '客户会议', 6),
      ev(1, 14, 0, 15, 0, '午休散步', 4),
      ev(2, 9, 0, 10, 30, '写方案', 8),
      // 列表示例数据
      ev(1, 0, 0, 0, 0, '阅读 2 本书', 7, reminder: true, allDay: true, listName: '月计划'),
      ev(2, 0, 0, 0, 0, '开心清单：看电影', 9, reminder: true, allDay: true, listName: '开心清单'),
      ev(3, 0, 0, 0, 0, '书单：复购元认知', 8, reminder: true, allDay: true, listName: '书单'),
      // 年计划/周计划示例数据（之前为空，导致切换看似无反应）
      ev(5, 0, 0, 0, 0, '年计划：存款 10 万', 6, reminder: true, allDay: true, listName: '年计划'),
      ev(0, 9, 0, 10, 0, '周计划：完成季度报告', 4, reminder: true, allDay: true, listName: '周计划'),
      ev(0, 15, 0, 16, 0, '周计划：健身 3 次', 3, reminder: true, allDay: true, listName: '周计划'),
    ];
  }

  void _seedDemo() {
    if (_seeded) return;
    _seeded = true;
    _memoryStore.addAll(_buildDemoTasks());
  }

  List<Task> get allTasks => _expandedForMonth();

  /// 返回源任务（未展开的存储数据），供编辑/持久化使用
  List<Task> _sourceCache = []; // 真机模式下缓存最近一次从 DB 读的源任务
  List<Task> _rawAll() {
    if (_memoryMode) {
      _seedDemoIfEmpty();
      return _memoryStore;
    }
    return _sourceCache;
  }

  List<Task> _allTasksSync() {
    _seedDemoIfEmpty();
    return _memoryStore;
  }

  /// 当前选中月 ±1 月范围内展开的重复实例（供月视图/搜索展示）
  List<Task> _expandedForMonth() {
    final base = _rawAll();
    final m = _selectedDay;
    final from = DateTime(m.year, m.month - 1, 1);
    final to = DateTime(m.year, m.month + 2, 1);
    return _expandRepeats(base, from, to);
  }

  /// 根据重复规则把源任务展开为 [from, to) 范围内出现的派生实例。
  /// 源任务自身始终保留；派生实例带 seriesId/occurrenceDate，不写库。
  List<Task> _expandRepeats(List<Task> source, DateTime from, DateTime to) {
    if (source.isEmpty) return [];
    final out = <Task>[];
    final fromDay = DateTime(from.year, from.month, from.day);
    final toDay = DateTime(to.year, to.month, to.day);
    for (final t in source) {
      out.add(t); // 源实例
      if (t.repeatRule == '永不' || t.isReminder) continue;
      final delta = t.duration;
      final rule = t.repeatRule;
      // 按规则生成"下一个出现日"，从源日期之后开始
      DateTime? next(DateTime after) {
        final day = _dayOnly(after).add(const Duration(days: 1));
        switch (rule) {
          case '每天':
            return day;
          case '每周':
            return day.add(Duration(days: 7));
          case '每两周':
            return day.add(Duration(days: 14));
          case '每月':
            return _addMonths(t.start, 1);
          case '每年':
            return _addMonths(t.start, 12);
          default:
            return null;
        }
      }

      DateTime cursor;
      if (rule == '每月' || rule == '每年') {
        // 日历对齐步进：从源日期按"月/年"推，避免在源日期当天重复
        cursor = _addMonths(t.start, rule == '每年' ? 12 : 1);
      } else {
        cursor = _dayOnly(t.start).add(Duration(days: _repeatStepDays(rule)!));
      }

      int guard = 0;
      while (!cursor.isAfter(toDay) && guard < 5000) {
        guard++;
        if (!cursor.isBefore(fromDay)) {
          final start = DateTime(cursor.year, cursor.month, cursor.day,
              t.start.hour, t.start.minute);
          out.add(t.copyWith(
            id: null,
            start: start,
            end: start.add(delta),
            seriesId: t.id,
            occurrenceDate: cursor,
          ));
        }
        final n = next(cursor);
        if (n == null) break;
        cursor = n;
      }
    }
    return out;
  }

  /// 在日期 d 上增加 months 个月，保留"日"；若目标月无该日则取月末（如 1/31 -> 2/28）
  DateTime _addMonths(DateTime d, int months) {
    final total = (d.year * 12 + (d.month - 1)) + months;
    final y = total ~/ 12;
    final m = (total % 12) + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    final day = d.day > lastDay ? lastDay : d.day;
    return DateTime(y, m, day, d.hour, d.minute);
  }

  int? _repeatStepDays(String rule) {
    switch (rule) {
      case '每天':
        return 1;
      case '每周':
        return 7;
      case '每两周':
        return 14;
      default:
        return null; // 每月/每年走 _addMonths
    }
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 点开重复派生实例时，找回其源任务以便编辑（编辑一次全系列生效）
  Task sourceTaskFor(Task t) {
    if (t.seriesId == null) return t;
    final all = _rawAll();
    try {
      return all.firstWhere((e) => e.id == t.seriesId);
    } catch (_) {
      return t;
    }
  }

  /// Web 端导出：直接返回 JSON 字符串（无文件系统），含任务 + 个人偏好（分类/活动含颜色）
  String exportBackupJson() {
    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': _memoryStore.map((t) => t.toMap()).toList(),
      'categories': _categories.map((c) => c.toMap()).toList(),
      'activities': _activityTypes.map((a) => a.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  bool _inDay(Task t, DateTime day) {
    final s = DateTime(day.year, day.month, day.day);
    final e = s.add(const Duration(days: 1));
    return t.start.isBefore(e) && t.end.isAfter(s) ||
        (t.isAllDay && _isSameDay(t.start, day));
  }

  /// 按视图范围取"已展开重复"的全量任务（内存/真机统一入口）。
  /// 内存模式直接展开；真机模式先把源任务拉出来再展开。
  Future<List<Task>> _expandedAll(DateTime from, DateTime to) async {
    List<Task> source;
    if (_memoryMode) {
      source = _rawAll();
    } else {
      source = await _db.allTasks();
      _sourceCache = source; // 缓存，供 month 视图的同步 allTasks getter 使用
    }
    return _expandRepeats(source, from, to);
  }

  Future<void> loadDay(DateTime day) async {
    _selectedDay = day;
    final from = day.subtract(const Duration(
        days: 366)); // 覆盖每月/每年规则在 day 之前最近一次落点
    final to = DateTime(day.year, day.month, day.day + 1);
    final all = await _expandedAll(from, to);
    _tasks = all
        .where((t) => _inDay(t, day))
        .where((t) => _showReminders || !t.isReminder)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    notifyListeners();
  }

  /// 获取指定日期的任务（供月/周视图用，不改变选中日）
  Future<List<Task>> tasksForDay(DateTime day) async {
    final from = day.subtract(const Duration(days: 366));
    final to = DateTime(day.year, day.month, day.day + 1);
    final all = await _expandedAll(from, to);
    return all
        .where((t) => _inDay(t, day))
        .where((t) => _showReminders || !t.isReminder)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  /// 同步版（内存模式/已缓存），供绘制月点用
  List<Task> tasksForDaySync(DateTime day) {
    if (!_memoryMode) return const [];
    final from = day.subtract(const Duration(days: 366));
    final to = DateTime(day.year, day.month, day.day + 1);
    final all = _expandRepeats(_rawAll(), from, to);
    return all
        .where((t) => _inDay(t, day))
        .where((t) => _showReminders || !t.isReminder)
        .toList();
  }

  /// 获取一段范围内全部任务（列表视图用）
  Future<List<Task>> tasksInRange(DateTime from, DateTime to) async {
    final all = await _expandedAll(from, to);
    return all
        .where((t) => t.end.isAfter(from) && t.start.isBefore(to))
        .where((t) => _showReminders || !t.isReminder)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  void changeDay(int deltaDays) =>
      loadDay(_selectedDay.add(Duration(days: deltaDays)));

  void changeMonth(int deltaMonths) {
    final d = _selectedDay;
    loadDay(DateTime(d.year, d.month + deltaMonths, d.day));
  }

  Future<void> addTask(Task t) async {
    try {
      if (_memoryMode) {
        final id = (_memoryStore
                    .map((e) => e.id ?? 0)
                    .fold(0, (a, b) => a > b ? a : b)) +
            1;
        _memoryStore.add(t.copyWith(id: id));
        _persistMemory();
        await loadDay(_selectedDay);
        notifyListeners(); // 列表视图也刷新
        return;
      }
      await _db.insert(t);
      _sourceCache = await _db.allTasks();
      await loadDay(_selectedDay);
      notifyListeners();
    } catch (e) {
      // 关键兜底：单点 DB 异常（如字段不匹配）不应拖垮整个 app 导致白屏，
      // 改为打印并安全跳过，至少保证 UI 不崩。
      debugPrint('addTask 失败: $e');
    }
  }

  Future<void> updateTask(Task t) async {
    try {
      if (_memoryMode) {
        final i = _memoryStore.indexWhere((e) => e.id == t.id);
        if (i >= 0) _memoryStore[i] = t;
        _persistMemory();
        await loadDay(_selectedDay);
        notifyListeners();
        return;
      }
      await _db.update(t);
      _sourceCache = await _db.allTasks();
      await loadDay(_selectedDay);
      notifyListeners();
    } catch (e) {
      debugPrint('updateTask 失败: $e');
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      if (_memoryMode) {
        _memoryStore.removeWhere((e) => e.id == id);
        _persistMemory();
        await loadDay(_selectedDay);
        notifyListeners();
        return;
      }
      await _db.delete(id);
      _sourceCache = await _db.allTasks();
      await loadDay(_selectedDay);
      notifyListeners();
    } catch (e) {
      debugPrint('deleteTask 失败: $e');
    }
  }

  Future<void> toggleDone(Task t) async {
    await updateTask(t.copyWith(isDone: !t.isDone));
  }

  /// 统一的导出入口：
  /// - Web 端：返回 JSON 字符串（由调用方复制到剪贴板/展示），含任务+个人偏好
  /// - 真机端：写入 JSON 文件（含任务+个人偏好）并返回路径
  Future<String> exportBackupUnified() async {
    if (_memoryMode) {
      return exportBackupJson();
    }
    return _db.exportBackup(
      categories: _categories.map((c) => c.toMap()).toList(),
      activities: _activityTypes.map((a) => a.toMap()).toList(),
    );
  }

  /// 统一的导入入口（合并去重）：
  /// - Web 端：解析 JSON 合并进内存存储并持久化
  /// - 真机端：写入数据库（DatabaseService 内部去重）
  /// 同时恢复个人偏好（categories/activities 含颜色）。
  /// 返回实际导入的任务条数。
  Future<int> importBackupUnified(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    // 恢复个人偏好（分类/活动，含颜色）
    if (data.containsKey('categories') && data.containsKey('activities')) {
      try {
        _categories = (data['categories'] as List)
            .cast<Map<String, dynamic>>()
            .map(ActivityCategory.fromMap)
            .toList();
        _activityTypes = (data['activities'] as List)
            .cast<Map<String, dynamic>>()
            .map(ActivityType.fromMap)
            .toList();
        _persistActivities();
      } catch (_) {
        // 偏好解析失败则保留现有配置
      }
    }
    if (_memoryMode) {
      final list = (data['tasks'] as List).cast<Map<String, dynamic>>();
      final seen = <String>{};
      for (final t in _memoryStore) {
        seen.add(_dedupKey(t.title, t.start, t.end, t.colorValue));
      }
      int count = 0;
      for (final m in list) {
        final t = Task.fromMap(m);
        final key = _dedupKey(t.title, t.start, t.end, t.colorValue);
        if (seen.contains(key)) continue;
        // 分配新 id，避免与现有冲突
        final id = (_memoryStore.isEmpty
                ? 0
                : _memoryStore
                        .map((e) => e.id ?? 0)
                        .reduce((a, b) => a > b ? a : b)) +
            1;
        _memoryStore.add(t.copyWith(id: id));
        seen.add(key);
        count++;
      }
      _persistMemory();
      notifyListeners();
      await loadDay(_selectedDay);
      return count;
    }
    final n = await _db.importBackup(jsonStr);
    notifyListeners();
    await loadDay(_selectedDay);
    return n;
  }

  String _dedupKey(String title, DateTime start, DateTime end, int color) =>
      '$title|${start.millisecondsSinceEpoch}|${end.millisecondsSinceEpoch}|$color';

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
