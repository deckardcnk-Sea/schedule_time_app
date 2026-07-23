# 提升版本号：pubspec.yaml 的 version: x.y.z+N 与 update/version.json 同步 +1
import re, json, os

ROOT = os.path.dirname(os.path.abspath(__file__))
pubspec = os.path.join(ROOT, 'pubspec.yaml')
vjson = os.path.join(ROOT, 'update', 'version.json')

if not os.path.exists(vjson):
    raise SystemExit('update/version.json 不存在，请先创建（初始 versionCode:1）')

with open(pubspec, encoding='utf-8') as f:
    lines = f.readlines()

new_name = None
new_code = None
for i, line in enumerate(lines):
    m = re.match(r'version:\s*(\d+\.\d+\.\d+)\+(\d+)', line)
    if m:
        name = m.group(1)
        code = int(m.group(2))
        new_code = code + 1
        new_name = f"{name}+{new_code}"
        lines[i] = f"version: {new_name}\n"
        break

if new_name is None:
    raise SystemExit('pubspec.yaml 找不到 version: x.y.z+N 行')

with open(pubspec, 'w', encoding='utf-8') as f:
    f.writelines(lines)

with open(vjson, encoding='utf-8') as f:
    data = json.load(f)

data['versionCode'] = new_code
data['versionName'] = new_name
data['apk'] = 'app-release.apk'
data['note'] = f'自动发布 v{new_name}'

with open(vjson, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False)

# 输出版本号供 bat 读取
with open(os.path.join(ROOT, 'update', '.release_version'), 'w', encoding='utf-8') as f:
    f.write(new_name)

print(f"版本号已提升 -> {new_name} (versionCode={new_code})")
