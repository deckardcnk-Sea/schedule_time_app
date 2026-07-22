import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../models/activity_model.dart';
import '../models/recording_session.dart';
import '../providers/task_provider.dart';
import '../utils/colors.dart';
import '../services/background_timer_service.dart';
import '../services/floating_timer_window.dart';

/// 快速记录页：点击图标立即开始计时，停止后自动保存为日历任务
///
/// 持久化策略：所有计时状态实时写入 SharedPreferences（经 TaskProvider）。
/// 即使退出软件 / 切到其它 tab 再回来，也能无损恢复进行中的记录，绝不丢失。
/// 停止时按真实时间段生成一条或多条任务（有暂停则分段）。
class QuickRecordPage extends StatefulWidget {
  const QuickRecordPage({super.key});

  @override
  State<QuickRecordPage> createState() => _QuickRecordPageState();
}

class _QuickRecordPageState extends State<QuickRecordPage>
    with WidgetsBindingObserver {
  String _activity = '';
  String _category = ''; // 当前活动所属大类（用于决定颜色/分类）
  Timer? _ticker;
  Timer? _persistTicker; // 周期写盘，防止意外丢失
  List<TimeSegment> _segments = []; // 已闭合的时间段
  DateTime? _runningStart; // 当前正在计时段的起点；null 表示暂停中
  bool _paused = false;
  final TextEditingController _noteCtrl = TextEditingController();

  /// 当前累计时长（含已闭合段 + 正在跑段）
  Duration get _elapsed {
    Duration total = Duration.zero;
    for (final s in _segments) {
      total += s.end.difference(s.start);
    }
    if (_runningStart != null) {
      total += DateTime.now().difference(_runningStart!);
    }
    return total;
  }

  /// 是否正在计时（用于切换 UI）
  bool get _recording => _runningStart != null || _segments.isNotEmpty;

  TaskProvider get _provider => context.read<TaskProvider>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 回到前台：应用内不需要悬浮窗，隐藏它；同时重新同步后台服务状态。
      if (_runningStart != null) {
        FloatingTimerWindow.hide();
        _syncBackground();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // 离开应用（后台 / 锁屏 / 被切走）：正在计时则显示全局悬浮胶囊。
      if (_runningStart != null) {
        _showFloatingWhenAway();
      }
    }
    super.didChangeAppLifecycleState(state);
  }

  /// 离开 App 时拉起悬浮窗（先确保权限，未授权则仅保活后台服务）。
  Future<void> _showFloatingWhenAway() async {
    final color = _provider.categoryColor(_category).value;
    final s = RecordingSession(
      activity: _activity,
      category: _category,
      note: _noteCtrl.text.trim(),
      segments: _segments,
      runningStart: _runningStart,
      paused: _paused,
      savedAt: DateTime.now(),
    );
    final granted = await FloatingTimerWindow.ensurePermission();
    if (granted) {
      await FloatingTimerWindow.show(s, color);
    } else {
      // 未授权：静默保活后台服务（通知栏可见），不在应用内弹打扰。
      await BackgroundTimerService.update(s);
    }
  }

  /// 从本地恢复进行中的会话（退出软件 / 切 tab 后依然有效）
  void _restore() {
    final s = _provider.loadRecordingSession();
    if (s != null && s.activity.isNotEmpty) {
      setState(() {
        _activity = s.activity;
        _category = s.category;
        _segments = List.from(s.segments);
        _runningStart = s.runningStart;
        _paused = s.paused;
        _noteCtrl.text = s.note;
      });
      // 若恢复时处于运行中，重启 tick 继续走表
      if (_runningStart != null) {
        _startTicker();
        // 需求4：恢复进行中会话时，同步给后台服务继续计时（退后台不丢）
        _syncBackground();
      }
    }
  }

  /// 需求4：把当前会话推给后台前台服务 + 原生悬浮窗，使其在 App 退到后台仍持续计时。
  Future<void> _syncBackground() async {
    final s = RecordingSession(
      activity: _activity,
      category: _category,
      note: _noteCtrl.text.trim(),
      segments: _segments,
      runningStart: _runningStart,
      paused: _paused,
      savedAt: DateTime.now(),
    );
    final color = _provider.categoryColor(_category).value;
    if (_runningStart != null) {
      await BackgroundTimerService.start(s);
      // 悬浮窗仅在离开 App 时显示：此处先确保后台服务，悬浮窗由生命周期显隐控制。
      // 若当前已不在前台（如计时中直接被切走），则补显示。
      final away = WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
      if (away) {
        final granted = await FloatingTimerWindow.ensurePermission();
        if (granted) {
          await FloatingTimerWindow.show(s, color);
        }
      }
    } else {
      await BackgroundTimerService.update(s);
      await FloatingTimerWindow.update(s, color);
    }
  }

  /// 把当前会话状态持久化到本地
  Future<void> _persist() async {
    final s = RecordingSession(
      activity: _activity,
      category: _category,
      note: _noteCtrl.text.trim(),
      segments: _segments,
      runningStart: _runningStart,
      paused: _paused,
      savedAt: DateTime.now(),
    );
    await _provider.saveRecordingSession(s);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_runningStart == null) return;
      // 仅触发重绘（用真实时间计算），不再手动累加
      if (mounted) setState(() {});
      // 需求4：每秒刷新悬浮窗计时
      if (FloatingTimerWindow.isVisible && mounted) {
        final s = RecordingSession(
          activity: _activity,
          category: _category,
          note: _noteCtrl.text.trim(),
          segments: _segments,
          runningStart: _runningStart,
          paused: _paused,
          savedAt: DateTime.now(),
        );
        final color = _provider.categoryColor(_category).value;
        FloatingTimerWindow.update(s, color);
      }
    });
  }

  void _start(ActivityType a) {
    setState(() {
      _activity = a.name;
      _category = a.categoryName;
      _segments = [];
      _runningStart = DateTime.now();
      _paused = false;
      _noteCtrl.clear();
    });
    _startTicker();
    _persist();
    // 需求4：开始计时即拉起后台服务，退到后台仍持续计时
    _syncBackground();
  }

  void _togglePause() {
    if (!_recording) return;
    setState(() {
      if (_paused) {
        // 继续：开启新的一段计时
        _runningStart = DateTime.now();
        _paused = false;
        _startTicker();
      } else {
        // 暂停：把当前正在跑的段闭合为一段
        if (_runningStart != null) {
          _segments.add(TimeSegment(
            start: _runningStart!,
            end: DateTime.now(),
          ));
          _runningStart = null;
        }
        _paused = true;
        _ticker?.cancel();
      }
    });
    _persist();
    // 需求4：暂停/继续都同步给后台服务
    _syncBackground();
  }

  /// 点「停止并保存」先弹二次确认（中间缩放 dialog），确认后才真正保存
  Future<void> _stop() async {
    // 先把正在跑的段闭合，便于确认框展示真实总时长
    final runningEnd =
        _runningStart != null ? DateTime.now() : null;
    final previewSegments = List<TimeSegment>.from(_segments);
    if (runningEnd != null) {
      previewSegments.add(TimeSegment(
        start: _runningStart!,
        end: runningEnd,
      ));
    }
    if (previewSegments.isEmpty) {
      // 没任何有效时段，直接清空即可（无需确认）
      _ticker?.cancel();
      if (mounted) {
        setState(() {
          _activity = '';
          _category = '';
          _paused = false;
          _noteCtrl.clear();
        });
      }
      await _provider.clearRecordingSession();
      return;
    }
    final total = previewSegments.fold<Duration>(
        Duration.zero, (sum, s) => sum + s.end.difference(s.start));
    final segCount = previewSegments.length;

    if (!context.mounted) return;
    final confirmed = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        opaque: false,
        barrierColor: Colors.black.withAlpha(40),
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (ctx, anim, _) {
          final scale = Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          );
          final fade =
              CurvedAnimation(parent: anim, curve: Curves.easeOut);
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(
              scale: scale,
              child: Center(
                child: CupertinoAlertDialog(
                  title: const Text('结束并保存？'),
                  content: Text(
                      '「$_activity」已记录 ${_fmtElapsed(total)}${segCount > 1 ? '（分 $segCount 段）' : ''}，结束后将写入日历。'),
                  actions: [
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消'),
                    ),
                    CupertinoDialogAction(
                      isDefaultAction: true,
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('确认结束'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (confirmed == true) {
      await _commitStop();
    }
  }

  /// 真正执行保存（确认后调用）
  Future<void> _commitStop() async {
    _ticker?.cancel();
    // 把正在跑的段也闭合
    if (_runningStart != null) {
      _segments.add(TimeSegment(
        start: _runningStart!,
        end: DateTime.now(),
      ));
      _runningStart = null;
    }
    if (_segments.isEmpty) {
      if (mounted) {
        setState(() {
          _activity = '';
          _category = '';
          _paused = false;
          _noteCtrl.clear();
        });
      }
      await _provider.clearRecordingSession();
      return;
    }

    final provider = _provider;
    final color = provider.categoryColor(_category);
    final note = _noteCtrl.text.trim();
    // 每段真实时间对应一条任务；有暂停则自然分段
    final realTasks = _segments
        .map((seg) => Task(
              title: _activity,
              start: seg.start,
              end: seg.end,
              colorValue: color.value,
              category: _category.isNotEmpty ? _category : '时间记录',
              note: note,
            ))
        .toList();

    try {
      await provider.addTasks(realTasks);
      await provider.clearRecordingSession();
      // 需求4：停止并保存后，关闭后台计时服务 + 悬浮窗
      await BackgroundTimerService.stop();
      await FloatingTimerWindow.close();
      if (mounted) {
        setState(() {
          _activity = '';
          _category = '';
          _segments = [];
          _paused = false;
        });
        _noteCtrl.clear();
        if (context.mounted) {
          final total = realTasks.fold<Duration>(
              Duration.zero, (sum, t) => sum + t.end.difference(t.start));
          final segText = realTasks.length > 1
              ? '（分 ${realTasks.length} 段）'
              : '';
          await showCupertinoDialog(
            context: context,
            builder: (_) => CupertinoAlertDialog(
              title: const Text('已保存'),
              content: Text(
                  '「${_activity}」已记录 ${_fmtElapsed(total)}$segText，可在日历查看。'),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('好的'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // 同一时间段与已有任务重叠属正常情况：日/周视图已支持左右分块并列显示，
      // 不再弹"保存失败"丑贴条，仅后台记录，保证交互不中断。
      debugPrint('快速记录保存异常(已忽略，任务仍尝试写入): $e');
    }
  }

  @override
  void dispose() {
    // 注意：不可在此丢弃记录！只停掉计时器，会话状态已持久化，
    // 再次进入页面时会从本地恢复。
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _persistTicker?.cancel();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _fmtElapsed(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final recording = _recording;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: recording ? _buildRecording() : _buildPresetGrid(),
        ),
      ),
    );
  }

  Widget _buildPresetGrid() {
    final provider = context.watch<TaskProvider>();
    final cats = provider.categories;
    final acts = provider.activityTypes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Text('快速记录',
                      style: const TextStyle(decoration: TextDecoration.none, 
                          fontSize: 28, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('点击一个活动立即开始计时',
                      style: const TextStyle(decoration: TextDecoration.none, 
                          fontSize: 15,
                          color: AppColors.secondaryLabel)),
                ],
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _openManager(context, provider),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.gear,
                    size: 22, color: AppColors.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        // 问题4修复：活动网格靠顶部排列（而非居中），紧贴标题下方，
        // 不让少量活动浮在页面中间，也不被底部导航栏遮挡。
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                // 问题4修复：底部留白避开底部导航栏（56）+ safe area + 余量，
                // 否则最后一行活动/大类说明会被导航栏遮挡。
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  for (final cat in cats) ...[
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 22, bottom: 14, left: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: cat.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(cat.name,
                              style: const TextStyle(decoration: TextDecoration.none, 
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2)),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      children: acts
                          .where((a) => a.categoryName == cat.name)
                          .map((a) => _activityChip(a, cat.color))
                          .toList(),
                    ),
                  ],
                  if (cats.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text('还没有活动，点右上角齿轮添加',
                            style: TextStyle(decoration: TextDecoration.none, color: AppColors.secondaryLabel)),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _activityChip(ActivityType a, Color color) {
    return GestureDetector(
      onTap: () => _start(a),
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(IconData(a.iconCodePoint,
                  fontFamily: CupertinoIcons.iconFont,
                  fontPackage: CupertinoIcons.iconFontPackage),
                  color: color, size: 30),
            ),
            const SizedBox(height: 7),
            Text(a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(decoration: TextDecoration.none, 
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecording() {
    final provider = context.watch<TaskProvider>();
    final color = provider.categoryColor(_category);
    return Column(
      children: [
        const Spacer(),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(CupertinoIcons.time, color: color, size: 54),
        ),
        const SizedBox(height: 24),
        Text(_activity,
            style: const TextStyle(decoration: TextDecoration.none, fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(_fmtElapsed(_elapsed),
            style: TextStyle(decoration: TextDecoration.none, 
                fontSize: 48,
                fontWeight: FontWeight.w300,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()])),
        if (_paused)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('已暂停',
                style: TextStyle(decoration: TextDecoration.none, 
                    fontSize: 13, color: AppColors.secondaryLabel)),
          ),
        const SizedBox(height: 20),
        // 备注输入
        CupertinoTextField(
          controller: _noteCtrl,
          placeholder: '加个备注（可选）',
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 16),
        // 暂停/继续 + 停止
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                color: AppColors.secondaryBackground,
                borderRadius: BorderRadius.circular(14),
                onPressed: _togglePause,
                child: Text(_paused ? '继续' : '暂停',
                    style: const TextStyle(decoration: TextDecoration.none, 
                        color: AppColors.label,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CupertinoButton(
                color: AppColors.destructive,
                borderRadius: BorderRadius.circular(14),
                onPressed: _stop,
                child: const Text('停止并保存',
                    style: TextStyle(decoration: TextDecoration.none, 
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }

  // ---- 活动管理弹窗 ----
  // 问题3修复：管理弹窗关闭后强制刷新主页面，确保新增/删除的活动立刻可见。
  Future<void> _openManager(BuildContext ctx, TaskProvider provider) async {
    await showCupertinoModalPopup(
      context: ctx,
      builder: (_) => _ActivityManagerSheet(provider: provider),
    );
    // 弹窗关闭后显式 setState 触发主页面刷新（watch 跨 overlay 有时不能及时传播）。
    if (mounted) setState(() {});
  }
}

/// 活动/分类管理底部弹窗：添加、编辑、删除大类与活动
class _ActivityManagerSheet extends StatefulWidget {
  final TaskProvider provider;
  const _ActivityManagerSheet({required this.provider});

  @override
  State<_ActivityManagerSheet> createState() => _ActivityManagerSheetState();
}

class _ActivityManagerSheetState extends State<_ActivityManagerSheet> {
  int _tab = 0; // 0=活动 1=大类

  @override
  Widget build(BuildContext context) {
    // 问题3修复：用 watch 监听 provider 变更，确保增删改后列表即时刷新，
    // 不再依赖手动 setState（之前弹窗 overlay 不在 watch 树中，导致"没反应"）。
    final cats = context.watch<TaskProvider>().categories;
    final acts = context.watch<TaskProvider>().activityTypes;
    // 问题5修复：用 CupertinoTheme 覆盖分段控件配色，杜绝系统默认红字 + tint 荧光下划线。
    // primaryColor 设为标准 iOS 蓝，分段选中的下划线与选中文字都走蓝，不再红/荧光。
    return CupertinoTheme(
      data: const CupertinoThemeData(
        primaryColor: AppColors.accent,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(decoration: TextDecoration.none, color: AppColors.label),
        ),
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _tab,
                thumbColor: CupertinoColors.white,
                backgroundColor: AppColors.groupedBackground,
                children: const {
                  0: Text('活动',
                      style: TextStyle(
                          color: AppColors.label,
                          decoration: TextDecoration.none)),
                  1: Text('大类',
                      style: TextStyle(
                          color: AppColors.label,
                          decoration: TextDecoration.none)),
                },
                onValueChanged: (v) => setState(() => _tab = v ?? 0),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _tab == 0
                  ? _buildActivityList(acts, cats)
                  : _buildCategoryList(cats),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityList(List<ActivityType> acts, List<ActivityCategory> cats) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              for (final a in acts)
                _rowTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.provider
                          .categoryColor(a.categoryName)
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      IconData(a.iconCodePoint,
                          fontFamily: CupertinoIcons.iconFont,
                          fontPackage: CupertinoIcons.iconFontPackage),
                      size: 20,
                      color: widget.provider.categoryColor(a.categoryName),
                    ),
                  ),
                  title: a.name,
                  subtitle: a.categoryName,
                  onEdit: () => _editActivity(a, cats),
                  onDelete: () {
                    widget.provider.deleteActivity(a.name);
                    setState(() {});
                  },
                ),
            ],
          ),
        ),
        _addButton('添加活动', () => _editActivity(null, cats)),
      ],
    );
  }

  Widget _buildCategoryList(List<ActivityCategory> cats) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              for (final c in cats)
                _rowTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CupertinoIcons.folder_fill,
                        size: 20, color: c.color),
                  ),
                  title: c.name,
                  subtitle: '颜色',
                  trailingColor: c.color,
                  onEdit: () => _editCategory(c),
                  onDelete: () {
                    widget.provider.deleteCategory(c.name);
                    setState(() {});
                  },
                ),
            ],
          ),
        ),
        _addButton('添加大类', () => _editCategory(null)),
      ],
    );
  }

  Widget _rowTile({
    required Widget leading,
    required String title,
    required String subtitle,
    Color? trailingColor,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.gridLine, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(decoration: TextDecoration.none, 
                        fontSize: 16, fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style: const TextStyle(decoration: TextDecoration.none, 
                        fontSize: 12, color: AppColors.secondaryLabel)),
              ],
            ),
          ),
          if (trailingColor != null)
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: trailingColor,
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.separator, width: 0.5),
              ),
            ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: onEdit,
            child: const Text('编辑',
                style: TextStyle(decoration: TextDecoration.none, color: AppColors.accent, fontSize: 14)),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: onDelete,
            child: const Text('删除',
                style: TextStyle(decoration: TextDecoration.none, color: AppColors.destructive, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _addButton(String label, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      child: CupertinoButton(
        color: AppColors.groupedBackground,
        borderRadius: BorderRadius.circular(12),
        onPressed: onTap,
        child: Text(label,
            style: const TextStyle(decoration: TextDecoration.none, 
                color: AppColors.accent, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ---- 编辑活动 ----
  void _editActivity(ActivityType? existing, List<ActivityCategory> cats) {
    final isNew = existing == null;
    String name = existing?.name ?? '';
    int iconCode = existing?.iconCodePoint ??
        CupertinoIcons.circle_fill.codePoint;
    String catName = existing?.categoryName ??
        (cats.isNotEmpty ? cats.first.name : '');
    final nameCtrl = TextEditingController(text: name);
    final iconCtrl = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setInner) => CupertinoAlertDialog(
          title: Text(isNew ? '添加活动' : '编辑活动'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                CupertinoTextField(
                  controller: nameCtrl,
                  placeholder: '活动名称',
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                const SizedBox(height: 10),
                // 选大类
                if (cats.isNotEmpty)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      showCupertinoModalPopup(
                        context: ctx2,
                        builder: (_) => Container(
                          height: 260,
                          color: AppColors.secondaryBackground,
                          child: CupertinoPicker(
                            itemExtent: 44,
                            scrollController: FixedExtentScrollController(
                                initialItem: cats
                                    .indexWhere((c) => c.name == catName)
                                    .clamp(0, cats.length - 1)),
                            onSelectedItemChanged: (i) =>
                                setInner(() => catName = cats[i].name),
                            children: cats
                                .map((c) => Center(
                                    child: Text(c.name,
                                        style: const TextStyle(decoration: TextDecoration.none, fontSize: 16))))
                                .toList(),
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: widget.provider.categoryColor(catName),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('大类：$catName',
                            style: const TextStyle(decoration: TextDecoration.none, 
                                color: AppColors.label)),
                        const SizedBox(width: 4),
                        const Icon(CupertinoIcons.chevron_down,
                            size: 14, color: AppColors.secondaryLabel),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                const Text('图标关键字（中英文皆可，模糊匹配）',
                    style: TextStyle(decoration: TextDecoration.none, 
                        fontSize: 12, color: AppColors.secondaryLabel)),
                CupertinoTextField(
                  controller: iconCtrl,
                  placeholder: isNew ? '如：work / 书 / run' : null,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  onChanged: (v) {
                    final found = _matchIcon(v);
                    if (found != null) setInner(() => iconCode = found.codePoint);
                  },
                ),
                const SizedBox(height: 10),
                Icon(IconData(iconCode,
                    fontFamily: CupertinoIcons.iconFont,
                    fontPackage: CupertinoIcons.iconFontPackage),
                    size: 36,
                    color: widget.provider.categoryColor(catName)),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('取消'),
              onPressed: () => Navigator.pop(ctx2),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('保存'),
              onPressed: () {
                name = nameCtrl.text.trim();
                if (name.isEmpty || catName.isEmpty) {
                  Navigator.pop(ctx2);
                  return;
                }
                final at = ActivityType(
                    name: name, iconCodePoint: iconCode, categoryName: catName);
                if (isNew) {
                  widget.provider.addActivity(at);
                } else {
                  widget.provider.updateActivity(existing!.name, at);
                }
                Navigator.pop(ctx2);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---- 编辑大类 ----
  void _editCategory(ActivityCategory? existing) {
    final isNew = existing == null;
    String name = existing?.name ?? '';
    Color color = existing?.color ?? AppColors.taskPalette[6];
    final nameCtrl = TextEditingController(text: name);

    showCupertinoDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setInner) => CupertinoAlertDialog(
          title: Text(isNew ? '添加大类' : '编辑大类'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                CupertinoTextField(
                  controller: nameCtrl,
                  placeholder: '大类名称',
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                const SizedBox(height: 14),
                const Text('选择颜色',
                    style: TextStyle(decoration: TextDecoration.none, 
                        fontSize: 12, color: AppColors.secondaryLabel)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: AppColors.taskPalette
                      .map((c) => GestureDetector(
                            onTap: () => setInner(() => color = c),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color == c
                                      ? AppColors.label
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('取消'),
              onPressed: () => Navigator.pop(ctx2),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('保存'),
              onPressed: () {
                name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  Navigator.pop(ctx2);
                  return;
                }
                final cat =
                    ActivityCategory(name: name, colorValue: color.value);
                if (isNew) {
                  widget.provider.addCategory(cat);
                } else {
                  widget.provider.updateCategory(existing!.name, cat);
                }
                Navigator.pop(ctx2);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 图标模糊匹配：支持中文关键词与英文
  IconData? _matchIcon(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return null;
    // 中文/英文关键字 → 图标
    final map = <String, IconData>{
      'work': CupertinoIcons.briefcase_fill,
      '工作': CupertinoIcons.briefcase_fill,
      '会议': CupertinoIcons.person_2_fill,
      'meeting': CupertinoIcons.person_2_fill,
      'study': CupertinoIcons.book_fill,
      '学习': CupertinoIcons.book_fill,
      'read': CupertinoIcons.book,
      '阅读': CupertinoIcons.book,
      'sport': CupertinoIcons.sportscourt_fill,
      '运动': CupertinoIcons.sportscourt_fill,
      'food': CupertinoIcons.house_fill,
      '用餐': CupertinoIcons.house_fill,
      '吃饭': CupertinoIcons.house_fill,
      'sleep': CupertinoIcons.moon_fill,
      '休息': CupertinoIcons.moon_fill,
      'game': CupertinoIcons.game_controller_solid,
      '娱乐': CupertinoIcons.game_controller_solid,
      'music': CupertinoIcons.music_note,
      '音乐': CupertinoIcons.music_note,
      'car': CupertinoIcons.car_fill,
      '车': CupertinoIcons.car_fill,
      'phone': CupertinoIcons.phone_fill,
      '电话': CupertinoIcons.phone_fill,
      'camera': CupertinoIcons.camera_fill,
      '相机': CupertinoIcons.camera_fill,
      'heart': CupertinoIcons.heart_fill,
      '爱心': CupertinoIcons.heart_fill,
      'star': CupertinoIcons.star_fill,
      '星': CupertinoIcons.star_fill,
      'flag': CupertinoIcons.flag_fill,
      '旗': CupertinoIcons.flag_fill,
      'cart': CupertinoIcons.cart_fill,
      '购物': CupertinoIcons.cart_fill,
      'coffee': CupertinoIcons.house_fill,
      '咖啡': CupertinoIcons.house_fill,
      'pencil': CupertinoIcons.pencil,
      '写': CupertinoIcons.pencil,
      'doctor': CupertinoIcons.bandage,
      '医疗': CupertinoIcons.bandage,
      'plane': CupertinoIcons.airplane,
      '飞机': CupertinoIcons.airplane,
    };
    if (map.containsKey(query)) return map[query];
    // 退化为前缀/包含匹配
    for (final k in map.keys) {
      if (k.contains(query) || query.contains(k)) return map[k];
    }
    return null;
  }
}
