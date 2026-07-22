# 跨会话交接地图 · schedule_time_app（复刻苹果日历 App）

> 最后更新：2026-07-21 17:13
> 用途：新会话接手时，读完本文件 + `video_source/feature_checklist_v2.md` 即可上手。
> **代码权威 = 磁盘 `.dart`**；本文件仅记录状态，不替代源码。

---

## 0. 一分钟上手
```bat
:: 本机双击预览（端口 8103，热加载）
D:\UserData\桌面\预览日历.bat

:: 沙箱/终端做静态检查（无 error 即通过）
D:\software\flutter\bin\flutter.bat analyze
```
工程路径：`C:\Users\31243\WorkBuddy\2026-07-19-15-04-20\schedule_time_app`
无可编译问题时，优先对照 `video_source/replica_final.png` + `replica_final.py` 做像素级微调。

---

## 1. 当前整体状态
- **编译**：`flutter analyze` 0 error（26 warning/info，非阻断）。
- **功能完成度**：feature_checklist_v2 的"核心界面 + 四视图 + CRUD + 列表/提醒 + 搜索 + 月标记 + 统计"均已落地；通知/设置/手机单日列表/左两图标功能 未做。
- **本日下午已修**：黑屏浮层、周视图日期头、撤回圆圈、顶栏同排、2 处括号错误（详见文末 changelog）。

---

## 2. 源头素材（改代码前必看，绝不可删）
| 文件 | 用途 |
|---|---|
| `video_source/source_video.mp4` | 功能最高权威（B 站视频备份） |
| `video_source/feature_checklist_v2.md` | 26 项功能 + 4 阶段实施计划 |
| `video_source/replica_final.png` + `replica_final.py` | 日视图单块像素实测基准（驱动 `_buildBlock` 的尺寸常量） |
| `video_source/ref_day_single_block.jpg` | 单块参考图 |
| `schedule_time_app_backup_20260721_1132/`（上级目录） | **可编译基准**，括号/结构出错时对照 |

---

## 3. 功能对照（✅ 已做 / ⬜ 待做）
**✅ 日/周/月/年四视图**：苹果顶栏（四图标+搜索+今天+大标题"2024年6月"），日周月 PageView 连续滑动。
**✅ 日/周时间块**：24h 轴 + 彩块(圆角+左彩条+标题/时间) + 重叠横排 + 当前红线。
**✅ 完成态样式**：半透明 + 标题划线 + 置灰（**无圆圈**，已按用户要求撤回 `DoneCircle`）。
**✅ 事件 CRUD**：全天/起止/重复(展开多实例)/分类/受邀人；点实例定位源任务。
**✅ 提醒/我的列表**：分类侧栏 + 勾选 + 旗标 + 智能筛选。
**✅ 搜索 / 月视图彩点 / 统计页(滑块+饼图+备份) / 快速记录 / 底部导航**。
**✅ 苹果交互**：ApplePopover/AppleSheet、去水波纹、Cupertino 转场、按压缩放、时间轴捏合缩放。
**⬜ 本地通知**（reminderOffset 已存库未接）、**⬜ 设置页**、**⬜ 手机单日列表**、**⬜ 左上"日历/邮件"两图标功能**。

---

## 4. 关键文件职责（改哪找哪）
| 文件 | 改什么 |
|---|---|
| `lib/pages/calendar_page.dart` | 顶栏(图标+日周月分段**居中** `_inlineSegmented` 124px)、**统一年月大标题**(顶栏与PageView之间，不在视图内部)、PageView 切换、各弹窗入口 |
| `lib/widgets/day_timeline_view.dart` | 日视图轴 + `_buildBlock`(单块布局，L257-264 像素常量) + 全天行 + 红线 |
| `lib/widgets/week_view.dart` | 周视图：日期头 `_DateHeader`(日号/星期两行) + `_buildBlock`(同构) + 全天区（**年月标题已上移到 calendar_page 统一显示**） |
| `lib/widgets/month_view.dart` | 月网格 + 彩点 |
| `lib/widgets/year_view.dart` | 年概览 tab |
| `lib/widgets/event_side_line.dart` | 时间块左侧直角竖线 |
| `lib/widgets/apple_popover.dart` / `pressable_scale.dart` | 浮层容器 / 按压缩放 |
| `lib/pages/quick_record_page.dart` | **记录页（可自定义活动）**：按大类分组展示活动 chip、右上角齿轮进 `_ActivityManagerSheet` 增删改大类(12色)/活动(图标模糊匹配)；计时保存写 `Task.category` + 大类色 |
| `lib/models/activity_model.dart` | **新增**：`ActivityCategory`{name,colorValue} + `ActivityType`{name,iconCodePoint,categoryName}（大类=颜色） |
| `lib/providers/task_provider.dart` | 状态/CRUD/筛选/视图模式 + **活动配置**(categories/activityTypes/CRUD，仅 Web 持久化 `schedule_categories_v1`/`schedule_activities_v1`) |
| `lib/widgets/task_editor_sheet.dart` | 事件/提醒编辑底部弹窗 |
| `lib/pages/reminders_page.dart` | 提醒列表（保留行内勾选） |
| `lib/providers/task_provider.dart` | 状态/CRUD/筛选/视图模式 |
| `lib/utils/colors.dart` | iOS 降饱和 16 色（勿随意改） |

---

## 5. 接手第一步建议
1. 本机双击 `预览日历.bat` 看当前渲染，确认日/周/月无红屏白屏。
2. 想微调视觉 → 对照 `replica_final.png`；想加功能 → 先读 `feature_checklist_v2.md` 对应阶段。
3. 改完跑 `D:\software\flutter\bin\flutter.bat analyze` 确认 0 error。
4. 若遇 `Expected to find ')'` → 多半是 `_buildBlock` 漏 `Positioned` 闭合 `)`，对照 backup 工程补一层 `        ),`。

---

## 6. 本日下午 changelog（2026-07-21）
1. **黑屏浮层修复**：无 `color` 的 `CupertinoButton`（新建/取消/完成/返回等）全改 `GestureDetector+Row/Text`，显式 `AppColors.label`/`accent`。保留有 `color` 的 filled 按钮。
2. **周视图日期头**：年月→顶部横排窄栏左对齐；日期→"日号/星期缩写"两行，去农历去圆圈；今天=红字粗体。
3. **撤回 DoneCircle**（用户叫停）：日/周/月 block 还原为直接 `Row`，删 `done_circle.dart`；保留半透明+划线完成态。
4. **顶栏同排**：「+」图标 + 「日周月」分段同排，分段固定 124px（`_inlineSegmented` 替满宽 `_buildSegmented`）；滑块仍连续跟随 PageView。
5. **修 2 处括号错误**：`day_timeline_view.dart:353`、`week_view.dart:556` 的 `_buildBlock` 末尾补 `Positioned` 闭合 `)`，analyze 0 error。
