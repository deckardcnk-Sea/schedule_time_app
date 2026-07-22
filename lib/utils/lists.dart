import 'package:flutter/cupertino.dart';
import '../utils/colors.dart';

/// 预定义提醒事项列表（与视频中的“我的列表”对应）
class AppLists {
  static const List<Map<String, dynamic>> defaults = [
    {'name': '今天', 'icon': CupertinoIcons.star_fill, 'color': AppColors.accent},
    {'name': '计划', 'icon': CupertinoIcons.calendar, 'color': AppColors.accent},
    {'name': '年计划', 'icon': CupertinoIcons.flag_fill, 'color': Color(0xFF007AFF)},
    {'name': '月计划', 'icon': CupertinoIcons.doc_text_fill, 'color': Color(0xFF5856D6)},
    {'name': '周计划', 'icon': CupertinoIcons.list_dash, 'color': Color(0xFF34C759)},
    {'name': '开心清单', 'icon': CupertinoIcons.heart_fill, 'color': Color(0xFFFF2D55)},
    {'name': '书单', 'icon': CupertinoIcons.book_fill, 'color': Color(0xFFFF9500)},
    {'name': '最近删除', 'icon': CupertinoIcons.trash_fill, 'color': Color(0xFF8E8E93)},
  ];

  static Color colorOf(String name) {
    for (final l in defaults) {
      if (l['name'] == name) return l['color'] as Color;
    }
    return AppColors.autoColor(name);
  }

  static IconData iconOf(String name) {
    for (final l in defaults) {
      if (l['name'] == name) return l['icon'] as IconData;
    }
    return CupertinoIcons.list_bullet;
  }
}
