import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/task_provider.dart';
import 'pages/calendar_page.dart';
import 'pages/stats_page.dart';
import 'pages/quick_record_page.dart';
import 'utils/colors.dart';
import 'widgets/pressable_scale.dart';
import 'services/background_timer_service.dart';
import 'services/update_service.dart';

void main() {
  // 全局未捕获异常兜底：避免 Web 上任何一处 widget 抛错直接白屏，
  // 改为显示可读的错误信息，便于定位。
  ErrorWidget.builder = (details) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          '渲染出错：\n${details.exception}\n\n${details.stack}',
          style: const TextStyle(
            decoration: TextDecoration.none,
            color: Colors.black,
            fontSize: 13,
          ),
        ),
      ),
    );
  };
  // 需求4：初始化后台计时前台服务（真机 Android 生效，Web/iOS 安全跳过）
  BackgroundTimerService.initialize();
  runApp(const MyApp());
}

/// 一次性初始化（Web 端从本地恢复数据 / 真机从数据库加载），返回已初始化的 provider
Future<TaskProvider> _bootstrap() async {
  final provider = TaskProvider();
  await provider.initWebStore();
  await provider.initNativeStore();
  return provider;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 关键：future 只在 initState 创建一次，绝不在 build 里重建。
  // 否则每次父级 rebuild（如页面返回触发 navigator 变化）FutureBuilder
  // 会重置并重新等待，中途显示空白 Scaffold → Web 上表现为白屏。
  late final Future<TaskProvider> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TaskProvider>(
      future: _initFuture,
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CupertinoActivityIndicator())),
          );
        }
        return ChangeNotifierProvider<TaskProvider>.value(
          value: snap.data!,
          child: CupertinoTheme(
            data: const CupertinoThemeData(
              primaryColor: AppColors.accent,
              textTheme: CupertinoTextThemeData(
                textStyle: TextStyle(
                  color: AppColors.label,
                  decoration: TextDecoration.none,
                ),
                actionTextStyle: TextStyle(
                  color: AppColors.label,
                  decoration: TextDecoration.none,
                ),
                tabLabelTextStyle: TextStyle(
                  color: AppColors.label,
                  decoration: TextDecoration.none,
                ),
                navTitleTextStyle: TextStyle(
                  color: AppColors.label,
                  decoration: TextDecoration.none,
                ),
                navLargeTitleTextStyle: TextStyle(
                  color: AppColors.label,
                  decoration: TextDecoration.none,
                ),
                pickerTextStyle: TextStyle(
                  color: AppColors.label,
                  decoration: TextDecoration.none,
                ),
                dateTimePickerTextStyle: TextStyle(
                  color: AppColors.label,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            child: MaterialApp(
              title: '日程时间',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                fontFamily: '.SF Pro Text',
                scaffoldBackgroundColor: AppColors.systemBackground,
                // ⚠️ 关键修复：之前用 ColorScheme.fromSeed(seedColor: 0xFF3C6EFF)
                // 会按 M3 算法派生出 surfaceTint / secondary / tertiary 等荧光蓝派生色，
                // 这些色被 Scaffold 的 bottomNavigationBar 槽位在 Material3 下当作
                // 选中项装饰（细蓝线 / surfaceTint 覆盖）。
                // 改为手写 ColorScheme，只保留标准 iOS 蓝 #007AFF，彻底杜绝荧光蓝派生。
                colorScheme: const ColorScheme.light(
                  primary: AppColors.accent, // #007AFF 标准 iOS 蓝
                  onPrimary: Colors.white,
                  secondary: AppColors.accent,
                  onSecondary: Colors.white,
                  surface: AppColors.secondaryBackground,
                  onSurface: AppColors.label,
                  surfaceTint: Colors.transparent, // 关闭 M3  elevation 叠加荧光蓝
                ),
                useMaterial3: true,
                // 苹果风格：去掉安卓水波纹、聚焦高亮、文字选中荧光蓝
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                // 兜底：即便有 NavigationBar/NavigationRail，indicator 也透明
                navigationBarTheme: const NavigationBarThemeData(
                  indicatorColor: Colors.transparent,
                ),
                // 全局封杀：所有 Text 默认不加任何 decoration（下划线/删除线等）
                // 这是消灭"新建事件页面黄色荧光下划线"的核心防御
                textTheme: const TextTheme(
                  displayLarge: TextStyle(decoration: TextDecoration.none),
                  displayMedium: TextStyle(decoration: TextDecoration.none),
                  displaySmall: TextStyle(decoration: TextDecoration.none),
                  headlineLarge: TextStyle(decoration: TextDecoration.none),
                  headlineMedium: TextStyle(decoration: TextDecoration.none),
                  headlineSmall: TextStyle(decoration: TextDecoration.none),
                  titleLarge: TextStyle(decoration: TextDecoration.none),
                  titleMedium: TextStyle(decoration: TextDecoration.none),
                  titleSmall: TextStyle(decoration: TextDecoration.none),
                  bodyLarge: TextStyle(decoration: TextDecoration.none),
                  bodyMedium: TextStyle(decoration: TextDecoration.none),
                  bodySmall: TextStyle(decoration: TextDecoration.none),
                  labelLarge: TextStyle(decoration: TextDecoration.none),
                  labelMedium: TextStyle(decoration: TextDecoration.none),
                  labelSmall: TextStyle(decoration: TextDecoration.none),
                ),
                textSelectionTheme: const TextSelectionThemeData(
                  cursorColor: AppColors.accent,
                  selectionColor: Color(0x40007AFF),
                  selectionHandleColor: AppColors.accent,
                ),
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
                  },
                ),
              ),
              home: const RootScaffold(),
            ),
          ),
        );
      },
    );
  }
}

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;

  // 顺序：记录 → 日历 → 统计（记录放第一）
  final _pages = const [QuickRecordPage(), CalendarPage(), StatsPage()];

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  /// 启动后静默检查更新；有更新则弹窗提示（覆盖安装，数据保留）。
  Future<void> _checkUpdate() async {
    // 仅在非 Web（即 Android/iOS 原生）端检查原生更新
    if (kIsWeb) return;
    // 延迟一点，避免与启动加载抢资源
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final info = await UpdateService.checkUpdate();
    if (!mounted || info == null) return;
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('发现新版本'),
        content: Text(
            '版本 ${info.versionName} 已发布。\n${info.note ?? ''}\n\n更新将覆盖安装，原有数据不会丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await UpdateService.downloadAndInstall(info);
              if (!mounted) return;
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('更新下载失败，请检查网络')),
                );
              }
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 返回键逻辑修复（问题2 + 返回上一页）：
    // 1) 若当前有子路由可 pop（如 RemindersPage / SearchPage 通过 Navigator.push 压入），
    //    系统返回键应先 pop 子页，而不是切 tab 或退出；
    // 2) 无子路由且不在首页 tab（记录）时，返回键切回首页 tab；
    // 3) 无子路由且已在首页 tab 时，才允许退出（系统默认行为）。
    final navigator = Navigator.of(context);
    final hasSubRoute = navigator.canPop();
    return PopScope(
      canPop: !hasSubRoute && _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (navigator.canPop()) {
          navigator.pop(); // 先关闭当前子页
        } else if (_index != 0) {
          setState(() => _index = 0); // 再切回首页 tab
        }
        // 已在首页 tab 且无子路由：canPop 为 true，系统默认退出
      },
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: KeyedSubtree(
            key: ValueKey<int>(_index),
            child: _pages[_index],
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBottomBar() {
    final items = [
      (CupertinoIcons.add_circled, '记录'),
      (CupertinoIcons.calendar, '日历'),
      (CupertinoIcons.chart_pie, '统计'),
    ];
    // 强制该子树内任何 Material 自动装饰（indicator / 表面 tint）一律透明，
    // 从根上杜绝 Scaffold.bottomNavigationBar 槽位在 M3 下注入的荧光蓝细线。
    return Theme(
      data: Theme.of(context).copyWith(
        navigationBarTheme: const NavigationBarThemeData(
          indicatorColor: Colors.transparent,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.secondaryBackground,
          border: Border(
            top: BorderSide(color: AppColors.gridLine, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: List.generate(items.length, (i) {
                final selected = _index == i;
                return Expanded(
                  child: PressableScale(
                    scaleDown: 0.8,
                    duration: const Duration(milliseconds: 130),
                    onTap: () => setState(() => _index = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i].$1,
                          size: 26,
                          color: selected
                              ? AppColors.accent
                              : AppColors.secondaryLabel,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].$2,
                          style: TextStyle(
                            fontSize: 11,
                            // 显式关闭任何继承来的文字装饰（下划线），双保险
                            decoration: TextDecoration.none,
                            color: selected
                                ? AppColors.accent
                                : AppColors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
