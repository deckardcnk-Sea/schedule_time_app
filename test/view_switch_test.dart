import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:schedule_time_app/pages/calendar_page.dart';
import 'package:schedule_time_app/providers/task_provider.dart';
import 'package:schedule_time_app/widgets/day_timeline_view.dart';
import 'package:schedule_time_app/widgets/week_view.dart';

void main() {
  testWidgets('view switch: PageView actually animates (old view lingers)',
      (tester) async {
    final provider = TaskProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<TaskProvider>.value(
        value: provider,
        child: const MaterialApp(home: CalendarPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DayTimelineView), findsOneWidget);

    // 点击“周”
    await tester.tap(find.text('周'));
    // 推进到动画中段：PageView 切换时旧页(日)不应被瞬间移除
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));

    final dayDuring = find.byType(DayTimelineView).evaluate().length;
    final weekDuring = find.byType(WeekView).evaluate().length;
    debugPrint('[TEST] during-animation: DayTimelineView=$dayDuring, WeekView=$weekDuring');

    // 动画中段两者应同时存在 —— 证明是连续滑动而非瞬间替换
    expect(dayDuring, 1,
        reason: 'PageView 切换动画中旧视图应仍在树中');
    expect(weekDuring, 1,
        reason: 'PageView 切换动画中新视图应已存在');

    await tester.pumpAndSettle();
    expect(find.byType(WeekView), findsOneWidget);
    expect(find.byType(DayTimelineView), findsNothing);
  });
}
