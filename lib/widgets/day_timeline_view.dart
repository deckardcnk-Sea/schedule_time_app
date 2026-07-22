import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task_model.dart';
import '../utils/colors.dart';
import 'event_side_line.dart';
import 'pressable_scale.dart';

/// 日视图：单列 24h 时间轴，左侧 24 小时制数字，/// 顶部可选全天/提醒事项，时间块圆角带小点+时间范围，支持重叠。
class DayTimelineView extends StatefulWidget {
  final List<Task> tasks;
  final void Function(Task task) onTapTask;
  final void Function(DateTime start) onTapEmpty;
  final void Function(Task task)? onToggleDone;

  const DayTimelineView({
    super.key,
    required this.tasks,
    required this.onTapTask,
    required this.onTapEmpty,
    this.onToggleDone,
  });

  @override
  State<DayTimelineView> createState() => _DayTimelineViewState();
}

class _DayTimelineViewState extends State<DayTimelineView> {
  // 时间轴每小时高度：可通过双指捏合缩放，有上下限（不能太大/太小）
  static const double _minHourHeight = 40.0;
  static const double _maxHourHeight = 140.0;
  double hourHeight = 60.0;
  double _scaleBaseHeight = 60.0; // 缩放手势开始时的基准高度
  static const double timeColWidth = 56.0;
  final ScrollController _scroll = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  // 双指捏合缩放：用 Listener 在指针层实现，避免与滚动手势竞技（不破坏滚动）
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final allDay = widget.tasks.where((t) => t.isAllDay || t.isReminder).toList();
    final timed = widget.tasks.where((t) => !t.isAllDay && !t.isReminder).toList();
    final layout = _layoutTasks(timed);

    return Column(
      children: [
        if (allDay.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: allDay.map((t) => _allDayRow(t)).toList(),
            ),
          ),
        if (allDay.isNotEmpty) const Divider(height: 1),
        Expanded(
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerUp,
            // 桌面：Ctrl + 滚轮缩放时间轴
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
                child: Stack(
                  children: [
                    ..._buildHourGrid(),
                    _buildTapLayer(),
                    ...layout.map((item) => _buildBlock(item)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _allDayRow(Task t) {
    final isReminder = t.isReminder;
    final lineColor = AppColors.lineOf(t.colorValue);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // 可点击圆圈：点击切换完成，完成后填充蓝色、整行变灰
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onToggleDone?.call(t),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.isDone ? AppColors.accent : Colors.transparent,
                border: Border.all(
                  color: t.isDone ? AppColors.accent : AppColors.secondaryLabel,
                  width: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onTapTask(t),
              child: Text(
                t.displayTitle,
                style: TextStyle(decoration: TextDecoration.none, 
                  fontSize: 14,
                  color: t.isDone ? AppColors.label : lineColor,
                ),
              ),
            ),
          ),
          if (t.repeatRule != '永不')
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(CupertinoIcons.repeat, size: 12, color: lineColor),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildHourGrid() {
    final widgets = <Widget>[];
    for (int h = 0; h <= 24; h++) {
      final top = h * hourHeight;
      widgets.add(Positioned(
        top: top.toDouble(),
        left: 0,
        right: 0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: timeColWidth,
              child: Transform.translate(
                offset: const Offset(0, -7),
                child: Text(
                  h == 24 ? '' : _hourLabel(h),
                  textAlign: TextAlign.right,
                  style: const TextStyle(decoration: TextDecoration.none, 
                    fontSize: 12,
                    color: AppColors.secondaryLabel,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Container(height: 1, color: AppColors.gridLine),
            ),
          ],
        ),
      ));
    }
    return widgets;
  }

  String _hourLabel(int h) => '${h.toString().padLeft(2, '0')}:00';

  Widget _buildTapLayer() {
    return Positioned.fill(
      left: timeColWidth + 2,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (details) {
          final localY = details.localPosition.dy;
          final hour = (localY / hourHeight).floor().clamp(0, 23);
          final minute =
              ((localY % hourHeight) / hourHeight * 60).floor();
          final base = DateTime.now();
          final start = DateTime(
              base.year, base.month, base.day, hour, minute - minute % 15);
          widget.onTapEmpty(start);
        },
      ),
    );
  }

  Widget _buildBlock(_LayoutItem item) {
    final t = item.task;
    final startMin = t.start.hour * 60 + t.start.minute;
    final endMin = t.end.hour * 60 + t.end.minute;
    final top = startMin / 60.0 * hourHeight;
    final height = ((endMin - startMin) / 60.0 * hourHeight).clamp(18.0, 9999.0);
    final colW = MediaQuery.of(context).size.width - timeColWidth - 4;
    final left = timeColWidth + 2 + colW * (item.column / item.columns);
    final width = (colW / item.columns - 1).clamp(6.0, double.infinity);

    // 基于最新参考图 replica_final.py 像素实测（块 1037×437）：
    // 线左距块左 27px≈2.6%，线宽 13px≈1.25%，线→文字 33px≈3.2%，
    // 线上下留白各约 6%，标题顶距线顶 8px≈1.8%。
    final lineGap = (width * 0.026).clamp(4.0, 16.0);
    final lineW = (width * 0.0125).clamp(2.0, 6.0);
    final lineInset = (height * 0.06).clamp(2.0, 14.0);
    final lineToText = (width * 0.032).clamp(2.0, 8.0);
    final textTopOffset = (height * 0.018).clamp(2.0, 6.0);

    // 字号固定：不随任务框高度变化（用户明确要求）
    const titleSize = 16.0;
    const timeSize = 12.0;
    const circleSize = 5.0;

    return Positioned(
      top: top,
      left: left,
      width: width.clamp(6.0, double.infinity),
      height: height.toDouble(),
      child: PressableScale(
        scaleDown: 0.9,
        onTap: () => widget.onTapTask(t),
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
                        // 备注单独成行；空间不足时隐藏，避免溢出
                        if (t.note.trim().isNotEmpty &&
                            height - 2 * lineInset >=
                                titleSize + timeSize + timeSize + textTopOffset + 10)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              t.note.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(decoration: TextDecoration.none, 
                                fontSize: timeSize,
                                color: AppColors.secondaryLabel,
                              ),
                            ),
                          ),
                        // 固定字号不随块高变化；若空间不足则隐藏时间行，避免溢出
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
                              const SizedBox(width: 4),
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
