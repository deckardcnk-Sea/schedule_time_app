import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../utils/colors.dart';
import '../utils/lunar.dart';

/// 年视图：12 个月的小月历网格，展示全年概览
class YearView extends StatelessWidget {
  final DateTime selectedDay;
  final void Function(DateTime month) onTapMonth;

  const YearView({
    super.key,
    required this.selectedDay,
    required this.onTapMonth,
  });

  static const _weekdayLabels = ['日', '一', '二', '三', '四', '五', '六'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final year = selectedDay.year;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        for (int row = 0; row < 4; row++) ...[
          Row(
            children: List.generate(3, (col) {
              final month = row * 3 + col + 1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _MiniMonth(
                    year: year,
                    month: month,
                    selectedDay: selectedDay,
                    onTapDay: (d) {
                      provider.loadDay(d);
                      onTapMonth(d);
                    },
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _MiniMonth extends StatelessWidget {
  final int year;
  final int month;
  final DateTime selectedDay;
  final void Function(DateTime) onTapDay;

  const _MiniMonth({
    required this.year,
    required this.month,
    required this.selectedDay,
    required this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDay = DateTime(year, month, 1);
    final startWeekday = firstDay.weekday % 7; // 0=Sunday

    return GestureDetector(
      onTap: () => onTapDay(DateTime(year, month, 1)),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('$month月',
                style: const TextStyle(decoration: TextDecoration.none, 
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            // 星期头
            Row(
              children: ['日', '一', '二', '三', '四', '五', '六']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: const TextStyle(decoration: TextDecoration.none, 
                                  fontSize: 9,
                                  color: AppColors.secondaryLabel)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            // 日期网格
            ...List.generate(6, (week) {
              return Row(
                children: List.generate(7, (day) {
                  final dateOffset = week * 7 + day - startWeekday;
                  if (dateOffset < 0 || dateOffset >= daysInMonth) {
                    return const Expanded(child: SizedBox(height: 22));
                  }
                  final d = DateTime(year, month, dateOffset + 1);
                  final isSelected = _isSameDay(d, selectedDay);
                  final isToday = _isSameDay(d, DateTime.now());
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTapDay(d),
                      child: Container(
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accent
                              : (isToday
                                  ? AppColors.destructive.withValues(alpha: 0.15)
                                  : null),
                          shape: BoxShape.circle,
                        ),
                        child: Text('${d.day}',
                            style: TextStyle(decoration: TextDecoration.none, 
                                fontSize: 10,
                                fontWeight: isSelected || isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : (isToday
                                        ? AppColors.destructive
                                        : AppColors.label))),
                      ),
                    ),
                  );
                }),
              );
            }),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
