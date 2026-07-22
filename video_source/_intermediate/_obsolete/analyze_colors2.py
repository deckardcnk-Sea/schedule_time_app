import os
from collections import Counter, defaultdict
from PIL import Image

ROOT = "C:/Users/31243/WorkBuddy/2026-07-19-15-04-20/schedule_time_app/video_source"
ALL = [os.path.join(ROOT, "frames", f) for f in sorted(os.listdir(os.path.join(ROOT, "frames")))] + \
      [os.path.join(ROOT, "frames2", f) for f in sorted(os.listdir(os.path.join(ROOT, "frames2")))]

def rgb_to_hsv(r, g, b):
    r, g, b = r/255, g/255, b/255
    mx, mn = max(r, g, b), min(r, g, b)
    d = mx - mn
    h = 0.0
    if d != 0:
        if mx == r: h = ((g - b) / d) % 6
        elif mx == g: h = (b - r) / d + 2
        else: h = (r - g) / d + 4
        h *= 60
    s = 0 if mx == 0 else d / mx
    return h, s, mx

# 只采集"真·分类色"：高饱和 + 不过亮不过暗
global_sat = defaultdict(int)
per_frame = []

for p in ALL:
    try:
        im = Image.open(p).convert("RGB")
    except Exception:
        continue
    w, h = im.size
    px = im.load()
    buckets = defaultdict(int)  # 量化色相+饱和+明度 -> count
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b = px[x, y]
            hh, ss, vv = rgb_to_hsv(r, g, b)
            if ss < 0.42:   # 强彩色
                continue
            if vv < 0.30 or vv > 0.92:  # 排除太暗/太亮（白字/黑字）
                continue
            # 量化：色相 12 桶, 饱和 5 档, 明度 5 档
            bq = (int(hh//30), int(ss//0.2), int(vv//0.2))
            buckets[bq] += 1
    # 合并相近量化桶为"代表色"
    rep = {}
    for (hq, sq, vq), cnt in buckets.items():
        key = (hq, sq, vq)
        # 还原代表 rgb（中值）
        hv = min(hq*30 + 15, 359); sv = min(sq*0.2 + 0.1, 0.99); vv = min(vq*0.2 + 0.1, 0.99)
        # hsv->rgb
        c = vv * sv
        x = c * (1 - abs((hv/60) % 2 - 1))
        m = vv - c
        if   hv < 60:  rr,gg,bb = c,x,0
        elif hv < 120: rr,gg,bb = x,c,0
        elif hv < 180: rr,gg,bb = 0,c,x
        elif hv < 240: rr,gg,bb = 0,x,c
        elif hv < 300: rr,gg,bb = x,0,c
        else:          rr,gg,bb = c,0,x
        rgb = (int((rr+m)*255), int((gg+m)*255), int((bb+m)*255))
        rep[key] = (rgb, cnt)
    # 按 count 排序
    top = sorted(rep.values(), key=lambda t: -t[1])[:8]
    per_frame.append((os.path.basename(p), sum(c for _,c in rep.values()), top))
    for rgb, cnt in top:
        global_sat[rgb] += cnt

print("================ 逐帧强彩色（分类色候选） ================")
for name, tot, top in per_frame:
    if tot < 150:
        continue
    desc = ", ".join(f"#{r:02X}{g:02X}{b:02X}x{c}" for (r,g,b),c in top)
    print(f"{name:16s} {desc}")

print()
print("================ 全局聚合（消除重复量化桶，按近似色合并） ================")
# 合并：色差 < 40 的归并
merged = []
for (r,g,b), cnt in sorted(global_sat.items(), key=lambda kv: -kv[1]):
    got = None
    for m in merged:
        mr,mg,mb = m["rgb"]
        if abs(r-mr)+abs(g-mg)+abs(b-mb) < 60:
            got = m; break
    if got:
        got["cnt"] += cnt
        # 加权平均
        tot = got["cnt"]
        got["rgb"] = ((got["rgb"][0]*(tot-cnt)+r*cnt)//tot,
                      (got["rgb"][1]*(tot-cnt)+g*cnt)//tot,
                      (got["rgb"][2]*(tot-cnt)+b*cnt)//tot)
    else:
        merged.append({"rgb":(r,g,b), "cnt":cnt})

merged.sort(key=lambda m: -m["cnt"])
for m in merged[:30]:
    r,g,b = m["rgb"]
    hh,ss,vv = rgb_to_hsv(r,g,b)
    print(f"#{r:02X}{g:02X}{b:02X}  count={m['cnt']:7d}  hue={hh:5.1f} sat={ss:.2f} val={vv:.2f}")
