import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../utils/colors.dart';
import 'event_side_line.dart';
import 'pressable_scale.dart';

/// 苹果风格周视图：7 列，左侧统一 24h 时间轴，每列顶部有“全天”区域，/// 时间块圆角、带彩色小点、标题+时间范围，支持重叠自动排列。
class WeekView extends StatefulWidget {
  final void Function(Task task) onTapTask;
  final void Function(DateTime start) onTapEmpty;
  final void Function(DateTime day) onAddAllDay;
  const WeekView({
    super.key,
    required this.onTapTask,
    required this.onTapEmpty,
    required this.onAddAllDay,
  });

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  // 时间轴每小时高度：可双指捏合缩放，有上下限（不能太大/太小）
  static const double _minHourHeight = 40.0;
  static const double _maxHourHeight = 140.0;
  double hourHeight = 60.0;
  double _scaleBaseHeight = 60.0;
  static const double timeColWidth = 46.0;
  static const double allDayHeight = 60.0;
  final ScrollController _scroll = ScrollController();
  Timer? _timer;

  final Map<int, Offset> _pointers = {};
  double? _pinchStartDist;

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      final pts = _pointers.values.toList();
      _pinchStartDist = (pts[0] - pts[1]).distance;
      _scaleBaseHeight = hourHeight;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2 && _pinchStartDist != null &&
        _pinchStartDist! > 0) {
      final pts = _pointers.values.toList();
      final dist = (pts[0] - pts[1]).distance;
      final scale = dist / _pinchStartDist!;
      final newH =
          (_scaleBaseHeight * scale).clamp(_minHourHeight, _maxHourHeight);
      if (newH != hourHeight) setState(() => hourHeight = newH);
    }
  }

  void _onPointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchStartDist = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _scrollToNow() {
    final now = DateTime.now();
    final offset = (now.hour + now.minute / 60.0) * hourHeight - 160;
    if (_scroll.hasClients) {
      _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  List<DateTime> _weekDays(DateTime sel) {
    final weekday = sel.weekday % 7; // 周日=0
    final sunday = sel.subtract(Duration(days: weekday));
    return List.generate(
        7, (i) => DateTime(sunday.year, sunday.month, sunday.day + i));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final days = _weekDays(provider.selectedDay);
    final today = DateTime.now();

    return Column(
      children: [
        // 日期头（7 天，无左侧时间列）
        // 注意：年月标题已统一上提到 calendar_page.dart 的 _buildBody 之前，
        Row(
          children: [
            // 左侧占位与全天/时间轴列对齐
            SizedBox(width: timeColWidth),
            ...days.map((d) => Expanded(
                  child: _DateHeader(
                    day: d,
                    isToday: _isSameDay(d, today),
                  ),
                )),
          ],
        ),
        const Divider(height: 1),
        // 全天区域
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: timeColWidth,
              child: Container(
                height: allDayHeight,
                alignment: Alignment.center,
                child: const Text('全天',
                    style: TextStyle(decoration: TextDecoration.none, 
                        fontSize: 11, color: AppColors.secondaryLabel)),
              ),
            ),
            ...days.map((d) => Expanded(
                  child: FutureBuilder<List<Task>>(
                    future: provider.tasksForDay(d),
                    builder: (ctx, snap) {
                      final tasks = snap.data ?? [];
                      final allDay = tasks
                          .where((t) => t.isAllDay || t.isReminder)
                          .toList();
                      return _AllDayColumn(
                        tasks: allDay,
                        day: d,
                        onTapTask: widget.onTapTask,
                        onTapEmpty: () => widget.onAddAllDay(d),
                        onToggleDone: (t) => provider.toggleDone(t),
                      );
                    },
                  ),
                )),
          ],
        ),
        const Divider(height: 1),
        // 时间轴网格
        Expanded(
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerUp,
            onPointerSignal: (sig) {
              if (sig is PointerScrollEvent &&
                  HardwareKeyboard.instance.isControlPressed) {
                final delta = -sig.scrollDelta.dy * 0.2;
                final newH = (hourHeight + delta)
                    .clamp(_minHourHeight, _maxHourHeight);
                if (newH != hourHeight) setState(() => hourHeight = newH);
              }
            },
            child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: hourHeight * 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间刻度列
                  SizedBox(
                    width: timeColWidth,
                    child: Column(
                      children: List.generate(24, (h) {
                        return SizedBox(
                          height: hourHeight,
                          child: Transform.translate(
                            offset: const Offset(0, -7),
                            child: Text(
                              h == 0 ? '' : _hLabel(h),
                              textAlign: TextAlign.right,
                              style: const TextStyle(decoration: TextDecoration.none, 
                                  fontSize: 11,
                                  color: AppColors.secondaryLabel),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // 7 天列
                  ...days.map((d) => Expanded(
                        child: FutureBuilder<List<Task>>(
                          future: provider.tasksForDay(d),
                          builder: (ctx, snap) {
                            final tasks = snap.data ?? [];
                            return _DayColumn(
                              day: d,
                              hourHeight: hourHeight,
                              tasks: tasks,
                              isToday: _isSameDay(d, today),
                              onTapTask: widget.onTapTask,
                              onTapEmpty: widget.onTapEmpty,
                            );
                          },
                        ),
                      )),
                ],
              ),
            ),
          ),
          ),
        ),
      ],
    );
  }

  String _hLabel(int h) => '${h.toString().padLeft(2, '0')}:00';

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateHeader extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  const _DateHeader({required this.day, required this.isToday});

  static const _wk = ['日', '一', '二', '三', '四', '五', '六'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(decoration: TextDecoration.none, 
                fontSize: 15,
                fontWeight:
                    isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday
                    ? AppColors.destructive
                    : AppColors.label),
          ),
          const SizedBox(height: 1),
          Text(
            _wk[day.weekday % 7],
            style: TextStyle(decoration: TextDecoration.none, 
                fontSize: 11,
                color: isToday
                    ? AppColors.destructive
                    : AppColors.secondaryLabel,
                fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

class _AllDayColumn extends StatelessWidget {
  final List<Task> tasks;
  final DateTime day;
  final void Function(Task) onTapTask;
  final VoidCallback onTapEmpty;
  final void Function(Task) onToggleDone;
  const _AllDayColumn({
    required this.tasks,
    required this.day,
    required this.onTapTask,
    required this.onTapEmpty,
    required this.onToggleDone,
  });

  // 固定容纳 3 条，超出滚动
  static const double _itemHeight = 22.0;
  static const int _maxVisible = 3;
  static const double _fixedHeight = _itemHeight * _maxVisible + 8;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _fixedHeight,
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.gridLine, width: 0.5),
        ),
      ),
      child: tasks.isEmpty
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTapEmpty,
              child: const SizedBox.expand(),
            )
          : GestureDetector(
              // 点空白处（非条目）也新建
              onTap: onTapEmpty,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                itemCount: tasks.length,
                itemBuilder: (ctx, i) {
                  final t = tasks[i];
                  return Container(
                    height: _itemHeight,
                    margin: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onToggleDone(t),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: t.isDone
                                  ? AppColors.accent
                                  : Colors.transparent,
                              border: Border.all(
                                color: t.isDone
                                    ? AppColors.accent
                                    : AppColors.secondaryLabel,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onTapTask(t),
                            child: Text(t.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(decoration: TextDecoration.none, 
                                    fontSize: 11,
                                    color: t.isDone
                                        ? AppColors.label
                                        : AppColors.blockTitleColor(t.colorValue))),
                          ),
                        ),
                        if (t.repeatRule != '永不')
                          Icon(CupertinoIcons.repeat,
                              size: 10, color: AppColors.lineOf(t.colorValue)),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final DateTime day;
  final double hourHeight;
  final List<Task> tasks;
  final bool isToday;
  final void Function(Task) onTapTask;
  final void Function(DateTime) onTapEmpty;

  const _DayColumn({
    required this.day,
    required this.hourHeight,
    required this.tasks,
    required this.isToday,
    required this.onTapTask,
    required this.onTapEmpty,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timed = tasks.where((t) => !t.isAllDay && !t.isReminder).toList();
    final layout = _layoutTasks(timed);
    final colWidth = (MediaQuery.of(context).size.width - 46.0) / 7;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (d) {
        final y = d.localPosition.dy;
        final hour = (y / hourHeight).floor().clamp(0, 23);
        onTapEmpty(DateTime(day.year, day.month, day.day, hour, 0));
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: AppColors.gridLine, width: 0.5),
          ),
        ),
        child: Stack(
          children: [
            // 小时线
            ...List.generate(
                24,
                (h) => Positioned(
                      top: h * hourHeight,
                      left: 0,
                      right: 0,
                      child: Container(
                          height: 0.5, color: AppColors.gridLine),
                    )),
            // 时间块
            ...layout.map((item) => _buildBlock(item, colWidth)),
          ],
        ),
      ),
    );
  }

  Widget _buildBlock(_LayoutItem item, double colWidth) {
    final t = item.task;
    final startMin = t.start.hour * 60 + t.start.minute;
    final endMin = t.end.hour * 60 + t.end.minute;
    final top = startMin / 60.0 * hourHeight;
    final height = ((endMin - startMin) / 60.0 * hourHeight).clamp(18.0, 9999.0);
    final leftRatio = item.column / item.columns;
    final widthRatio = 1.0 / item.columns;
    // 修复：left 应直接按列索引占比算，不应再乘 widthRatio。
    // 原代码 left = colWidth * widthRatio * leftRatio 导致 column=1 时只到 1/4 处，
    // 右侧重叠块被截断/溢出。
    final left = colWidth * leftRatio;
    final width = (colWidth * widthRatio - 1).clamp(6.0, double.infinity);

    // 基于最新参考图 replica_final.py 像素实测（块 1037×437）：
    // 线左距块左 27px≈2.6%，线宽 13px≈1.25%，线→文字 33px≈3.2%，
    // 线上下留白各约 6%，标题顶距线顶 8px≈1.8%。周列窄，上限收紧。
    final lineGap = (width * 0.026).clamp(4.0, 12.0);
    final lineW = (width * 0.0125).clamp(2.0, 4.0);
    final lineInset = (height * 0.06).clamp(2.0, 14.0);
    final lineToText = (width * 0.032).clamp(2.0, 6.0);
    final textTopOffset = (height * 0.018).clamp(2.0, 6.0);

    // 字号固定：不随任务框高度变化（用户明确要求）
    const titleSize = 14.0;
    const timeSize = 11.0;
    const circleSize = 4.0;

    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height.toDouble(),
      child: PressableScale(
        scaleDown: 0.9,
        onTap: () => onTapTask(t),
        child: Container(
          // 上下 padding = 线 inset，让线从块顶/底内缩；左右保持呼吸感
          padding: EdgeInsets.fromLTRB(lineGap, lineInset, 4, lineInset),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: t.isDone
                ? AppColors.fillOf(t.colorValue).withAlpha(90)
                : AppColors.fillOf(t.colorValue),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // 左侧竖线（直角方头），容器已处理上下内缩
              EventSideLine(
                color: AppColors.lineOf(t.colorValue),
                width: lineW,
                inset: 0,
              ),
              SizedBox(width: lineToText),
              Expanded(
                child: Padding(
                  // 标题下沉到线顶下方；高度紧张时不额外下沉，优先保证不溢出
                  padding: EdgeInsets.only(
                      top: (height - 2 * lineInset >=
                              titleSize + timeSize + textTopOffset + 4)
                          ? textTopOffset
                          : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(decoration: TextDecoration.none, 
                          fontSize: titleSize,
                          fontWeight: FontWeight.w600,
                          color: AppColors.label,
                        ),
                      ),
                    // 固定字号不随块高变化；空间不足时隐藏时间行，避免溢出
                    if (height - 2 * lineInset >=
                        titleSize + timeSize + textTopOffset + 4)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                            Container(
                              width: circleSize,
                              height: circleSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.blockSubColor(t.colorValue),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${_fmt(t.start)} - ${_fmt(t.end)}',
                              style: TextStyle(decoration: TextDecoration.none, 
                                fontSize: timeSize,
                                color: t.isDone
                                    ? AppColors.label
                                    : AppColors.blockSubColor(t.colorValue),
                              ),
                            ),
                          ],
                        ),
                    // 备注：在名称、时间下方单独一行，更小字体，颜色与时间段标识对齐
                    if (t.note.trim().isNotEmpty &&
                        height - 2 * lineInset >=
                            titleSize + timeSize + (timeSize - 2) +
                                textTopOffset + 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          t.note.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(decoration: TextDecoration.none, 
                            fontSize: timeSize - 2,
                            color: t.isDone
                                ? AppColors.secondaryLabel
                                : AppColors.blockSubColor(t.colorValue),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
                  ],
                ),
          ),
        ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  bool _overlaps(Task a, Task b) =>
      a.start.isBefore(b.end) && a.end.isAfter(b.start);

  List<_LayoutItem> _layoutTasks(List<Task> tasks) {
    if (tasks.isEmpty) return [];
    final sorted = tasks.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final items = sorted
        .map((t) => _LayoutItem(task: t, column: 0, columns: 1))
        .toList();

    // 贪心分配列
    for (int i = 0; i < items.length; i++) {
      int col = 0;
      while (true) {
        bool ok = true;
        for (int j = 0; j < i; j++) {
          if (items[j].column == col && _overlaps(items[j].task, items[i].task)) {
            ok = false;
            break;
          }
        }
        if (ok) break;
        col++;
      }
      items[i].column = col;
    }

    // 计算每个任务所在冲突团的总列数
    for (int i = 0; i < items.length; i++) {
      int maxCol = items[i].column;
      for (int j = 0; j < items.length; j++) {
        if (i != j && _overlaps(items[i].task, items[j].task)) {
          maxCol = max(maxCol, items[j].column);
        }
      }
      items[i].columns = max(1, maxCol + 1);
    }
    return items;
  }
}

class _LayoutItem {
  final Task task;
  int column;
  int columns;
  _LayoutItem({required this.task, required this.column, required this.columns});
}
