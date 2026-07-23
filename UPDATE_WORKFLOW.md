# 更新流程（Android 自动更新）

本 App 已接入「应用内自动更新」：新功能发布后，你手机上打开 App 会弹窗提示更新，
点「立即更新」即覆盖安装，**原有任务数据全部保留，无需导出导入**。

---

## 一、第一次准备（只需做一次）

1. 本机安装 Git 并登录 GitHub 账号 `deckardcnk-Sea`
2. 在 GitHub 新建仓库 `schedule_time_app`，设为 **public**（raw 链接才能被 App 读取）
3. 在工程目录执行：
   ```bash
   git push -u origin main
   ```
   （仓库已 `git init` 并设好 remote；keystore 已随工程提交，保证覆盖安装不丢数据）

---

## 二、日后每次发布新版本（已配 GitHub Actions 自动出包）

**初版(1.0.0+1)需本机出包一次（见下方「初版手动出包」）。之后所有版本全自动。**

WorkBuddy 改完代码后，你只需在本机做 1 步：

```bash
git add -A
git commit -m "你的改动说明"
git push
```

push 后 GitHub Actions（`.github/workflows/build.yml`）会自动：
- 读 `pubspec.yaml` 版本号 X，把 `update/version.json` 升到 X+1
- `flutter build apk --release` 出包
- 把 `app-release.apk` + `version.json` push 回仓库 `update/`

手机打开 App（或等 2 秒自动检查）即会弹「发现新版本」→ 点更新即可。
**你本机不再需要 `flutter build apk`、不再手动改版本号。**

> 版本号规则：配 CI 后，pubspec.yaml 版本号由 CI 自动管理，人工不要手动改它（避免与 CI 冲突/死循环）。WorkBuddy 只改代码、只 push 源码。

---

## 二-附：初版手动出包（仅第一次，之后交给 CI）

本机在工程目录执行（中文路径已解决，build 可过）：
```bash
D:\software\flutter\bin\flutter.bat build apk --release
move build\app\outputs\flutter-apk\app-release.apk update\app-release.apk
git add -A
git commit -m "release: v1.0.0+1 初版"
git push
```
push 后 `update/` 里才有 apk，手机才能首次安装。

---

## 三、手机端行为

- 启动后约 2 秒静默检查 `update/version.json`
- 若远端 `versionCode` > 本机 `buildNumber`，弹窗提示，点「立即更新」下载并调起系统安装器
- 安装器里选「更新」（覆盖安装），数据保留

---

## 四、hosting 地址

`lib/services/update_service.dart` 中：
```dart
static const String baseUrl =
    'https://raw.githubusercontent.com/deckardcnk-Sea/schedule_time_app/main/update/';
```
URL 永久固定（raw 直链），改包只需覆盖 `update/` 下两个文件，无需动代码。

---

## 五、Web 版（兜底/电脑用）

Web 版部署在 CloudStudio（沙箱链接，可能回收）：
https://3000-64a746c971444dcab239c79a933ee45a.e2b.ap-beijing.sandbox.cloudstudio.club/

手机/电脑浏览器直接开即是最新版，数据在浏览器本地，刷新即更新。

---

## 注意

- **keystore 密码**见 `android/key.properties`（个人单机弱密码，可改）
- 覆盖安装不丢数据的前提是**始终用同一个 keystore 签名**（已固定，勿替换）
- 若换机器出包，需把 `android/app/schedule_release.keystore` 一并带走，否则签名不一致会无法覆盖安装
