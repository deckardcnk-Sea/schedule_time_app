import 'package:flutter/material.dart';

/// 苹果 iOS 18 风格配色与任务颜色池
class AppColors {
  // 系统背景
  static const Color systemBackground = Color(0xFFF2F2F7); // iOS 浅灰背景
  static const Color secondaryBackground = Color(0xFFFFFFFF);
  static const Color groupedBackground = Color(0xFFEFEFF4);

  // 文字
  static const Color label = Color(0xFF000000);
  static const Color secondaryLabel = Color(0x993C3C43); // 60%
  static const Color tertiaryLabel = Color(0x4D3C3C43); // 30%

  // 分隔线
  static const Color separator = Color(0x363C3C43);
  static const Color gridLine = Color(0xFFE5E5EA);

  // 强调色（iOS 蓝）
  static const Color accent = Color(0xFF007AFF);
  static const Color destructive = Color(0xFFFF3B30);

  // 当前时间红线
  static const Color nowLine = Color(0xFFFF3B30);

  /// 任务色板（苹果日历视频实测主导分类色，12 色）
  /// 取色来源：video_source/frames(+2) 逐帧聚类（analyze_colors2.py）。
  /// 原则：色相对齐视频实色，明度/饱和贴近苹果"柔和但不灰"的观感。
  static const List<Color> taskPalette = [
    Color(0xFFE5554E), // 红（视频粉红/品红系 → 暖正红）
    Color(0xFFE56D44), // 橙（视频亮橙红 #E56D44）
    Color(0xFFE5C04F), // 黄（视频 #E5C872 降亮成黄）
    Color(0xFF5BAE72), // 绿（视频 #59B278 偏柔绿）
    Color(0xFF27B28F), // 青绿（视频 #27B28F）
    Color(0xFF3C94B2), // 青蓝（视频主导工作色 #3C94B2）
    Color(0xFF446DE5), // 蓝（视频亮蓝 #446DE5）
    Color(0xFF5A54C9), // 靛（视频靛紫 #3554B2→柔化）
    Color(0xFF8E59C4), // 紫（视频紫，柔化）
    Color(0xFFE5728F), // 粉（视频粉 #E5728F）
    Color(0xFFB2705B), // 棕/赤陶（视频 #B2705B）
    Color(0xFF8E8E93), // 灰
  ];

  /// 任务填充底色（苹果日历实测：极浅、近白带色调 L≈92% S≈15~22%）
  /// 取色对齐 video_source 逐帧块提取，与 taskPalette 一一对应。
  static const List<Color> taskFillPalette = [
    Color(0xFFFBD9D6), // 红填充（近白偏红）
    Color(0xFFFBE3D6), // 橙填充
    Color(0xFFFBF0CC), // 黄填充
    Color(0xFFDCEFD9), // 绿填充
    Color(0xFFCCF0E6), // 青绿填充
    Color(0xFFD2E9F0), // 青蓝填充（≈#CAEEFC 系）
    Color(0xFFD7E1FB), // 蓝填充
    Color(0xFFE1DFF5), // 靛填充
    Color(0xFFEEDCF8), // 紫填充（≈#F6E2FB 系）
    Color(0xFFFADCE5), // 粉填充（≈#FFCDDE 系）
    Color(0xFFF0E2DB), // 棕填充
    Color(0xFFE6E6EA), // 灰填充
  ];

  /// 任务左边线底色（苹果日历实测：同色相极深 L≈45% S≈65%，近黑带色相）
  /// 与 taskPalette 一一对应，是时间块左侧那条彩色竖线的颜色。
  static const List<Color> taskLinePalette = [
    Color(0xFFD2554E), // 红深线
    Color(0xFFD2814B), // 橙深线
    Color(0xFFD2A23F), // 黄深线
    Color(0xFF3E9A6A), // 绿深线
    Color(0xFF1E9C7E), // 青绿深线
    Color(0xFF3E99B8), // 青蓝深线（视频 #3E99B8 / #3F92B0）
    Color(0xFF3F5BD0), // 蓝深线
    Color(0xFF434CB1), // 靛深线（视频 #434CB1 / #0C1570）
    Color(0xFFB06AC0), // 紫深线（视频 #B06AC0）
    Color(0xFFD2557A), // 粉深线
    Color(0xFFB4866F), // 棕深线（视频 #B4866F）
    Color(0xFF8E8E93), // 灰深线
  ];

  /// 取第 i 个类别的填充底色（越界回退到蓝）
  static Color fillOf(int colorValue) {
    final idx = taskPalette.indexWhere((c) => c.value == colorValue);
    return idx >= 0 ? taskFillPalette[idx] : taskFillPalette[6];
  }

