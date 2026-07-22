import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../utils/colors.dart';
import '../utils/lists.dart';

/// 新建 / 编辑任务弹窗（苹果风格大圆角底部浮层）
class TaskEditorSheet extends StatefulWidget {
  final Task? existing;
  final DateTime defaultStart;
  final bool asReminder;

  const TaskEditorSheet({
    super.key,
    this.existing,
    required this.defaultStart,
    this.asReminder = false,
  });

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _noteCtrl;
  late DateTime _start;
  late DateTime _end;
  late int _colorValue;
  bool _isAllDay = false;
  bool _autoColor = true;
  late bool _isReminder;
  bool _isFlagged = false;
  String _listName = '';
  String _category = '工作';
  String _repeatRule = '永不';
  String _reminderOffset = '无';
  final TextEditingController _inviteeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _start = e?.start ?? widget.defaultStart;
    _end = e?.end ?? widget.defaultStart.add(const Duration(hours: 1));
    _isAllDay = e?.isAllDay ?? false;
    _isReminder = e?.isReminder ?? widget.asReminder;
    _isFlagged = e?.isFlagged ?? false;
    _listName = e?.listName ?? (_isReminder ? '今天' : '');
    _category = e?.category.isNotEmpty ?? false ? e!.category : '工作';
    _repeatRule = e?.repeatRule.isNotEmpty ?? false ? e!.repeatRule : '永不';
    _reminderOffset =
        e?.reminderOffset.isNotEmpty ?? false ? e!.reminderOffset : '无';
    if (e != null) {
      _colorValue = e.colorValue;
      _autoColor = false;
    } else {
      _colorValue = AppColors.taskPalette[6].value;
    }
    _titleCtrl.addListener(() {
      if (_autoColor) {
        setState(() =>
            _colorValue = AppColors.autoColor(_titleCtrl.text).value);
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _inviteeCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) {
      // 标题为空：不静默跳过（那会让用户以为"点完成没反应"），
      // 给出明确提示并留在编辑页。
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('请填写标题'),
          content: const Text('事件或提醒事项需要一个标题。'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('好的'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }
    final task = (widget.existing ??
            Task(
              title: '',
              start: _start,
              end: _end,
              colorValue: _colorValue,
            ))
        .copyWith(
      title: _titleCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
      start: _start,
      end: _isAllDay ? _start : _end,
      colorValue: _colorValue,
      isAllDay: _isAllDay,
      isReminder: _isReminder,
      isFlagged: _isFlagged,
      listName: _listName,
      category: _category,
      repeatRule: _repeatRule,
      reminderOffset: _reminderOffset,
    );
    Navigator.pop(context, task);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    // 问题5修复：用 CupertinoTheme 包裹整个编辑器，强制：
    // - primaryColor = 黑（压掉 Cupertino 控件默认蓝/红 accent tint 和选中下划线）
    // - textTheme 全黑字 + 无 decoration（消灭荧光下划线/删除线）
    return CupertinoTheme(
      data: const CupertinoThemeData(
        primaryColor: AppColors.label,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            color: AppColors.label,
            decoration: TextDecoration.none,
          ),
          actionTextStyle: TextStyle(
            color: AppColors.label,
            decoration: TextDecoration.none,
          ),
          pickerTextStyle: TextStyle(
            color: AppColors.label,
            fontSize: 16,
            decoration: TextDecoration.none,
          ),
        ),
      ),
      child: TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (ctx, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 44),
          child: child,
        ),
      ),
      child: Container(
      decoration: const BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部拖动条
                Container(
                  width: 36,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryLabel,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // 顶栏：取消 / 标题 / 完成
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消',
                          style: TextStyle(color: AppColors.accent, decoration: TextDecoration.none)),
                    ),
                    Text(
                        isEdit
                            ? (_isReminder ? '编辑提醒' : '编辑事件')
                            : (_isReminder ? '新建提醒事项' : '新建事件'),
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.label, decoration: TextDecoration.none)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _save,
                      child: const Text('完成',
                          style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 标题
                _card(
                  child: CupertinoTextField(
                    controller: _titleCtrl,
                    placeholder: '标题',
                    decoration: const BoxDecoration(),
                    style: const TextStyle(fontSize: 17, decoration: TextDecoration.none),
                    autofocus: !isEdit,
                  ),
                ),
                const SizedBox(height: 12),
                // 备注（紧跟标题，直接插入；与记录模块共用同一 note 字段，编辑后日历/记录同步显示）
                _card(
                  child: CupertinoTextField(
                    controller: _noteCtrl,
                    placeholder: '添加备注…（与记录模块同步显示）',
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    decoration: const BoxDecoration(),
                    style: const TextStyle(fontSize: 15, decoration: TextDecoration.none),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
                const SizedBox(height: 12),
                // 全天开关
                _card(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('全天', style: TextStyle(fontSize: 16, color: AppColors.label, decoration: TextDecoration.none)),
                          CupertinoSwitch(
                            value: _isAllDay,
                            onChanged: (v) => setState(() => _isAllDay = v),
                          ),
                        ],
                      ),
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              // 问题5：旗标图标改灰（非红），与"黑字灰字无荧光线"逻辑一致
                              Icon(CupertinoIcons.flag_fill,
                                  size: 16, color: AppColors.secondaryLabel),
                              SizedBox(width: 6),
                              Text('旗标', style: TextStyle(fontSize: 16, color: AppColors.label, decoration: TextDecoration.none)),
                            ],
                          ),
                          CupertinoSwitch(
                            value: _isFlagged,
                            onChanged: (v) => setState(() => _isFlagged = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 时间选择
                if (!_isAllDay) ...[
                  _timeRow('开始', _start, (d) => setState(() => _start = d)),
                  const SizedBox(height: 8),
                  _timeRow('结束', _end, (d) => setState(() => _end = d)),
                  const SizedBox(height: 12),
                ],
                // 列表 / 日历 / 重复 / 提醒
                _card(
                  child: Column(
                    children: [
                      if (_isReminder) ...[
                        _pickerRow('列表', _listName, AppLists.defaults.map((l) => l['name'] as String).toList(),
                            (v) => setState(() => _listName = v)),
                        const Divider(height: 1),
                      ],
                      _pickerRow('日历', _category, ['工作', '个人', '家庭', '学习', '健康', '娱乐'],
                          (v) => setState(() => _category = v)),
                      const Divider(height: 1),
                      _pickerRow('重复', _repeatRule, ['永不', '每天', '每周', '每两周', '每月', '每年'],
                          (v) => setState(() => _repeatRule = v)),
                      if (_isReminder) ...[
                        const Divider(height: 1),
                        _pickerRow('提醒', _reminderOffset, ['无', '日程当天(09:00)', '1天前(09:00)', '2天前(09:00)', '1周前'],
                            (v) => setState(() => _reminderOffset = v)),
                      ],
                      if (!_isReminder) ...[
                        const Divider(height: 1),
                        _pickerRow('受邀人', _inviteeCtrl.text.isEmpty ? '无' : _inviteeCtrl.text, ['无', '我自己', '团队成员'],
                            (v) {
                          _inviteeCtrl.text = v == '无' ? '' : v;
                          setState(() {});
                        }),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 颜色选择
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('颜色', style: TextStyle(fontSize: 16, color: AppColors.label, decoration: TextDecoration.none)),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _autoColor = !_autoColor),
                            child: Text(_autoColor ? '自动分配' : '手动',
                                style: const TextStyle(
                                    color: AppColors.accent, fontSize: 14, decoration: TextDecoration.none)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: AppColors.taskPalette.map((c) {
                          final selected = c.value == _colorValue;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _colorValue = c.value;
                              _autoColor = false;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOut,
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: selected
                                    ? Border.all(
                                        color: AppColors.label, width: 2.5)
                                    : null,
                              ),
                              child: selected
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 18)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (isEdit) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: AppColors.destructive.withValues(alpha: 0.12),
                      onPressed: () => Navigator.pop(context, 'delete'),
                      child: const Text('删除任务',
                          style: TextStyle(color: AppColors.destructive, decoration: TextDecoration.none)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );

  Widget _timeRow(String label, DateTime value, ValueChanged<DateTime> onChanged) {
    return _card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: AppColors.label, decoration: TextDecoration.none)),
          GestureDetector(
            onTap: () => _pickDateTime(value, onChanged),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.groupedBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_fmtDateTime(value),
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.accent, decoration: TextDecoration.none)),
            ),
          ),
        ],
      ),
    );
  }

  void _pickDateTime(DateTime initial, ValueChanged<DateTime> onChanged) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 280,
        color: AppColors.secondaryBackground,
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: CupertinoDatePicker(
                initialDateTime: initial,
                use24hFormat: true,
                mode: CupertinoDatePickerMode.dateAndTime,
                onDateTimeChanged: onChanged,
              ),
            ),
            CupertinoButton(
              child: const Text('确定', style: TextStyle(decoration: TextDecoration.none)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerRow(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return GestureDetector(
      onTap: () => _showPicker(label, value, options, onChanged),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16, color: AppColors.label, decoration: TextDecoration.none)),
            Row(
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.secondaryLabel, decoration: TextDecoration.none)),
                const SizedBox(width: 4),
                const Icon(CupertinoIcons.chevron_right,
                    size: 14, color: AppColors.secondaryLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(String title, String currentValue, List<String> options, ValueChanged<String> onChanged) {
    int selectedIndex = options.indexOf(currentValue);
    if (selectedIndex < 0) selectedIndex = 0;
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 280,
        color: AppColors.secondaryBackground,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: selectedIndex),
                itemExtent: 36,
                onSelectedItemChanged: (i) => selectedIndex = i,
                children: options
                    .map((o) => Center(
                        child: Text(o,
                            style: const TextStyle(fontSize: 16, decoration: TextDecoration.none))))
                    .toList(),
              ),
            ),
            CupertinoButton(
              child: const Text('确定', style: TextStyle(decoration: TextDecoration.none)),
              onPressed: () {
                onChanged(options[selectedIndex]);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDateTime(DateTime d) =>
      '${d.month}月${d.day}日 ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
