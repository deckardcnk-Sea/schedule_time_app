import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/colors.dart';

/// 圆环图（donut）数据段
class DonutSlice {
  final String label;
  final double minutes; // 分钟
  final Color color;
  DonutSlice({required this.label, required this.minutes, required this.color});
}

/// 参考图风格圆环图：
/// - 圆环细小，每格之间仅留很窄缝隙
/// - 引导线为柔和曲线，从圆环外缘直接接到文字
/// - 左侧：文字（名称 百分比）→ 曲线 → 圆环
/// - 右侧：圆环 → 曲线 → 文字（名称 百分比）
/// - 文字统一灰色、字号小、与线条几乎在一条流畅线上
/// - 支持点击某一段（onTapSlice）
class DonutChart extends StatefulWidget {
  final List<DonutSlice> slices;
  final double size;
  final double gap;
  final void Function(int index)? onTapSlice;

  const DonutChart({
    super.key,
    required this.slices,
    this.size = 360,
    this.gap = 0.006,
    this.onTapSlice,
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  late _DonutPainter _painter;
  final GlobalKey _key = GlobalKey();

  @override
  void didUpdateWidget(covariant DonutChart old) {
    super.didUpdateWidget(old);
    _buildPainter();
  }

  @override
  void initState() {
    super.initState();
    _buildPainter();
  }

  void _buildPainter() {
    final total = widget.slices.fold(0.0, (a, b) => a + b.minutes);
    _painter = _DonutPainter(
      slices: widget.slices,
      totalMinutes: total,
      gap: widget.gap,
      size: widget.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasData = widget.slices.isNotEmpty &&
        widget.slices.any((s) => s.minutes > 0);
    if (!hasData) {
      return SizedBox(
        height: widget.size * 0.55,
        child: const Center(
          child: Text('该时间段还没有时间记录',
              style: TextStyle(
                  decoration: TextDecoration.none,
                  color: AppColors.secondaryLabel)),
        ),
      );
    }
    return GestureDetector(
      onTapDown: (d) {
        if (widget.onTapSlice == null) return;
        final box = _key.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(d.globalPosition);
        final idx = _painter.sliceAt(local);
        if (idx >= 0) widget.onTapSlice!(idx);
      },
      child: CustomPaint(
        key: _key,
        size: Size(widget.size, widget.size * 0.82),
        painter: _painter,
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final double totalMinutes;
  final double gap;
  final double size;
  final double outerR;
  final double innerR;

  late final List<(double, double)> _ranges;

  _DonutPainter({
    required this.slices,
    required this.totalMinutes,
    required this.gap,
    required this.size,
  })  : outerR = size * 0.26,
        innerR = size * 0.19 {
    _computeRanges();
  }

  void _computeRanges() {
    _ranges = [];
    if (totalMinutes <= 0) return;
    double cursor = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.minutes / totalMinutes * (2 * math.pi);
      final start = cursor + gap / 2;
      final end = cursor + sweep - gap / 2;
      _ranges.add((start, end));
      cursor += sweep;
    }
  }

  int sliceAt(Offset local) {
    if (totalMinutes <= 0) return -1;
    final dx = local.dx - size / 2;
    final dy = local.dy - size * 0.41;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < innerR - 6 || dist > outerR + 6) return -1;
    double ang = math.atan2(dy, dx);
    for (var i = 0; i < _ranges.length; i++) {
      final (start, end) = _ranges[i];
      if (_angleInRange(ang, start, end)) return i;
    }
    return -1;
  }

  bool _angleInRange(double a, double start, double end) {
    double t = a;
    while (t < start) {
      t += 2 * math.pi;
    }
    while (t > start + 2 * math.pi) {
      t -= 2 * math.pi;
    }
    return t >= start && t <= end;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (totalMinutes <= 0) return;
    final cx = size.width / 2;
    final cy = size.height * 0.50;
    canvas.save();
    canvas.translate(cx, cy);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerR - innerR
      ..strokeCap = StrokeCap.butt;

    for (var i = 0; i < slices.length; i++) {
      final (start, end) = _ranges[i];
      paint.color = slices[i].color;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: (outerR + innerR) / 2),
        start,
        end - start,
        false,
        paint,
      );
    }

    // 准备标注
    final infos = <_LabelInfo>[];
    for (var i = 0; i < slices.length; i++) {
      final pct = slices[i].minutes / totalMinutes;
      if (pct < 0.035) continue;
      final (start, end) = _ranges[i];
      final mid = (start + end) / 2;
      infos.add(_LabelInfo(index: i, mid: mid, pct: pct));
    }

    // 计算每个标签的文字尺寸（名称 百分比 单行，统一灰色）
    final textMetrics = <int, _TextMetric>{};
    for (final info in infos) {
      textMetrics[info.index] = _measureLabel(slices[info.index], info.pct);
    }

    // 按角度防重叠，保证每个标签到圆环的线长一致
    final finalAngles = _layoutAngles(infos);

    for (final info in infos) {
      final i = info.index;
      final mid = finalAngles[i]!;
      final p = slices[i];
      final onRight = math.cos(mid) >= 0;
      final metric = textMetrics[i]!;

      // 标签沿径向分布：线段长度随角度轻微变化（参考图：基本差不多、极端稍变）。
      // 水平方向较短、上下方向略长。
      final lineLen = 18.0 + math.sin(mid).abs() * 10.0;
      final labelCenterR = outerR + lineLen;
      final labelCenter = Offset(
        math.cos(mid) * labelCenterR,
        math.sin(mid) * labelCenterR,
      );

      // 文字偏移：左右侧文字起点不同
      const textPad = 4.0;
      final textX = onRight
          ? labelCenter.dx + textPad
          : labelCenter.dx - metric.width - textPad;
      final textTop = labelCenter.dy - metric.height / 2;

      // 先画文字
      _drawText(canvas, metric.text,
          offset: Offset(textX, textTop),
          color: AppColors.secondaryLabel,
          fontSize: 11,
          align: TextAlign.left);

      // 曲线起点：直接落在圆环外缘（与色块连在一起，无间隙）
      final ringStart = Offset(
        math.cos(mid) * outerR,
        math.sin(mid) * outerR,
      );

      // 曲线终点：文字靠近圆环一侧的中点
      final labelAttach = Offset(
        onRight ? textX - 2 : textX + metric.width + 2,
        labelCenter.dy,
      );

      // 单一二次贝塞尔，无转折点、无直线段、无端点圆点。
      // 控制点 y 取终点 y → 终点切线趋于水平；x 偏向圆环侧 → 弯曲集中在环端。
      final ctrl = Offset(
        ringStart.dx + (labelAttach.dx - ringStart.dx) * 0.32,
        labelAttach.dy,
      );

      final linePaint = Paint()
        ..color = p.color
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final path = Path()
        ..moveTo(ringStart.dx, ringStart.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, labelAttach.dx, labelAttach.dy);
      canvas.drawPath(path, linePaint);
    }

    // 总时间：右上角靠边，字号较小（参考图没有总时间，但产品需要展示）
    final totalH = (totalMinutes / 60).toStringAsFixed(1);
    final topRight = Offset(outerR * 1.15, -outerR * 1.05);
    _drawText(canvas, '$totalH h',
        offset: Offset(topRight.dx, topRight.dy - 16),
        color: AppColors.label,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        align: TextAlign.center);
    _drawText(canvas, '已记录',
        offset: Offset(topRight.dx, topRight.dy + 2),
        color: AppColors.secondaryLabel,
        fontSize: 9,
        align: TextAlign.center);

    canvas.restore();
  }

  /// 角度防重叠：相邻标签保持最小角度间隔，使每条引导线长度一致。
  /// 左右两侧分别排序处理；右侧上方预留总时间禁区。
  Map<int, double> _layoutAngles(List<_LabelInfo> infos) {
    final out = <int, double>{};
    for (final info in infos) {
      out[info.index] = info.mid;
    }

    // 右侧上方禁区（避开总时间文字）
    const forbiddenStart = -math.pi / 2 - 0.55;
    const forbiddenEnd = -math.pi / 2 + 0.55;
    for (final info in infos) {
      if (math.cos(info.mid) >= 0) {
        double a = out[info.index]!;
        while (a < forbiddenStart) {
          a += 2 * math.pi;
        }
        while (a > forbiddenEnd) {
          a -= 2 * math.pi;
        }
        if (a >= forbiddenStart && a <= forbiddenEnd) {
          // 落到禁区则压到禁区下边界
          out[info.index] = forbiddenEnd;
        }
      }
    }

    // 最小角度间隔（弧度），按文字高度折算到半径 outerR+lineLen 处的弧长
    const lineLen = 20.0;
    final minAngleGap = 16.0 / (outerR + lineLen);

    for (final right in [true, false]) {
      final side = infos
          .where((i) => math.cos(i.mid) >= 0 == right)
          .toList()
        ..sort((a, b) => out[a.index]!.compareTo(out[b.index]!));
      for (var i = 1; i < side.length; i++) {
        final prev = side[i - 1];
        final cur = side[i];
        if (out[cur.index]! - out[prev.index]! < minAngleGap) {
          out[cur.index] = out[prev.index]! + minAngleGap;
        }
      }
    }
    return out;
  }

  _TextMetric _measureLabel(DonutSlice slice, double pct) {
    final text = '${slice.label} ${(pct * 100).toStringAsFixed(0)}%';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.secondaryLabel,
          fontSize: 11,
          decoration: TextDecoration.none,
          // 不指定 fontFamily，使用系统默认字体族以支持 emoji / 特殊字符 fallback
        ),
      ),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    return _TextMetric(text: text, width: tp.width, height: tp.height);
  }

  void _drawText(Canvas canvas, String text,
      {required Offset offset,
      required Color color,
      required double fontSize,
      FontWeight fontWeight = FontWeight.normal,
      TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          decoration: TextDecoration.none,
          // 不指定 fontFamily，使用系统默认字体族以支持 emoji / 特殊字符 fallback
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    double dx = offset.dx;
    if (align == TextAlign.center) {
      dx = offset.dx - tp.width / 2;
    } else if (align == TextAlign.right) {
      dx = offset.dx - tp.width;
    }
    tp.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.slices != slices || old.totalMinutes != totalMinutes;
}

class _LabelInfo {
  final int index;
  final double mid;
  final double pct;
  _LabelInfo({required this.index, required this.mid, required this.pct});
}

class _TextMetric {
  final String text;
  final double width;
  final double height;
  _TextMetric({required this.text, required this.width, required this.height});
}
