import os
from collections import Counter, defaultdict
from PIL import Image

ROOT = "C:/Users/31243/WorkBuddy/2026-07-19-15-04-20/schedule_time_app/video_source"
FRAMES = [os.path.join(ROOT, "frames", f) for f in sorted(os.listdir(os.path.join(ROOT, "frames")))]
FRAMES2 = [os.path.join(ROOT, "frames2", f) for f in sorted(os.listdir(os.path.join(ROOT, "frames2")))]
ALL = FRAMES + FRAMES2

def clamp(v):
    return max(0, min(255, v))

def rgb_to_hsv(r, g, b):
    r, g, b = r/255, g/255, b/255
    mx, mn = max(r, g, b), min(r, g, b)
    d = mx - mn
    if d == 0:
        h = 0
    elif mx == r:
        h = ((g - b) / d) % 6
    elif mx == g:
        h = (b - r) / d + 2
    else:
        h = (r - g) / d + 4
    h *= 60
    s = 0 if mx == 0 else d / mx
    v = mx
    return h, s, v

global_sat = Counter()       # 彩色块主导色（高饱和 中高明度）
global_neutral = Counter()   # 中性色（低饱和）
frame_reports = []

for p in ALL:
    try:
        im = Image.open(p).convert("RGB")
    except Exception as e:
        continue
    w, h = im.size
    px = im.load()
    sat_pixels = []   # (r,g,b,h,s,v)
    neutral_pixels = []
    step = 3
    for y in range(0, h, step):
        for x in range(0, w, step):
            r, g, b = px[x, y]
            hsv = rgb_to_hsv(r, g, b)
            hh, ss, vv = hsv
            # 统计除白色/黑色/背景灰以外的有色彩像素
            if ss > 0.18 and vv > 0.25 and vv < 0.97:
                sat_pixels.append((r, g, b, hh, ss, vv))
            else:
                neutral_pixels.append((r, g, b))

    # 彩色块：按色相分桶，找每个桶平均颜色
    hue_buckets = defaultdict(list)
    for (r, g, b, hh, ss, vv) in sat_pixels:
        # 12 个色相桶，每 30 度
        bk = int((hh // 30) * 30) % 360
        hue_buckets[bk].append((r, g, b, ss))

    top_colors = []
    for bk, lst in hue_buckets.items():
        # 仅取该桶中饱和度高（更像实色文字/块）的样本
        avg_r = int(sum(c[0] for c in lst) / len(lst))
        avg_g = int(sum(c[1] for c in lst) / len(lst))
        avg_b = int(sum(c[2] for c in lst) / len(lst))
        avg_s = sum(c[3] for c in lst) / len(lst)
        top_colors.append((len(lst), bk, (avg_r, avg_g, avg_b), avg_s))

    top_colors.sort(reverse=True)
    # 只保留占比较大的彩色色调
    frame_reports.append((os.path.basename(p), w, h, len(sat_pixels), top_colors[:6]))

    # 全局聚合：用每帧 top 色相桶的平均色（出现量加权）
    for cnt, bk, (ar, ag, ab), asat in top_colors[:6]:
        global_sat[(ar, ag, ab)] += cnt
    # 中性色：常见的背景/文字/分隔线
    for (r, g, b) in neutral_pixels:
        # 量化到 16 级
        qr, qg, qb = (r//16)*16, (g//16)*16, (b//16)*16
        global_neutral[(qr, qg, qb)] += 1

print("================ 逐帧彩色主导色 ================")
for name, w, h, cnt, tops in frame_reports:
    if cnt < 200:
        print(f"{name:18s} {w}x{h} sat_px={cnt:6d} (基本无色块)")
        continue
    desc = ", ".join(f"H{bk:03d}x{cnt:5d}#{ar:02X}{ag:02X}{ab:02X}" for cnt, bk, (ar,ag,ab), asat in tops)
    print(f"{name:18s} {w}x{h} sat_px={cnt:6d} | {desc}")

print()
print("================ 全局出现最多的彩色块色 ================")
for (r, g, b), cnt in global_sat.most_common(20):
    hsv = rgb_to_hsv(r, g, b)
    print(f"#{r:02X}{g:02X}{b:02X}  count={cnt:7d}  hue={hsv[0]:5.1f} sat={hsv[1]:.2f} val={hsv[2]:.2f}")

print()
print("================ 全局中性色（背景/文字/分隔线） ================")
for (r, g, b), cnt in global_neutral.most_common(25):
    print(f"#{r:02X}{g:02X}{b:02X}  count={cnt:8d}")
