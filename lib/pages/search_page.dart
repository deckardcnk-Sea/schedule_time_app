import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../utils/colors.dart';
import '../widgets/task_editor_sheet.dart';

/// 搜索页面：按标题搜索任务/事件/提醒事项
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final all = provider.allTasks; // 所有任务
    final q = _query.toLowerCase();
    final results = q.isEmpty
        ? <Task>[]
        : all
            .where((t) => t.title.toLowerCase().contains(q))
            .toList();

    return CupertinoPageScaffold(
      backgroundColor: AppColors.secondaryBackground,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
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
                    child: CupertinoTextField(
                      controller: _ctrl,
                      autofocus: true,
                      placeholder: '搜索事件、提醒事项...',
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.groupedBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text('无结果',
                          style:
                              TextStyle(decoration: TextDecoration.none, color: AppColors.secondaryLabel)))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (ctx, i) {
                        final t = results[i];
                        return ListTile(
                          leading: Icon(
                            t.isReminder
                                ? CupertinoIcons.circle
                                : CupertinoIcons.calendar,
                            color: AppColors.lineOf(t.colorValue),
                          ),
                          title: Text(t.title),
                          subtitle: Text(
                              '${t.start.month}月${t.start.day}日 ${t.start.hour.toString().padLeft(2, '0')}:${t.start.minute.toString().padLeft(2, '0')}'),
                          onTap: () => _openEditor(context, t),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, Task t) async {
    final provider = context.read<TaskProvider>();
    final target = provider.sourceTaskFor(t); // 重复实例指向源任务
    // 返回值：Task（保存）/ 'delete'（删除）/ null（取消），用 Object? 接收。
    final result = await showCupertinoModalPopup<Object?>(
      context: context,
      builder: (_) => TaskEditorSheet(
        existing: target,
        defaultStart: target.start,
        asReminder: target.isReminder,
      ),
    );
    if (result == 'delete') {
      // 关键修复：删除必须用源任务 target 的 id（result 也是源任务），
      // 不能用原始 t.id——若 t 是重复派生实例，t.id 是临时 id，删不掉/删错。
      if (target.id != null) {
        await provider.deleteTask(target.id!);
      }
    } else if (result is Task) {
      await provider.updateTask(result);
    }
  }
}
