import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../utils/colors.dart';
import '../utils/lunar.dart';

/// 苹果风格月视图：整月网格 + 每日农历 + 事件彩色短条
class MonthView extends StatelessWidget {
  final void Function(DateTime day) onTapDay;
  const MonthView({super.key, required this.onTapDay});

  static const _weekHeaders = ['日', '一', '二', '三', '四', '五', '六'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final month = provider.selectedDay;
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final firstWeekday = firstOfMonth.weekday % 7; // 周日=0
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = ((firstWeekday + daysInMonth) / 7).ceil() * 7;
    final today = DateTime.now();

    return Column(
      children: [
        // 星期表头
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: _weekHeaders
                .map((w) => Expanded(
                      child: Center(
                        child: Text(w,
                            style: const TextStyle(decoration: TextDecoration.none, 
                                fontSize: 12,
                                color: AppColors.secondaryLabel)),
                      ),
                    ))
                .toList(),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.62,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              final dayNum = index - firstWeekday + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox();
              }
              final date = DateTime(month.year, month.month, dayNum);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected = date.day == provider.selectedDay.day;
              final all = provider.allTasks;
              final dayTasks = all.where((t) {
                final s = DateTime(date.year, date.month, date.day);
                final e = s.add(const Duration(days: 1));
                return t.start.isBefore(e) && t.end.isAfter(s) ||
                    (t.isAllDay && t.start.year == date.year &&
                        t.start.month == date.month && t.start.day == date.day);
              }).toList()
                ..sort((a, b) => a.start.compareTo(b.start));

              return GestureDetector(
                onTap: () => onTapDay(date),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.gridLine, width: 0.5),
                    ),
                  ),
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.destructive
                              : (isSelected
                                  ? AppColors.label.withValues(alpha: 0.08)
                                  : null),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$dayNum',
                          style: TextStyle(decoration: TextDecoration.none, 
                            fontSize: 14,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? Colors.white : AppColors.label,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        LunarUtil.lunarDayString(date),
                        style: TextStyle(decoration: TextDecoration.none, 
                          fontSize: 8,
                          color: isToday ? AppColors.destructive : AppColors.secondaryLabel,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // 事件/提醒彩色条（最多 3 条）：前面可点击圆圈，整条变灰无划线
                      ...dayTasks.take(3).map((t) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 0.5),
                            child: Row(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => provider.toggleDone(t),
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: t.isDone
                                          ? AppColors.accent
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: t.isDone
                                            ? AppColors.accent
                                            : AppColors
                                                .secondaryLabel,
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(t.displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(decoration: TextDecoration.none, 
                                          fontSize: 8,
                                          color: t.isDone
                                              ? AppColors.label
                                              : AppColors.lineOf(t.colorValue))),
                                ),
                              ],
                            ),
                          )),
                      if (dayTasks.length > 3)
                        Text('+${dayTasks.length - 3}',
                            style: const TextStyle(decoration: TextDecoration.none, 
                                fontSize: 8,
                                color: AppColors.secondaryLabel)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
