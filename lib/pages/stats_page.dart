import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../utils/colors.dart';
import '../widgets/range_picker_sheet.dart';
import '../widgets/donut_chart.dart';
import '../widgets/apple_popover.dart';
import '../widgets/pressable_scale.dart';

/// 统计时间段
enum StatsRange { today, week, month, year }

extension StatsRangeX on StatsRange {
  String get label {
    switch (this) {
      case StatsRange.today:
        return '今日';
      case StatsRange.week:
        return '本周';
      case StatsRange.month:
        return '本月';
      case StatsRange.year:
        return '本年';
    }
  }
}

/// 统计粒度
enum StatsMode { sub, level1, level2 }

extension StatsModeX on StatsMode {
  String get label {
    switch (this) {
      case StatsMode.sub:
        return '小类';
      case StatsMode.level1:
        return '一级';
      case StatsMode.level2:
        return '二级';
    }
  }
}

/// 统计页：时间段内时间分布（甜甜圈图 + 引导线标注），支持三种粒度
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final PageController _pageController = PageController();
  StatsRange _range = StatsRange.today;
  // 自定义时间段（选中后覆盖默认四档展示）
  DateTimeRange? _customRange;
  // 粒度：小类（默认）/ 一级（大类）/ 二级（大类下小类）
  StatsMode _mode = StatsMode.sub;
  // 二级模式下当前选中的大类
  String? _level1Key;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickCustom(BuildContext context) async {
    final range = await showRangePicker(context);
    if (range != null) {
      setState(() => _customRange = range);
    }
  }

  void _showModeMenu(BuildContext context, GlobalKey anchorKey) {
    showApplePopover(
      context: context,
      anchorContext: anchorKey.currentContext!,
      width: 180,
      content: (close) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeItem(context, StatsMode.sub, close, '小类（默认）'),
          _modeItem(context, StatsMode.level1, close, '一级统计（大类）'),
          _modeItem(context, StatsMode.level2, close, '二级统计（先选大类）'),
        ],
      ),
    );
  }

  Widget _modeItem(BuildContext context, StatsMode m, VoidCallback close,
      String title) {
    final selected = _mode == m;
    return PressableScale(
      scaleDown: 0.95,
      onTap: () {
        close();
        if (m == _mode) return;
        setState(() {
          _mode = m;
          _level1Key = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      decoration: TextDecoration.none,
                      fontSize: 15,
                      color: selected ? AppColors.accent : AppColors.label)),
            ),
            if (selected)
              const Icon(CupertinoIcons.check_mark,
                  size: 16, color: AppColors.accent),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();

    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 顶栏：标题(可点切换粒度) + 自定义 + 备份 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatsTitle(
                    mode: _mode,
                    onTap: () => _showModeMenu(context, _titleKey),
                    titleKey: _titleKey,
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _pickCustom(context),
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.calendar,
                                size: 16, color: AppColors.accent),
                            SizedBox(width: 4),
                            Text('自定义',
                                style: TextStyle(
                                    decoration: TextDecoration.none,
                                    fontSize: 15,
                                    color: AppColors.accent)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _exportBackup(context, provider),
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.square_arrow_up,
                                size: 16, color: AppColors.accent),
                            SizedBox(width: 4),
                            Text('备份',
                                style: TextStyle(
                                    decoration: TextDecoration.none,
                                    fontSize: 15,
                                    color: AppColors.accent)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _importBackup(context, provider),
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.square_arrow_down,
                                size: 16, color: AppColors.accent),
                            SizedBox(width: 4),
                            Text('导入',
                                style: TextStyle(
                                    decoration: TextDecoration.none,
                                    fontSize: 15,
                                    color: AppColors.accent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    _customRange != null
                        ? _customRangeTitle(_customRange!)
                        : _rangeTitle(_range),
                    style: const TextStyle(
                        decoration: TextDecoration.none,
                        fontSize: 15,
                        color: AppColors.secondaryLabel),
                  ),
                  if (_customRange != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _customRange = null),
                      child: const Icon(CupertinoIcons.xmark_circle_fill,
                          size: 16, color: AppColors.secondaryLabel),
                    ),
                  ],
                  // 当前粒度提示
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_mode.label,
                        style: const TextStyle(
                            decoration: TextDecoration.none,
                            fontSize: 12,
                            color: AppColors.accent)),
                  ),
                  if (_mode == StatsMode.level2 && _level1Key != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _level1Key = null),
                      child: Text('← 返回大类',
                          style: const TextStyle(
                              decoration: TextDecoration.none,
                              fontSize: 12,
                              color: AppColors.secondaryLabel)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── 分段（自定义时隐藏滑块，仅展示自定义结果）──
            if (_customRange == null) _buildSegmented(),
            if (_customRange == null) const Divider(height: 1),
            // ── 内容区 ──
            Expanded(
              child: _customRange != null
                  ? _StatsRangePage(
                      range: StatsRange.today,
                      from: _customRange!.start,
                      to: _customRange!.end,
                      mode: _mode,
                      level1Key: _level1Key,
                      onPickLevel1: (key) =>
                          setState(() => _level1Key = key),
                    )
                  : PageView(
                      controller: _pageController,
                      physics: const ClampingScrollPhysics(),
                      onPageChanged: (i) =>
                          setState(() => _range = StatsRange.values[i]),
                      children: StatsRange.values
                          .map((r) => _StatsRangePage(
                                range: r,
                                mode: _mode,
                                level1Key: _level1Key,
                                onPickLevel1: (key) =>
                                    setState(() => _level1Key = key),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  final GlobalKey _titleKey = GlobalKey();

  String _customRangeTitle(DateTimeRange r) {
    final f = r.start;
    final t = r.end.subtract(const Duration(days: 1));
    final fmt = (DateTime d) => '${d.year}.${d.month}.${d.day}';
    return '${fmt(f)} ~ ${fmt(t)}';
  }

  /// 与日历页一致：滑块跟随 PageController.page 连续移动，与内容同轨迹滑动。
  Widget _buildSegmented() {
    final index = _range.index;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 2, 20, 10),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.groupedBackground,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _pageController,
            builder: (ctx, _) {
              final p = _pageController.hasClients
                  ? (_pageController.page ?? index.toDouble())
                  : index.toDouble();
              final n = StatsRange.values.length;
              final w = (MediaQuery.of(context).size.width - 40 - 4) / n;
              return Positioned(
                top: 0,
                bottom: 0,
                left: 2 + p * w,
                right: 2 + (n - 1 - p) * w,
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
          Row(
            children: List.generate(StatsRange.values.length, (i) {
              final selected = i == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _range = StatsRange.values[i]);
                    _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                      child: Text(StatsRange.values[i].label,
                          style: TextStyle(
                            decoration: TextDecoration.none,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected
                                ? AppColors.label
                                : AppColors.secondaryLabel,
                          )),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _rangeTitle(StatsRange r) {
    final now = DateTime.now();
    switch (r) {
      case StatsRange.today:
        return '${now.month}月${now.day}日 时间分布';
      case StatsRange.week:
        return '本周（周一至周日）时间分布';
      case StatsRange.month:
        return '${now.month}月 时间分布';
      case StatsRange.year:
        return '${now.year}年 时间分布';
    }
  }

  Future<void> _exportBackup(
      BuildContext context, TaskProvider provider) async {
    final result = await provider.exportBackupUnified();
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: result));
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('备份已复制'),
            content: const Text(
                'JSON 已复制到剪贴板，可粘贴保存到备忘录/文档。'),
            actions: [
              CupertinoDialogAction(
                  child: const Text('好的'),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
        );
      }
    } else {
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('备份已导出'),
            content: Text('文件已保存：\n$result'),
            actions: [
              CupertinoDialogAction(
                  child: const Text('好的'),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
        );
      }
    }
  }

  /// 导入备份：弹窗粘贴 JSON（Web / 移动端通用），
  /// 也支持移动端从剪贴板直接粘贴；调用 importBackupUnified 合并去重导入。
  Future<void> _importBackup(
      BuildContext context, TaskProvider provider) async {
    final controller = TextEditingController();
    String? error;
    await showCupertinoDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setState) => CupertinoAlertDialog(
          title: const Text('导入备份'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () async {
                    final data =
                        await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      controller.text = data!.text!;
                    }
                  },
                  child: const Text('从剪贴板粘贴',
                      style: TextStyle(
                          decoration: TextDecoration.none,
                          fontSize: 13,
                          color: AppColors.accent)),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: controller,
                  maxLines: 6,
                  minLines: 4,
                  decoration: BoxDecoration(
                    color: AppColors.groupedBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  style: const TextStyle(
                      decoration: TextDecoration.none, fontSize: 12),
                  placeholder: '在此粘贴导出的 JSON…',
                ),
                if (error != null) ...[
                  const SizedBox(height: 6),
                  Text(error!,
                      style: const TextStyle(
                          decoration: TextDecoration.none,
                          fontSize: 12,
                          color: AppColors.destructive)),
                ],
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
                child: const Text('取消'),
                onPressed: () => Navigator.pop(dlgCtx)),
            CupertinoDialogAction(
                child: const Text('导入'),
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isEmpty) {
                    setState(() => error = '请先粘贴 JSON 内容');
                    return;
                  }
                  try {
                    final n = await provider.importBackupUnified(text);
                    if (context.mounted) {
                      Navigator.pop(dlgCtx);
                      showCupertinoDialog(
                        context: context,
                        builder: (_) => CupertinoAlertDialog(
                          title: const Text('导入完成'),
                          content: Text('成功导入 $n 条任务'
                              '（重复任务已自动跳过）。'),
                          actions: [
                            CupertinoDialogAction(
                                child: const Text('好的'),
                                onPressed: () => Navigator.pop(context)),
                          ],
                        ),
                      );
                    }
                  } catch (e) {
                    setState(() => error = '解析失败：$e');
                  }
                }),
          ],
        ),
      ),
    );
  }
}

