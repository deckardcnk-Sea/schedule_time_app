@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
cd /d "%~dp0" || (echo [错误] 无法进入工程目录 & pause & exit /b 1)

REM ============================================================
REM  一键发布新版：自动升版本号 + 出 apk + 移到 update/
REM  用法：双击本文件，跑完按提示手动 git add/commit/push
REM  前提：本机已装 Flutter 并加入 PATH
REM ============================================================

where flutter >nul 2>nul
if errorlevel 1 (
    echo [错误] 未检测到 flutter 命令，请先安装 Flutter 并加入 PATH。
    pause & exit /b 1
)

echo ============================================
echo [1/4] 读取并提升版本号
echo ============================================

"C:\Users\31243\.workbuddy\binaries\python\versions\3.13.12\python.exe" "%~dp0bump_version.py"
if errorlevel 1 (echo [失败] 版本号提升出错 & pause & exit /b 1)

echo.
echo ============================================
echo [2/4] 编译 release apk（耗时较长，请耐心）
echo ============================================
call "D:\software\flutter\bin\flutter.bat" build apk --release
if errorlevel 1 (echo [失败] flutter build 出错 & pause & exit /b 1)

echo.
echo ============================================
echo [3/4] 移动 apk 到 update/
echo ============================================
if not exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo [错误] 找不到编译产物，build 可能未成功
    pause & exit /b 1
)
move /Y "build\app\outputs\flutter-apk\app-release.apk" "update\app-release.apk"
echo apk 已移至 update/app-release.apk

echo.
echo ============================================
echo [4/4] 完成。请手动执行以下命令推送到 GitHub：
set /p RELVER=<"update\.release_version"
echo   git add -A
echo   git commit -m "release: v%RELVER%"
echo   git push
echo ============================================
pause
