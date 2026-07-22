import 'package:flutter/material.dart';

/// 苹果风格 Popover。
///
/// 复刻 Apple HIG 中 context menu / popover 的核心交互：
///  - 浮层锚定在触发控件旁边（箭头尽量指向来源元素）
///  - 出现时带轻微「缩放 + 淡入」动画，像从控件里生长出来
///  - 背景毛玻璃模糊 + 柔和阴影 + 大圆角
///  - 点击浮层外部或按 Esc 即优雅收起
///  - 自动避让屏幕边缘
///
/// 用法：把触发按钮包在 [ApplePopoverAnchor] 里，或用 [showApplePopover]。
class ApplePopover extends StatelessWidget {
  final Widget child;
  final GlobalKey _anchorKey = GlobalKey();

  ApplePopover({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(key: _anchorKey, child: child);
  }

  /// 在 [context] 对应控件的旁边弹出 [content]。
  /// 通常这样用：
  ///   ApplePopover(child: MyButton(onTap: () => ApplePopover.of(ctx).show(...)))
  void show(BuildContext context, Widget Function(VoidCallback close) content,
      {double width = 240}) {
    final anchor = _anchorKey.currentContext;
    if (anchor == null) return;
    showApplePopover(
      context: context,
      anchorContext: anchor,
      content: content,
      width: width,
    );
  }
}

/// 直接以某个 [anchorContext]（触发控件）为锚点弹出苹果风格浮层。
/// 返回 [OverlayEntry]，调用方可在需要时手动 [OverlayEntry.remove] 关闭浮层
/// （例如浮层内某选项点击后需先收起浮层再 push 新页面）。
///
/// [content] 接收 [close] 回调（即关闭本浮层），浮层内选项点击后应先调 [close]
/// 收起浮层，再执行后续动作（如 push 新页面），避免浮层残留在新页面之上。
OverlayEntry showApplePopover({
  required BuildContext context,
  required BuildContext anchorContext,
  required Widget Function(VoidCallback close) content,
  double width = 240,
  double maxHeight = 360,
}) {
  final render = anchorContext.findRenderObject() as RenderBox?;
  if (render == null) return OverlayEntry(builder: (_) => const SizedBox.shrink());
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return OverlayEntry(builder: (_) => const SizedBox.shrink());

  final anchor = render.localToGlobal(Offset.zero, ancestor: overlay);
  final size = render.size;
  final screen = overlay.size;

  // 决定浮层出现在控件「下方」还是「上方」：下方剩余空间够就放下，否则放上。
  const margin = 8.0;
  const arrow = 8.0;
  final double spaceBelow = screen.height - (anchor.dy + size.height) - arrow - margin;
  final double spaceAbove = anchor.dy - arrow - margin;
  final bool below = spaceBelow >= spaceAbove;
  // 卡片实际能用的最大高度 = min(maxHeight, 该方向可用空间)，卡片本身按内容自适应，
  // 只有内容超过这个高度时才滚动。这样短内容不会被撑出底部空白。
  final double avail = (below ? spaceBelow : spaceAbove).clamp(120.0, maxHeight);

  // 水平居中于控件，但避让左右边缘。
  double left = anchor.dx + size.width / 2 - width / 2;
  left = left.clamp(margin, screen.width - width - margin);

  final double topBelow = anchor.dy + size.height + arrow;
  final double bottomAbove = screen.height - (anchor.dy - arrow);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ApplePopoverSurface(
      below: below,
      left: left,
      width: width,
      topBelow: topBelow,
      bottomAbove: bottomAbove,
      onDismiss: () => entry.remove(),
      content: content(() => entry.remove()),
      maxHeight: avail,
    ),
  );
  Overlay.of(context).insert(entry);
  return entry;
}

class _ApplePopoverSurface extends StatefulWidget {
  final bool below;
  final double left;
  final double width;
  final double topBelow;
  final double bottomAbove;
  final VoidCallback onDismiss;
  final Widget content;
  final double maxHeight;

  const _ApplePopoverSurface({
    required this.below,
    required this.left,
    required this.width,
    required this.topBelow,
    required this.bottomAbove,
    required this.onDismiss,
    required this.content,
    required this.maxHeight,
  });

  @override
  State<_ApplePopoverSurface> createState() => _ApplePopoverSurfaceState();
}

class _ApplePopoverSurfaceState extends State<_ApplePopoverSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _close() {
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    // 返回手势：点浮层外部/Esc 关闭。
    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        onVerticalDragStart: (_) {},
        child: Stack(
          children: [
            // 浮层本体（点它自己不关闭）。高度按内容自适应：
            // 下方展开→锁定 top，上方展开→锁定 bottom，卡片自然收在最后一项。
            Positioned(
              left: widget.left,
              width: widget.width,
              top: widget.below ? widget.topBelow : null,
              bottom: widget.below ? null : widget.bottomAbove,
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  alignment: widget.below
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  scale: Tween(begin: 0.92, end: 1.0).animate(_scale),
                  child: GestureDetector(
                    onTap: () {}, // 吞掉内部点击
                    child: _PopoverCard(
                      maxHeight: widget.maxHeight,
                      child: widget.content,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 苹果风格底部 Sheet：从底部轻微缩放 + 上浮 + 淡入，遮罩毛玻璃。
/// 用于内容较多的大表单（如任务编辑），替代生硬的 ModalBottomSheet。
Future<T?> showAppleSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      // 必须 opaque: true，否则 Flutter Web 上透明路由 pop 时底层未及时重绘会黑屏
      opaque: true,
      barrierColor: Colors.black.withAlpha(40),
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim, _) {
        return _AppleSheetSurface(
          animation: anim,
          child: builder(ctx),
        );
      },
    ),
  );
}

class _AppleSheetSurface extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _AppleSheetSurface(
      {required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));
    final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);

    return FadeTransition(
      opacity: fade,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SlideTransition(
          position: slide,
          child: ScaleTransition(
            scale: scale,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PopoverCard extends StatelessWidget {
  final Widget child;
  final double maxHeight;

  const _PopoverCard({required this.child, required this.maxHeight});

  @override
  Widget build(BuildContext context) {
    // 苹果风格浮层永远用浅色毛玻璃白底（不依赖 platformBrightness，
    // 避免 Flutter Web 上 Overlay context brightness 判定不准导致黑框）
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF).withAlpha(235),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x32000000),
                blurRadius: 30,
                offset: Offset(0, 12),
                spreadRadius: 0,
              ),
            ],
            border: Border.all(
              color: const Color(0x14000000),
              width: 0.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
