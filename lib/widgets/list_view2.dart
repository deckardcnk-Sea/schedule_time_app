import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../utils/colors.dart';

/// 列表视图：按日期分组，仅列出有事件的日期
class ListView2 extends StatelessWidget {
  final void Function(Task task) onTapTask;
  const ListView2({super.key, required this.onTapTask});

  static const _wk = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final base = provider.selectedDay;
    final from = DateTime(base.year, base.month, 1);
    final to = DateTime(base.year, base.month + 2, 0); // 覆盖约两个月

    return FutureBuilder<List<Task>>(
      future: provider.tasksInRange(from, to),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? const [];
        if (tasks.isEmpty) {
          return const Center(
            child: Text('这段时间没有安排',
                style: TextStyle(decoration: TextDecoration.none, color: AppColors.secondaryLabel)),
          );
        }
        // 按天分组
        final Map<String, List<Task>> grouped = {};
        for (final t in tasks) {
          final key =
              '${t.start.year}-${t.start.month}-${t.start.day}';
          grouped.putIfAbsent(key, () => []).add(t);
        }
        final keys = grouped.keys.toList()
          ..sort((a, b) {
            final da = grouped[a]!.first.start;
            final db = grouped[b]!.first.start;
            return da.compareTo(db);
          });

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: keys.length,
          itemBuilder: (context, i) {
            final dayTasks = grouped[keys[i]]!;
            final d = dayTasks.first.start;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: AppColors.systemBackground,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    '${d.month}月${d.day}日 ${_wk[d.weekday % 7]}',
                    style: const TextStyle(decoration: TextDecoration.none, 
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryLabel),
                  ),
                ),
                ...dayTasks.map((t) => GestureDetector(
                      onTap: () => onTapTask(t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                color: AppColors.gridLine, width: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.lineOf(t.colorValue),
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (t.isReminder)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: Icon(CupertinoIcons.circle,
                                              size: 15,
                                              color: AppColors.secondaryLabel),
                                        ),
                                      Expanded(
                                        child: Text(t.displayTitle,
                                            style: const TextStyle(decoration: TextDecoration.none, 
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    t.isAllDay
                                        ? '全天'
                                        : '${_fmt(t.start)} - ${_fmt(t.end)}',
                                    style: const TextStyle(decoration: TextDecoration.none, 
                                        fontSize: 12,
                                        color: AppColors.secondaryLabel),
                                  ),
                                  if (t.note.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        t.note.trim(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(decoration: TextDecoration.none, 
                                            fontSize: 11,
                                            color: AppColors.secondaryLabel),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (t.isFlagged)
                              const Icon(CupertinoIcons.flag_fill,
                                  size: 14, color: AppColors.destructive),
                          ],
                        ),
                      ),
                    )),
              ],
            );
          },
        );
      },
    );
  }

  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
