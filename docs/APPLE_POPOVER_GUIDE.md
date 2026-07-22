# 苹果风格弹窗复刻规范（schedule_time_app）

> 来源：Apple HIG（Popovers / Context Menus）+ UIKit 实现范式。
> 目标：弹窗位置锚定触发控件、出现带缩放+淡入、有交互感、流畅丝滑。

## 一、苹果弹窗的核心交互（已对照 HIG 核实）
1. **锚定到触发控件**：popover 浮在控件附近，箭头尽量直指来源元素；不遮挡来源控件与必要内容。
2. **缩放 + 淡入**：从内容"生长"出来，scale 0.9→1 + opacity 0→1，时长 ~200-320ms，曲线 easeOutCubic。
3. **单次一个**：同一时刻只显示一个浮层，点击外部或 Esc 即优雅收起（收起也有反向动画）。
4. **边缘自动避让**：水平/垂直超出屏幕时自动翻转或夹取。
5. **外观**：大圆角（14pt）、柔和阴影、近不透明实色背景（iOS popover 不是强毛玻璃，而是实色+阴影），内容刚好包住。
6. **大小可变时带过渡动画**：尺寸变化也要 animate，避免"像换了个新弹窗"。

## 二、本项目落地实现
- `lib/widgets/apple_popover.dart`
  - `showApplePopover(...)`：以 `anchorContext`（触发控件 BuildContext）为锚点，用 `Overlay` 承载浮层。自动判定控件下方/上方空间，决定浮层出现在下还是上；水平居中于控件并夹取避免出界。
  - 出现动画：`ScaleTransition`(0.92→1) + `FadeTransition`，`alignment` 跟随出现方向（下→顶部对齐，上→底部对齐），曲线 easeOutCubic，220ms。
  - 关闭：`GestureDetector` 点浮层外部 + 反向动画后 remove。
  - `_PopoverCard`：圆角 14、阴影、近白实色（深色模式用近黑）、0.5pt 描边，内部 `SingleChildScrollView`(BouncingScrollPhysics) 防内容溢出。
  - `showAppleSheet(...)`：大表单专用底部 sheet 路由——底部上浮(Offset 0.08→0) + 缩放(0.96→1) + 淡入，320ms，遮罩 40% 黑。用于 TaskEditorSheet。
- `lib/pages/calendar_page.dart`
  - 顶部"列表""新建"两个图标按钮：通过 `_iconButton` 的 `popover` 参数，点击时直接 `showApplePopover`，内容分别为 `_listsMenuContent` / `_addMenuContent`，**不再用 `showCupertinoModalPopup` 从底部弹出**。
  - `_openEditor` 改用 `showAppleSheet` 打开任务编辑表单。

## 三、使用约定（给后续调试）
- **轻量菜单 / 选择 / 筛选**（内容少、点一下就走）：一律用 `showApplePopover`，锚定触发按钮。
- **大表单 / 编辑器**（内容多、需滚动）：用 `showAppleSheet`（底部上浮，是 iOS 大 sheet 的正确范式，不是"旁出"）。
- **日期/选项 picker**（CupertinoDatePicker / CupertinoPicker）：保持 iOS 原生底部滑出，不动。
- 新增弹窗时优先复用 `apple_popover.dart`，不要再引入 `showModalBottomSheet` / `showCupertinoModalPopup` 作为菜单入口。

## 四、验证方式（手机流畅性底线）
- 安卓模拟器（phone_test / android-34 x86_64）或真机，`flutter run --release -d <device>` 实测：转场、弹窗、各视图切换是否 60fps、无卡顿。
- debug 模式（`flutter run`）卡顿不代表真机卡；release 模式才是验收标准。
- Web 预览（8103）仅供开发看图，不代表原生性能。
