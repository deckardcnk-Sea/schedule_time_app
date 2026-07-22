import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../utils/colors.dart';
import '../utils/lists.dart';
import '../widgets/task_editor_sheet.dart';
import '../widgets/pressable_scale.dart';

/// 提醒事项/列表视图：左侧列表分类，右侧任务，顶部筛选
class RemindersPage extends StatefulWidget {
  final String? initialList;
  const RemindersPage({super.key, this.initialList});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  bool _initialApplied = false;

  static const List<(ListFilter, String)> _filters = [
    (ListFilter.today, '今天'),
    (ListFilter.planned, '计划'),
    (ListFilter.all, '全部'),
    (ListFilter.flagged, '旗标'),
    (ListFilter.completed, '完成'),
    (ListFilter.assignedToMe, '分配给我'),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    // 从日历"我的列表"抽屉进入时，预设选中列表（仅首次，且当前不是该列表才设）
    if (!_initialApplied && widget.initialList != null && provider.selectedList != widget.initialList) {
      _initialApplied = true;
      final target = widget.initialList!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          provider.setSelectedList(target);
        }
      });
    }
    final tasks = provider.filteredListTasks();

    // 杀灭"计划"等列表项/筛选可能继承到的荧光下划线：用 CupertinoTheme 兜底，
    // primaryColor 设标准蓝，文字样式统一无 decoration（无下划线/删除线）。
    return CupertinoTheme(
      data: const CupertinoThemeData(
        primaryColor: AppColors.accent,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(color: AppColors.label, decoration: TextDecoration.none),
          actionTextStyle: TextStyle(color: AppColors.label, decoration: TextDecoration.none),
          tabLabelTextStyle: TextStyle(color: AppColors.label, decoration: TextDecoration.none),
        ),
      ),
      child: CupertinoPageScaffold(
      backgroundColor: AppColors.secondaryBackground,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, provider),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  // 左侧列表分类
                  SizedBox(
                    width: 130,
                    child: _buildListSidebar(context, provider),
                  ),
                  const VerticalDivider(width: 1),
                  // 右侧任务列表
                  Expanded(
                    child: _buildTaskList(context, provider, tasks),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildHeader(BuildContext context, TaskProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: const Icon(CupertinoIcons.chevron_back, size: 26),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(provider.selectedList,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.label,
                    decoration: TextDecoration.none,
                    backgroundColor: Colors.transparent)),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openEditor(context, provider),
            child: const Icon(CupertinoIcons.add, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildListSidebar(BuildContext context, TaskProvider provider) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: AppLists.defaults.map((l) {
        final name = l['name'] as String;
        final color = l['color'] as Color;
        final icon = l['icon'] as IconData;
        final selected = provider.selectedList == name;
        return PressableScale(
          scaleDown: 0.9,
          onTap: () => provider.setSelectedList(name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.15) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 260),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: selected ? color : AppColors.label,
                        decoration: TextDecoration.none,
                        backgroundColor: Colors.transparent),
                    child: Text(name),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTaskList(
      BuildContext context, TaskProvider provider, List<Task> tasks) {
    return Column(
      children: [
        // 顶部筛选
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final (filter, label) = _filters[i];
              final selected = provider.listFilter == filter;
              return GestureDetector(
                onTap: () => provider.setListFilter(filter),
                child: Container(
                  color: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color: AppColors.label,
                        decoration: TextDecoration.none,
                        backgroundColor: Colors.transparent,
                      )),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: tasks.isEmpty
              ? const Center(
                  child: Text('没有符合条件的提醒事项',
                      style: TextStyle(decoration: TextDecoration.none, color: AppColors.secondaryLabel)))
              : ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) {
                    final t = tasks[i];
                    return _taskTile(context, provider, t);
                  },
                ),
        ),
      ],
    );
  }

  Widget _taskTile(BuildContext context, TaskProvider provider, Task t) {
    final color = AppLists.colorOf(t.listName);
    return PressableScale(
      scaleDown: 0.9,
      onTap: () => _openEditor(context, provider, task: t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.gridLine, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => provider.toggleDone(t),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.isDone ? AppColors.accent : Colors.transparent,
                  border: Border.all(
                    color: t.isDone ? AppColors.accent : AppColors.secondaryLabel,
                    width: 1.6,
                  ),
                ),
                child: t.isDone
                    ? const Icon(CupertinoIcons.check_mark,
                        size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 260),
                    style: TextStyle(
                      fontSize: 15,
                      // 诊断点1修复：已完成项走灰字（苹果提醒事项的完成态），
                      // 同时加删除线区分"未完成"与"已完成"。
                      color: t.isDone
                          ? AppColors.secondaryLabel
                          : AppColors.label,
                      decoration: t.isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      backgroundColor: Colors.transparent,
                    ),
                    child: Text(t.title),
                  ),
                  if (t.listName.isNotEmpty)
                    Text(t.listName,
                        style: TextStyle(decoration: TextDecoration.none, fontSize: 11, color: color)),
                  if (t.note.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(t.note.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(decoration: TextDecoration.none, 
                              fontSize: 11, color: AppColors.secondaryLabel)),
                    ),
                ],
              ),
            ),
            if (t.isFlagged)
              const Icon(CupertinoIcons.flag_fill,
                  size: 16, color: AppColors.destructive),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, TaskProvider provider,
      {Task? task}) async {
    // 返回值：Task（保存）/ 'delete'（删除）/ null（取消），用 Object? 接收。
    final result = await showCupertinoModalPopup<Object?>(
      context: context,
      builder: (_) => TaskEditorSheet(
        existing: task,
        defaultStart: task?.start ?? provider.selectedDay,
        asReminder: true,
      ),
    );
    if (result == 'delete') {
      if (task?.id != null) {
        await provider.deleteTask(task!.id!);
      }
    } else if (result is Task) {
      if (task == null) {
        await provider.addTask(result);
      } else {
        await provider.updateTask(result);
      }
    }
  }
}