/// 可点击切换粒度的"统计"标题
class _StatsTitle extends StatelessWidget {
  final StatsMode mode;
  final VoidCallback onTap;
  final GlobalKey titleKey;
  const _StatsTitle(
      {required this.mode, required this.onTap, required this.titleKey});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: titleKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          const Text('统计',
              style: TextStyle(
                  decoration: TextDecoration.none,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          const Icon(CupertinoIcons.chevron_down,
              size: 16, color: AppColors.secondaryLabel),
        ],
      ),
    );
  }
}

/// 单个时间段的统计内容页（甜甜圈图 + 引导线标注），供 PageView 复用。
class _StatsRangePage extends StatelessWidget {
  final StatsRange range;
  final DateTime? from;
  final DateTime? to;
  final StatsMode mode;
  final String? level1Key;
  final void Function(String key)? onPickLevel1;

  const _StatsRangePage({
    required this.range,
    this.from,
    this.to,
    required this.mode,
    this.level1Key,
    this.onPickLevel1,
  });

  (DateTime, DateTime) _rangeBounds(StatsRange r) {
    if (from != null && to != null) return (from!, to!);
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    switch (r) {
      case StatsRange.today:
        return (startOfToday, startOfToday.add(const Duration(days: 1)));
      case StatsRange.week:
        final weekday = now.weekday;
        final monday = startOfToday.subtract(Duration(days: weekday - 1));
        return (monday, monday.add(const Duration(days: 7)));
      case StatsRange.month:
        final first = DateTime(now.year, now.month, 1);
        final next = (now.month == 12)
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        return (first, next);
      case StatsRange.year:
        final first = DateTime(now.year, 1, 1);
        return (first, DateTime(now.year + 1, 1, 1));
    }
  }

