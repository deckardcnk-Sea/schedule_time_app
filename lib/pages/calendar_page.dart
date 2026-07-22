import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../utils/colors.dart';
import '../utils/lunar.dart';
import '../pages/reminders_page.dart';
import '../pages/search_page.dart';
import '../widgets/day_timeline_view.dart';
import '../widgets/week_view.dart';
import '../widgets/month_view.dart';
import '../widgets/task_editor_sheet.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/apple_popover.dart';
import '../utils/lists.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadDay(DateTime.now());
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 苹果风格轻提示：基于 Overlay 实现，不依赖 Material 的 ScaffoldMessenger，
  /// 避免在无 Material 的 CupertinoPageScaffold 下调用 showSnackBar 抛异常导致黑屏。
  void _showCupertinoToast(String message) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (ctx) => _ToastWidget(message: message),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 1, milliseconds: 400), () {
      entry.remove();
    });
  }

  Future<void> _openEditor(
      {Task? task, DateTime? start, bool asReminder = false}) async {
    final provider = context.read<TaskProvider>();
    // 返回值可能是：Task（保存）、字符串 'delete'（删除）、null（取消）。
    // 用 Object? 接收，再分别按运行时类型判断，避免 Task? 与 'delete' 的
    // 类型不匹配隐患（之前删除按钮 pop 出字符串，静态类型却标 Task?，
    // 既产生 unrelated_type_equality_checks 警告，也易在重构时踩坑）。
    final result = await showCupertinoModalPopup<Object?>(
      context: context,
      builder: (_) => TaskEditorSheet(
        existing: task,
        defaultStart: start ?? provider.selectedDay,
        asReminder: asReminder,
      ),
    );
    if (result == 'delete') {
      // 删除走源任务 id：编辑重复派生实例时 task 已是 sourceTaskFor 还原后的源，
      // 其 id 是库内真实 id；task 自身可能为 null（从空白新建的删除不会发生，
      // 因为删除按钮只在 isEdit 时出现）。
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

  /// 苹果风格「新建」浮层内容（锚定在 + 按钮旁，带缩放出现）
  Widget _addMenuContent(BuildContext anchorCtx, VoidCallback close) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('新建',
                style: TextStyle(decoration: TextDecoration.none, 
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryLabel)),
          ),
        ),
        _popoverItem('新建事件', CupertinoIcons.calendar, () {
          close(); // 先关闭浮层
          _openEditor();
        }),
        _popoverItem('新建提醒事项', CupertinoIcons.bell, () {
          close(); // 先关闭浮层
          _openEditor(asReminder: true);
        }),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _popoverItem(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.label),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style:
                      const TextStyle(decoration: TextDecoration.none, fontSize: 16, color: AppColors.label)),
            ),
          ],
        ),
      ),
    );
  }

  String _monthTitle(DateTime d) => '${d.year}年${d.month}月';

  void _openTask(Task t) {
    // 重复派生实例指向源任务，编辑一次全系列生效
    final target = context.read<TaskProvider>().sourceTaskFor(t);
    _openEditor(task: target);
  }

  /// 苹果风格「我的列表」浮层内容（锚定在列表按钮旁，带缩放出现）
  Widget _listsMenuContent(BuildContext anchorCtx, VoidCallback close) {
    final lists = AppLists.defaults;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('我的列表',
                style: TextStyle(decoration: TextDecoration.none, 
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryLabel)),
          ),
        ),
        ...lists.map((l) {
          final name = l['name'] as String;
          final color = l['color'] as Color;
          final icon = l['icon'] as IconData;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              close(); // 先关闭浮层
              Navigator.push(
                context,
                CupertinoPageRoute(
                    builder: (_) => RemindersPage(initialList: name)),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(decoration: TextDecoration.none, 
                            fontSize: 16, color: AppColors.label)),
                  ),
                  const Icon(CupertinoIcons.chevron_right,
                      size: 14, color: AppColors.secondaryLabel),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final day = provider.selectedDay;
    final mode = provider.viewMode;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.secondaryBackground,
      child: SafeArea(
      child: Column(
        children: [
          _buildTopBar(provider, day, mode),
          const Divider(height: 1),
          // 独立的"2024年6月"大标题——在表格外面、上方（苹果原设计），
          // 不属于任何视图内部，跨日/周/月统一显示。
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 6, bottom: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_monthTitle(day),
                  style: const TextStyle(decoration: TextDecoration.none, 
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label)),
            ),
          ),
          Expanded(child: _buildBody(provider, mode)),
        ],
      ),
      ),
    );
  }

  Widget _buildTopBar(
      TaskProvider provider, DateTime day, CalendarViewMode mode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: Row(
        children: [
          // 左上图标：日历、提醒事项显示开关、列表、新建
          _iconButton(
            CupertinoIcons.calendar,
            '日历',
            () {
              // 保持当前视图，仅回到日视图起点
            },
          ),
          // 提醒事项显示开关：高亮=在日历中显示提醒事项
          _iconButton(
            CupertinoIcons.bell,
            '提醒事项',
            () {
              provider.toggleShowReminders();
              // 诊断点1修复：原代码用 ScaffoldMessenger.showSnackBar，
              // 但日历页是 CupertinoPageScaffold（无 Material Scaffold），
              // 会抛异常导致黑屏。改为苹果风格轻提示，不依赖 Material。
              _showCupertinoToast(provider.showReminders
                  ? '已在日历中显示提醒事项'
                  : '已隐藏提醒事项');
            },
            active: provider.showReminders,
          ),
          _iconButton(CupertinoIcons.list_bullet, '列表', () {},
              popover: _listsMenuContent),
          _iconButton(CupertinoIcons.add, '新建', () {},
              popover: _addMenuContent),
          const SizedBox(width: 6),
          // 「日 / 周 / 月」分段置于中间：占据图标组与右侧内容之间的
          // 剩余空间并将其水平居中（而非紧贴左侧图标组）
          Expanded(
            child: Center(child: _inlineSegmented(provider)),
          ),
          // 右侧：搜索框 + 今天
          _searchBox(),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => provider.loadDay(DateTime.now()),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('今天',
                  style: TextStyle(decoration: TextDecoration.none, color: AppColors.accent, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, String tooltip, VoidCallback onTap,
      {bool active = false,
      Widget? Function(BuildContext, VoidCallback close)? popover}) {
    return StatefulBuilder(
      builder: (ctx, setState) {
        var pressed = false;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => pressed = true),
          onTapUp: (_) => setState(() => pressed = false),
          onTapCancel: () => setState(() => pressed = false),
          onTap: () {
            if (popover != null) {
              // 苹果式：在按钮旁弹出带缩放动画的浮层。
              // popover content 会收到 close 回调，点击选项时先关闭浮层再执行动作，
              // 避免浮层残留在新页面之上（原代码误用 Navigator.pop 关不掉 overlay）。
              showApplePopover(
                context: context,
                anchorContext: ctx,
                width: 240,
                content: (close) => popover(ctx, close)!,
              );
            } else {
              onTap();
            }
          },
          child: AnimatedScale(
            scale: pressed ? 0.86 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(icon,
                  size: 22,
                  color: active ? AppColors.accent : AppColors.label),
            ),
          ),
        );
      },
    );
  }

  Widget _searchBox() {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, CupertinoPageRoute(builder: (_) => const SearchPage())),
      child: Container(
        width: 120,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.groupedBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(CupertinoIcons.search,
                size: 14, color: AppColors.secondaryLabel),
            SizedBox(width: 4),
            Expanded(
              child: Text('搜索',
                  style: TextStyle(decoration: TextDecoration.none, 
                      fontSize: 13, color: AppColors.secondaryLabel)),
            ),
          ],
        ),
      ),
    );
  }

  /// 窄小、仅由内容撑开的「日 / 周 / 月」分段控件。
  /// 与左上方图标同排，不占满整行；滑块仍连续跟随 PageView 偏移。
  Widget _inlineSegmented(TaskProvider provider) {
    final mode = provider.viewMode;
    const labels = ['日', '周', '月'];
    const modes = [
      CalendarViewMode.day,
      CalendarViewMode.week,
      CalendarViewMode.month,
    ];
    final index = modes.indexOf(mode).clamp(0, modes.length - 1);

    const itemW = 40.0; // 每项自然宽度（px），控件总宽 = itemW * 3 + 内边距
    const pad = 2.0;
    final totalW = itemW * modes.length + pad * 2;

    return LayoutBuilder(
      builder: (ctx, _) {
        return Container(
          width: totalW,
          padding: const EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: AppColors.groupedBackground,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Stack(
            children: [
              // 滑块位置实时跟随 PageView 滚动偏移(连续值 0.0~3.0)，
              // 与页面在同一轨迹上连续滑动，而非离散跳变。
              AnimatedBuilder(
                animation: _pageController,
                builder: (_, __) {
                  final p = _pageController.page ?? index.toDouble();
                  return Positioned(
                    top: 0,
                    bottom: 0,
                    left: pad + p * itemW,
                    right: pad + (modes.length - 1 - p) * itemW,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 3,
                              offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // 文字层
              Row(
                children: List.generate(modes.length, (i) {
                  final selected = i == index;
                  return SizedBox(
                    width: itemW,
                    child: GestureDetector(
                      onTap: () {
                        provider.setViewMode(modes[i]);
                        _pageController.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Center(
                          child: Text(labels[i],
                              style: TextStyle(decoration: TextDecoration.none, 
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: selected
                                      ? AppColors.label
                                      : AppColors.secondaryLabel)),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(TaskProvider provider, CalendarViewMode mode) {
    const modes = [
      CalendarViewMode.day,
      CalendarViewMode.week,
      CalendarViewMode.month,
    ];
    // 用 PageView 实现真实横向整页滑动：天然连续推挤、且不会被任何父层裁剪。
    // 分段控件点击 / 月视图内跳转 都驱动 _pageController.animateToPage；
    // 用户手动左右滑则通过 onPageChanged 回写 provider.viewMode 让滑块同步。
    return PageView(
      controller: _pageController,
      physics: const ClampingScrollPhysics(),
      onPageChanged: (i) => provider.setViewMode(modes[i]),
      children: [
        DayTimelineView(
          tasks: provider.tasks,
          onTapTask: _openTask,
          onTapEmpty: (s) => _openEditor(start: s),
          onToggleDone: (t) => provider.toggleDone(t),
        ),
        WeekView(
          onTapTask: _openTask,
          onTapEmpty: (s) => _openEditor(start: s),
          onAddAllDay: (d) =>
              _openEditor(start: d, asReminder: true),
        ),
        MonthView(onTapDay: (d) {
          provider.loadDay(d);
          provider.setViewMode(CalendarViewMode.day);
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
          );
        }),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 轻提示气泡：居中偏下，淡入淡出。纯 Cupertino 配色，不依赖 Material。
class _ToastWidget extends StatefulWidget {
  final String message;
  const _ToastWidget({required this.message});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // 下一帧淡入
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 100,
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: _visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.message,
                style: const TextStyle(decoration: TextDecoration.none, color: CupertinoColors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
