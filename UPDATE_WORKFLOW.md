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

## 二、日后每次发布新版本（WorkBuddy 改完代码后）

WorkBuddy 改完代码、build web 验证通过后，你只需在本机做 2 步：

1. **双击 `发布新版.bat`**（工程根目录）：
   它会自动完成以下全部事项，无需你手动改任何版本号：
   - 调用 `bump_version.py`：读取 `pubspec.yaml` 的 `version: 1.0.0+X`，X 自动 +1，
     并同步写回 `pubspec.yaml` 与 `update/version.json`（versionCode / versionName 一致）
   - `flutter build apk --release` 出包
   - `move` apk 到 `update/app-release.apk`（覆盖旧包）
   
   （用 `move` 而非 `copy`：apk 是编译产物，删了可用同一份源码随时 `flutter build apk` 重生，
   没必要在工程里留双份。Windows 的 `move` 遇到同名会自动覆盖旧包，符合发版预期。）

2. **推送**：脚本跑完后，在工程目录执行：
   ```bash
   git add -A
   git commit -m "release: v1.0.0+X"
   git push
   ```
   （X 为脚本自动提升后的数字，看脚本末尾回显即可）

完成。手机上打开 App（或等 2 秒自动检查）即会弹「发现新版本」→ 点更新即可。

> 手动方式（不用脚本时）：自行把 `pubspec.yaml` 与 `update/version.json` 的版本号 +1，
> 再 `flutter build apk --release` 并 `move` 到 `update/`。脚本只是把这三件事合并为一键。

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
