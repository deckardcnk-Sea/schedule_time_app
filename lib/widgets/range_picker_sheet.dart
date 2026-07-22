import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/colors.dart';

/// 统计自定义时间段选择器。
/// 返回选中的 [DateTimeRange]（from 含，to 不含）。
/// 交互设计：先选后确定——点选仅高亮，底部「确定」才返回结果。
/// - 日：月历点选某天（参考图2：左右箭头+年月+星期行+7列网格）
/// - 周：月历点选某天，按该天所在周一~下周一
/// - 月：左右分栏选年+月（参考图3）
/// - 年：单列年份列表
class RangePickerSheet extends StatefulWidget {
  const RangePickerSheet({super.key});

  @override
  State<RangePickerSheet> createState() => _RangePickerSheetState();
}

class _RangePickerSheetState extends State<RangePickerSheet> {
  int _type = 0; // 0=日 1=周 2=月 3=年
  late DateTime _focus; // 当前浏览的年月（日/周/月用）

  // 选中态（先选后确定）
  DateTime? _selectedDay; // 日/周
  int? _selectedMonth; // 月
  int? _selectedYear; // 年

  @override
  void initState() {
    super.initState();
    _focus = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  static const _types = ['日', '周', '月', '年'];
  static const _weekHead = ['日', '一', '二', '三', '四', '五', '六'];

  DateTime _startOfWeek(DateTime d) {
    final wd = d.weekday; // 1=周一
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: wd - 1));
  }

  void _confirm() {
    DateTimeRange? range;
    switch (_type) {
      case 0:
        if (_selectedDay != null) {
          final start = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
          range = DateTimeRange(start: start, end: start.add(const Duration(days: 1)));
        }
      case 1:
        if (_selectedDay != null) {
          final start = _startOfWeek(_selectedDay!);
          range = DateTimeRange(start: start, end: start.add(const Duration(days: 7)));
        }
      case 2:
        if (_selectedMonth != null) {
          final m = _selectedMonth!;
          final start = DateTime(_focus.year, m, 1);
          final end = (m == 12) ? DateTime(_focus.year + 1, 1, 1) : DateTime(_focus.year, m + 1, 1);
          range = DateTimeRange(start: start, end: end);
        }
      case 3:
        if (_selectedYear != null) {
          final start = DateTime(_selectedYear!, 1, 1);
          final end = DateTime(_selectedYear! + 1, 1, 1);
          range = DateTimeRange(start: start, end: end);
        }
    }
    if (range != null) Navigator.pop(context, range);
  }

  void _switchType(int t) {
    setState(() {
      _type = t;
      _selectedDay = null;
      _selectedMonth = null;
      _selectedYear = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: const CupertinoThemeData(
        primaryColor: AppColors.accent,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(color: AppColors.label, decoration: TextDecoration.none),
        ),
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: const BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildSegmented(),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmented() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: _type,
        thumbColor: CupertinoColors.white,
        backgroundColor: AppColors.groupedBackground,
        children: {
          for (int i = 0; i < _types.length; i++)
            i: Text(_types[i], style: const TextStyle(decoration: TextDecoration.none, color: AppColors.label)),
        },
        onValueChanged: (v) => _switchType(v ?? 0),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border(top: BorderSide(color: AppColors.separator.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(decoration: TextDecoration.none, color: AppColors.secondaryLabel, fontSize: 16)),
          ),
          const Spacer(),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: _confirm,
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(23),
                ),
                alignment: Alignment.center,
                child: const Text('确定', style: TextStyle(decoration: TextDecoration.none, color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_type) {
      case 0:
        return _buildDayPicker();
      case 1:
        return _buildWeekPicker();
      case 2:
        return _buildMonthPicker();
      case 3:
        return _buildYearPicker();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDayPicker() => _buildCalendar(isWeek: false);
  Widget _buildWeekPicker() => _buildCalendar(isWeek: true);

  // 月历网格（日/周共用），参考图2
  Widget _buildCalendar({required bool isWeek}) {
    final now = DateTime.now();
    final daysInMonth = DateTime(_focus.year, _focus.month + 1, 0).day;
    final firstWeekday = DateTime(_focus.year, _focus.month, 1).weekday; // 1=周一
    final leading = firstWeekday % 7; // 周日开头
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;

    final rows = <Widget>[
      Row(
        children: _weekHead
            .map((w) => Expanded(
                  child: Center(
                    child: Text(w, style: const TextStyle(decoration: TextDecoration.none, fontSize: 13, color: AppColors.secondaryLabel)),
                  ),
                ))
            .toList(),
      ),
      const SizedBox(height: 6),
    ];

    var day = 1;
    for (var week = 0; week < totalCells / 7; week++) {
      final weekCells = <Widget>[];
      for (var col = 0; col < 7; col++) {
        final idx = week * 7 + col;
        if (idx < leading || day > daysInMonth) {
          weekCells.add(const Expanded(child: SizedBox(height: 42)));
          continue;
        }
        final d = DateTime(_focus.year, _focus.month, day);
        final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
        final selected = isWeek
            ? (_selectedDay != null && _startOfWeek(_selectedDay!) == _startOfWeek(d))
            : (_selectedDay != null && _selectedDay!.year == d.year && _selectedDay!.month == d.month && _selectedDay!.day == d.day);
        weekCells.add(Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedDay = d),
            child: Container(
              height: 42,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : (isToday ? AppColors.accent.withValues(alpha: 0.15) : null),
                borderRadius: BorderRadius.circular(21),
              ),
              alignment: Alignment.center,
              child: Text('$day',
                  style: TextStyle(decoration: TextDecoration.none, 
                      fontSize: 15,
                      color: selected ? Colors.white : (isToday ? AppColors.accent : AppColors.label))),
            ),
          ),
        ));
        day++;
      }
      rows.add(Row(children: weekCells));
    }

    return Column(
      children: [
        _MonthHeader(
          year: _focus.year,
          month: _focus.month,
          onPrev: () => setState(() => _focus = DateTime(_focus.year, _focus.month - 1, 1)),
          onNext: () => setState(() => _focus = DateTime(_focus.year, _focus.month + 1, 1)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: rows),
        ),
      ],
    );
  }

  // 月选择：参考图3，左侧年份 + 右侧月份
  Widget _buildMonthPicker() {
    final now = DateTime.now();
    final startYear = now.year - 3;
    final years = List.generate(7, (i) => startYear + i);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Text('${_focus.year}年${_focus.month}月',
              style: const TextStyle(decoration: TextDecoration.none, fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.label)),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: years.length,
                  itemBuilder: (ctx, idx) {
                    final y = years[idx];
                    final selected = _focus.year == y;
                    return GestureDetector(
                      onTap: () => setState(() => _focus = DateTime(y, _focus.month, 1)),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        color: selected ? AppColors.accent : Colors.transparent,
                        child: Text('$y年',
                            style: TextStyle(decoration: TextDecoration.none, 
                                fontSize: 16,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                color: selected ? Colors.white : AppColors.label)),
                      ),
                    );
                  },
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: 12,
                  itemBuilder: (ctx, idx) {
                    final m = idx + 1;
                    final selected = _selectedMonth == m;
                    final isCur = m == now.month && _focus.year == now.year;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedMonth = m),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        color: selected ? AppColors.accent : Colors.transparent,
                        child: Text('$m月',
                            style: TextStyle(decoration: TextDecoration.none, 
                                fontSize: 16,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                color: selected
                                    ? Colors.white
                                    : (isCur ? AppColors.accent : AppColors.label))),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 年选择：单列年份列表
  Widget _buildYearPicker() {
    final now = DateTime.now();
    final startYear = now.year - 10;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Text('选择年份',
              style: const TextStyle(decoration: TextDecoration.none, fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.label)),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        Expanded(
          child: ListView.builder(
            itemCount: 21,
            itemBuilder: (ctx, idx) {
              final y = startYear + idx;
              final selected = _selectedYear == y;
              final isCur = y == now.year;
              return GestureDetector(
                onTap: () => setState(() => _selectedYear = y),
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 3),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : (isCur ? AppColors.accent.withValues(alpha: 0.12) : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text('$y 年',
                      style: TextStyle(decoration: TextDecoration.none, 
                          fontSize: 17,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          color: selected ? Colors.white : (isCur ? AppColors.accent : AppColors.label))),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 月视图顶部：左右箭头 + 年-月标题（黑色，无荧光）
class _MonthHeader extends StatelessWidget {
  final int year;
  final int month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthHeader({required this.year, required this.month, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onPrev,
            child: const Icon(CupertinoIcons.chevron_left, size: 22, color: AppColors.label),
          ),
          Text('$year年$month月',
              style: const TextStyle(decoration: TextDecoration.none, fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.label)),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onNext,
            child: const Icon(CupertinoIcons.chevron_right, size: 22, color: AppColors.label),
          ),
        ],
      ),
    );
  }
}

Future<DateTimeRange?> showRangePicker(BuildContext context) {
  return showCupertinoModalPopup<DateTimeRange?>(
    context: context,
    builder: (_) => const RangePickerSheet(),
  );
}