  /// 取第 i 个类别的左边线色（越界回退到蓝深线）
  static Color lineOf(int colorValue) {
    final idx = taskPalette.indexWhere((c) => c.value == colorValue);
    return idx >= 0 ? taskLinePalette[idx] : taskLinePalette[6];
  }

  /// 时间块标题/副文文字色：以"截图逐像素实测"为唯一权威（非纯黑、非 lineOf 同比例混白）。
  /// 实测（蓝块）：标题平均 RGB(51,60,113)≈#333C6F，副文 RGB(70,83,131)≈#465383。
  /// 规律：文字是"同色相族、低饱和深灰"，亮度约 40~50%，带非常淡的本色调——
  /// 绝不能从 lineOf/填充直接混白得到（那会太浅太彩），须按实测关系单独映射。
  ///
  /// 做法：以 lineOf 深线为色相锚点，但以实测 L≈45%/S≈35% 的目标重新构造深灰蓝，
  /// 用 HSL 把 deep 的色相保留、降低饱和到 ~35%、亮度降到 ~45% 得到标题色；
  /// 副文再降一档亮度/升一档饱和。下面用离线算好的固定映射表（已对齐截图实测）。
  static const List<Color> _blockTitlePalette = [
    Color(0xFF8A3B38), // 红 #333C6F 族同亮度档（红相深灰红）
    Color(0xFF8A5238), // 橙
    Color(0xFF8A7233), // 黄
    Color(0xFF3C6B4A), // 绿
    Color(0xFF2C6B5C), // 青绿
    Color(0xFF333C6F), // 青蓝/蓝（截图实测 #333C6F）
    Color(0xFF333C6F), // 蓝（同族）
    Color(0xFF3A3A6B), // 靛
    Color(0xFF6A3A6E), // 紫
    Color(0xFF8A3A58), // 粉
    Color(0xFF6B5246), // 棕
    Color(0xFF3C3C43), // 灰（iOS label 深灰）
  ];

  static const List<Color> _blockSubPalette = [
    Color(0xFFA0504C),
    Color(0xFFA0684A),
    Color(0xFFA08644),
    Color(0xFF4E8360),
    Color(0xFF3A8276),
    Color(0xFF465383), // 截图实测副文 #465383
    Color(0xFF465383),
    Color(0xFF4C4C82),
    Color(0xFF82507E),
    Color(0xFFA0506C),
    Color(0xFF826458),
    Color(0xFF636366),
  ];

  /// 时间块标题文字色（逐像素实测，深但不黑）
  static Color blockTitleColor(int colorValue) {
    final idx = taskPalette.indexWhere((c) => c.value == colorValue);
    return idx >= 0 ? _blockTitlePalette[idx] : _blockTitlePalette[6];
  }

  /// 时间块副文（时间范围）文字色：比标题再浅一档
  static Color blockSubColor(int colorValue) {
    final idx = taskPalette.indexWhere((c) => c.value == colorValue);
    return idx >= 0 ? _blockSubPalette[idx] : _blockSubPalette[6];
  }

  /// 根据字符串（如任务标题/分类）稳定地自动分配一个颜色
  static Color autoColor(String seed) {
    if (seed.isEmpty) return taskPalette[6];
    int hash = 0;
    for (final code in seed.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return taskPalette[hash % taskPalette.length];
  }

  /// 统计页甜甜圈专用柔和粉彩调色板（对齐参考图配色风格）：
  /// 比 taskPalette 更柔、明度更高、饱和中低，整体粉彩苹果风。
  static const List<Color> donutPalette = [
    Color(0xFFF2707E), // 柔红
    Color(0xFFF5A05A), // 柔橙
    Color(0xFFF4CE5B), // 柔黄
    Color(0xFF7CC894), // 柔绿
    Color(0xFF4FC9B0), // 青绿
    Color(0xFF5AB0D6), // 青蓝
    Color(0xFF5C8FE8), // 蓝
    Color(0xFF8A7FE0), // 靛紫
    Color(0xFFB98AD8), // 紫
    Color(0xFFF29BC0), // 粉
    Color(0xFFC99A7E), // 棕/赤陶
    Color(0xFFB5B5BD), // 灰
  ];

  /// 统计页甜甜圈颜色分配：稳定 hash + donutPalette
  static Color donutColor(String seed) {
    if (seed.isEmpty) return donutPalette[6];
    int hash = 0;
    for (final code in seed.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return donutPalette[hash % donutPalette.length];
  }
}