  String _emptyHint(StatsRange r) {
    if (from != null && to != null) return '该时间段还没有时间记录';
    switch (r) {
      case StatsRange.today:
        return '今天还没有时间记录';
      case StatsRange.week:
        return '本周还没有时间记录';
      case StatsRange.month:
        return '本月还没有时间记录';
      case StatsRange.year:
        return '本年还没有时间记录';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final (from, to) = _rangeBounds(range);

    return FutureBuilder<List<Task>>(
      future: provider.tasksInRange(from, to),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }
        final timed = snap.data!.where((t) => !t.isAllDay).toList();

        // 二级模式：先让用户在半透明遮罩里选大类
        if (mode == StatsMode.level2 && level1Key == null) {
          return _Level1Picker(timed: timed);
        }

        final slices = _buildSlices(timed, mode, level1Key);
        final total = slices.fold(0.0, (a, b) => a + b.minutes);

        if (total == 0) {
          return Center(
            child: Text(_emptyHint(range),
                style: const TextStyle(
                    decoration: TextDecoration.none,
                    color: AppColors.secondaryLabel)),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              DonutChart(
                slices: slices,
                size: 360,
                gap: 0.03,
                onTapSlice: mode == StatsMode.level1
                    ? (i) => onPickLevel1?.call(slices[i].label)
                    : null,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _StatsList(
                  slices: slices,
                  totalMinutes: total,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 聚合逻辑：
  /// - sub：按 title（小类/活动名）聚合
  /// - level1：仅按 category（大类）聚合
  /// - level2：在所选大类下，按 title（小类）聚合
  /// 颜色直接使用任务创建时选定的 colorValue（与日历中活动色一致）。
  List<DonutSlice> _buildSlices(
      List<Task> timed, StatsMode mode, String? level1Key) {
    final Map<String, double> byKey = {};
    final Map<String, int> colorByKey = {};
    for (final t in timed) {
      String key;
      if (mode == StatsMode.level1) {
        key = t.category.isNotEmpty ? t.category : '未分类';
      } else if (mode == StatsMode.level2) {
        if (level1Key != null && (t.category != level1Key)) {
          continue;
        }
        key = t.title.isNotEmpty ? t.title : '未命名';
      } else {
        // sub：小类 = 活动名（直接显示，不带「未分类」前缀）
        key = t.title.isNotEmpty ? t.title : '未命名';
      }
      byKey[key] = (byKey[key] ?? 0) + t.duration.inMinutes;
      // 记录该 key 对应的活动颜色（取首个出现的任务颜色）
      colorByKey.putIfAbsent(key, () => t.colorValue);
    }

    final entries = byKey.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries
        .map((e) => DonutSlice(
              label: e.key,
              minutes: e.value,
              color: colorByKey.containsKey(e.key)
                  ? Color(colorByKey[e.key]!)
                  : AppColors.donutColor(e.key),
            ))
        .toList();
  }
}

/// 二级模式：半透明遮罩 + 居中一级甜甜圈，点块带明显缩放动画进入该大类
class _Level1Picker extends StatefulWidget {
  final List<Task> timed;
  const _Level1Picker({required this.timed});

  @override
  State<_Level1Picker> createState() => _Level1PickerState();
}

class _Level1PickerState extends State<_Level1Picker> {
  String? _tapped;

  List<DonutSlice> _slices() {
    final Map<String, double> byKey = {};
    final colorByKey = <String, int>{};
    for (final t in widget.timed) {
      final k = t.category.isNotEmpty ? t.category : '未分类';
      byKey[k] = (byKey[k] ?? 0) + t.duration.inMinutes;
      colorByKey.putIfAbsent(k, () => t.colorValue);
    }
    final entries = byKey.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map((e) => DonutSlice(
              label: e.key,
              minutes: e.value,
              color: colorByKey.containsKey(e.key)
                  ? Color(colorByKey[e.key]!)
                  : AppColors.donutColor(e.key),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final slices = _slices();
    return Stack(
      children: [
        // 半透明遮罩
        Container(
          color: Colors.black.withValues(alpha: 0.35),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('选择大类',
                  style: TextStyle(
                      decoration: TextDecoration.none,
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              AnimatedScale(
                scale: _tapped != null ? 1.18 : 1.0,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                child: DonutChart(
                  slices: slices,
                  size: 260,
                  gap: 0.035,
                  onTapSlice: (i) {
                    final key = slices[i].label;
                    setState(() => _tapped = key);
                    // 明显缩放后回调
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) _notify(context, key);
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _notify(BuildContext context, String key) {
    // 找到最近的 _StatsRangePage 的 onPickLevel1 回调
    final page = context.findAncestorWidgetOfExactType<_StatsRangePage>();
    if (page is _StatsRangePage && page.onPickLevel1 != null) {
      page.onPickLevel1!(key);
    }
  }
}

/// 下方列表（恢复原来的列表说明，并加上参考图里的彩色进度条）
class _StatsList extends StatelessWidget {
  final List<DonutSlice> slices;
  final double totalMinutes;
  const _StatsList({required this.slices, required this.totalMinutes});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: slices.length,
      itemBuilder: (ctx, i) {
        final s = slices[i];
        final pct = totalMinutes > 0 ? s.minutes / totalMinutes : 0.0;
        final hours = (s.minutes / 60).toStringAsFixed(1);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            decoration: TextDecoration.none,
                            fontSize: 13,
                            color: AppColors.secondaryLabel)),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.label,
                        style: const TextStyle(
                            decoration: TextDecoration.none,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                  ),
                  Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          decoration: TextDecoration.none,
                          fontSize: 14,
                          color: AppColors.secondaryLabel)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 64,
                    child: Text('${hours}h',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            decoration: TextDecoration.none,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // 彩色进度条
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(
                  children: [
                    Container(
                      height: 4,
                      color: AppColors.gridLine,
                    ),
                    FractionallySizedBox(
                      widthFactor: pct.clamp(0.0, 1.0),
                      child: Container(
                        height: 4,
                        color: s.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
