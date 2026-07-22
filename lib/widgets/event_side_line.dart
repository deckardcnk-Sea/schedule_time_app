import 'package:flutter/material.dart';

/// 苹果风格事件左边线：圆角胶囊状竖条（上下两端也圆润），
/// 嵌在时间块左内边距的窄区里。线宽固定、与圆角自然形成胶囊。
class EventSideLine extends StatelessWidget {
  final Color color;
  final double width;
  final double inset; // 距上下内边距（让线不顶到块边缘，更显圆润留白）
  final double radius;

  const EventSideLine({
    super.key,
    required this.color,
    this.width = 3.0,
    this.inset = 3.0,
    this.radius = 0, // 直角方头（对齐苹果日历参考图：线端非胶囊圆）
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: EdgeInsets.symmetric(vertical: inset),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
