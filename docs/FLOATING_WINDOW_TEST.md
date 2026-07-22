# 原生悬浮窗（胶囊）真机测试指南

> 本指南用于在本机 Android 真机/模拟器上验证「自写原生 WindowManager 悬浮窗」需求（任务 4-6）。

## 已完成改动
1. **删除 `system_alert_window` 插件依赖**，改为原生实现。
2. 新增 `android/app/src/main/kotlin/com/schedule/schedule_time_app/FloatingWindowService.kt`
   - 前台服务（`dataSync` 类型），用 `WindowManager` 自绘左上角半透明胶囊。
   - 胶囊：左侧分类色圆点 + 活动名（白色粗体）+ 实时计时（等宽白色）。
   - 点击胶囊 → `PendingIntent` 回到 App（MainActivity）。
3. `MainActivity.kt` 注册 `MethodChannel`
   `com.schedule.schedule_time_app/floating_window`，接收
   `checkPermission / requestPermission / show / update / hide / close`。
4. `lib/services/floating_timer_window.dart` 改为 MethodChannel 调用原生服务。
5. `lib/pages/quick_record_page.dart` 显隐逻辑：
   - App **回到前台（resumed）** → `FloatingTimerWindow.hide()`（应用内不显示）。
   - App **离开前台（paused/inactive/detached）且正在计时** → 显示悬浮胶囊。
   - 离开前台时若未授权「显示在其他应用上」，仅保活后台服务（通知栏可见），不弹打扰。

## 本机构建与测试步骤
```bash
# 1. 在本机（已装 Android SDK）进入工程
cd schedule_time_app
flutter pub get
flutter analyze          # 应无 error

# 2. 连上 Android 11+ 真机（或模拟器），开启 USB 调试
flutter run              # 首次安装会请求「显示在其他应用上」权限，请授予

# 3. 测试路径
#   a. 在「快速记录」页点一个活动 → 开始计时（此时 App 内不应出现胶囊）。
#   b. 按 Home 退回桌面 / 切到其它 App → 左上角应出现半透明胶囊，显示活动名+计时，
#      且每秒刷新。
#   c. 点击胶囊 → 应回到本 App 的快速记录页，计时继续。
#   d. 回到 App 后胶囊应自动消失。
#   e. 点「停止并保存」→ 胶囊关闭、后台服务停止、任务写入日历。
```

## 已知限制
- **仅 Android 支持全局悬浮窗**。iOS 的 `SYSTEM_ALERT_WINDOW` 不等同于 Android 全局悬浮，
  本实现在 iOS 上 `ensurePermission` 会返回 false，自动降级为「仅通知栏计时」，不影响核心功能。
- 若用户手动杀掉 App 进程，前台服务与悬浮窗会随进程结束（符合系统行为，可接受）。
- 胶囊默认位于左上角（状态栏下方 40dp）。如需可调位置，改 `FloatingWindowService.addFloatingView` 的 `params.x / params.y`。

## 沙箱说明
当前开发沙箱**未配置 Android SDK**，无法在此环境编译 APK。请在本机执行上述 `flutter run` 验证。
