@echo off
chcp 65001 >nul
setlocal

REM ============================================================
REM  需求4 真机编译运行（后台计时 + 原生悬浮窗胶囊）
REM  双击即可：拉依赖 -> 连设备/模拟器 -> flutter run
REM  注意：必须在已安装 Flutter + Android SDK 的本机运行
REM        沙箱无 Android SDK，无法在此编译（这是上一轮卡死的根因）
REM ============================================================

set "PROJECT_DIR=%~dp0"
cd /d "%PROJECT_DIR%" || (echo [错误] 无法进入工程目录 & pause & exit /b 1)

where flutter >nul 2>nul
if errorlevel 1 (
    echo [错误] 未检测到 flutter 命令，请先安装 Flutter 并加入 PATH。
    echo   安装指引: https://docs.flutter.dev/get-started/install/windows
    pause & exit /b 1
)

echo ====================================================
echo [1/3] 拉取依赖 (flutter pub get)
echo ====================================================
call flutter.bat pub get
if errorlevel 1 (echo [失败] pub get 出错 & pause & exit /b 1)

echo ====================================================
echo [2/3] 检查已连接设备 / 模拟器
echo ====================================================
call flutter.bat devices
echo.

echo ====================================================
echo [3/3] 启动运行 (flutter run)
echo   首次会编译 Kotlin 原生代码，耗时较长，请耐心等待。
echo   真机需 Android 11+ 并在系统设置中授权「显示在其他应用上」。
echo ====================================================
call flutter.bat run --verbose
if errorlevel 1 (echo [失败] flutter run 出错，见上方日志 & pause & exit /b 1)

pause
