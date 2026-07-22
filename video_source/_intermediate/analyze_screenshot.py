"""
精确分析苹果日历周视图截图中的时间块视觉结构。
输入：用户提供的 2354x1080 截图
输出：每个时间块的：填充色、左边线色、线宽、内边距、圆角、文字色
"""
import os
from collections import Counter, defaultdict
from PIL import Image

IMG = r"D:/software/weixin/xwechat_files/wxid_gj79s2kgsrox22_d1ce/temp/RWTemp/2026-07/9e20f478899dc29eb19741386f9343c8/8161d816cc4f0a81eb737fd7b3c65d48.jpg"
OUT_DIR = "C:/Users/31243/WorkBuddy/2026-07-19-15-04-20/schedule_time_app/video_source"

im = Image.open(IMG).convert("RGB")
w, h = im.size
px = im.load()

def rgb_to_hsv(r,g,b):
    r,g,b = r/255,g/255,b/255
    mx,mn = max(r,g,b),min(r,g,b)
    d=mx-mn
    h=0.0
    if d:
        if mx==r: h=((g-b)/d)%6
        elif mx==g: h=(b-r)/d+2
        else: h=(r-g)/d+4; h*=60
    return h, (0 if mx==0 else d/mx), mx

def hexc(c): return "#%02X%02X%02X" % c
def lum(c): return 0.299*c[0]+0.587*c[1]+0.114*c[2]

# ============================================================
# 第一步：识别所有"彩色填充区域"（时间块背景）
# 方法：扫描每一行，找到连续的"非白/非灰"彩色段
# ============================================================

# 先采样整图了解背景色
bg_samples = []
for y in range(0, h, 20):
    for x in range(0, w, 20):
        bg_samples.append(px[x,y])
bg_counter = Counter(bg_samples)
print("=== 全局最常见像素（背景候选）===")
for c, n in bg_counter.most_common(15):
    hh,ss,vv = rgb_to_hsv(*c)
    print(f"  {hexc(c)}  count={n:6d}  H={hh:.0f} S={ss:.2f} V={vv:.2f}")

# ============================================================
# 第二步：逐行扫描，找"有颜色的水平段"（时间块的行切片）
# 排除纯白/浅灰背景
# ============================================================
def is_bg_like(r,g,b):
    """判断是否像背景（白/极浅灰）"""
    mx = max(r,g,b); mn = min(r,g,b)
    if mx > 240 and mn > 230: return True   # 近白
    if mx - mn < 12 and mx > 220: return True # 极浅均匀灰
    return False

# 对每行记录彩色段的 [x_start, x_end, y, dominant_color]
color_segments = []
for y in range(h):
    in_seg = False
    seg_start = 0
    seg_colors = []
    for x in range(w):
        r,g,b = px[x,y]
        if not is_bg_like(r,g,b):
            if not in_seg:
                seg_start = x
                in_seg = True
            seg_colors.append((r,g,b))
        else:
            if in_seg and len(seg_colors) >= 3:
                # 计算该段主导色
                cc = Counter(seg_colors)
                dom = cc.most_common(1)[0][0]
                color_segments.append((seg_start, x-1, y, dom, len(seg_colors)))
            in_seg = False
            seg_colors = []
    if in_seg and len(seg_colors) >= 3:
        cc = Counter(seg_colors)
        dom = cc.most_common(1)[0][0]
        color_segments.append((seg_start, w-1, y, dom, len(seg_colors)))

print(f"\n=== 彩色段总数: {len(color_segments)} ===")

# ============================================================
# 第三步：把相邻行的段合并成"块"（矩形区域）
# ============================================================
# 按垂直位置聚类：y 相差 <= 2 且 x 范围重叠 >50% 视为同一块
blocks = []  # each: {x1,x2,y1,y2, colors:[(rgb,count)], name_hint}

for sx, ex, y, col, cnt in color_segments:
    merged = False
    for blk in blocks:
        # y 重叠或邻接
        if y <= blk["y2"] + 2 and y >= blk["y1"] - 2:
            # x 重叠 >30%
            overlap = min(ex, blk["x2"]) - max(sx, blk["x1"])
            wid = max(ex - sx, blk["x2"] - blk["x1"])
            if overlap > wid * 0.25:
                blk["x1"] = min(blk["x1"], sx)
                blk["x2"] = max(blk["x2"], ex)
                blk["y2"] = max(blk["y2"], y)
                blk["colors"].append((col, cnt))
                merged = True
                break
    if not merged:
        blocks.append({"x1":sx, "x2":ex, "y1":y, "y2":y, "colors":[(col,cnt)], "segments":1})
        pass

# 过滤太小（<400 px²）的噪点
blocks = [b for b in blocks if (b["x2"]-b["x1"])*(b["y2"]-b["y1"]) > 400]
blocks.sort(key=lambda b: (b["y1"], b["x1"]))

print(f"\n=== 合并后块数: {len(blocks)} ===\n")

# ============================================================
# 第四步：对每个块精确分析
# ============================================================
for i, b in enumerate(blocks):
    bx1, bx2, by1, by2 = b["x1"], b["x2"], b["y1"], b["y2"]
    bw = bx2 - bx1
    bh = by2 - by1
    
    # 块内所有像素
    block_pixels = []
    for y in range(by1, by2+1):
        for x in range(bx1, bx2+1):
            block_pixels.append(px[x,y])
    
    # 整体主导色（填充底色）
    bc = Counter(block_pixels)
    fill_rgb = bc.most_common(1)[0][0]
    
    # 左边 ~8px 区域的颜色（左边线 + 线左侧同色区）
    left_strip = []
    margin = min(10, bw // 4)
    for y in range(by1, by2+1):
        for x in range(bx1, bx1 + margin):
            left_strip.append(px[x,y])
    lc = Counter(left_strip)
    left_dom = lc.most_common(5)
    
    # 更精细：找左边线——它是左 strip 里**最深**的那条窄带
    # 在左 strip 内按 x 列统计平均亮度，最暗列就是线
    col_brightness = []
    for dx in range(margin):
        vals = []
        for y in range(by1, by2+1):
            if bx1+dx < w:
                r,g,b = px[bx1+dx, y]
                vals.append(0.299*r+0.587*g+0.114*b)
        if vals:
            col_brightness.append((sum(vals)/len(vals), dx))
    col_brightness.sort()
    
    # 最暗的 1~3 列 → 左边线
    line_cols = [cb[1] for cb in col_brightness[:min(3, len(col_brightness))]]
    line_pixels = []
    for y in range(by1, by2+1):
        for dx in line_cols:
            if bx1+dx < w:
                line_pixels.append(px[bx1+dx, y])
    line_c = Counter(line_pixels)
    line_rgb = line_c.most_common(1)[0][0] if line_pixels else fill_rgb
    
    # 线左侧区域（如果线不在最左边）
    pre_line_pixels = []
    pre_min_x = min(line_cols) if line_cols else 0
    for dx in range(pre_min_x):
        for y in range(by1, by2+1):
            if bx1+dx < w:
                pre_line_pixels.append(px[bx1+dx, y])
    pre_fill = Counter(pre_line_pixels).most_common(1)[0][0] if pre_line_pixels else fill_rgb
    
    # 线右侧填充（排除线）
    post_line_pixels = []
    post_start = max(line_cols) + 1 if line_cols else 0
    for dx in range(post_start, min(bw, bx2-bx1+1)):
        for y in range(by1, by2+1):
            if bx1+dx < w:
                post_line_pixels.append(px[bx1+dx, y])
    post_fill = Counter(post_line_pixels).most_common(1)[0][0] if post_line_pixels else fill_rgb
    
    # 圆角检测：检查四角是否比中心更亮（透出背景）
    corner_size = min(6, bh//4, bw//4)
    def avg_brightness(region):
        if not region: return 999
        return sum(0.299*r+0.587*g+0.114*b for r,g,b in region)/len(region)
    
    tl = [px[x,y] for x in range(bx1, bx1+corner_size) for y in range(by1, by1+corner_size)]
    tr = [px[x,y] for x in range(max(bx1,bx2-corner_size), bx2+1) for y in range(by1, by1+corner_size)]
    bl = [px[x,y] for x in range(bx1, bx1+corner_size) for y in range(max(by1,by2-corner_size), by2+1)]
    br = [px[x,y] for x in range(max(bx1,bx2-corner_size), bx2+1) for y in range(max(by1,by2-corner_size), by2+1)]
    center = [px[x,y] for x in range(bx1+bw//3, bx1+2*bw//3) for y in range(by1+bh//3, by1+2*bh//3)]
    
    center_lum = avg_brightness(center)
    corners_avg = avg_brightness(tl+tr+bl+br)
    has_rounded_corners = corners_avg > center_lum + 8
    
    # 内边距（上/下）：检查块顶部和底部几行是否更亮（背景透出）
    top_pad = 0
    for dy in range(min(8, bh//2)):
        row_px = [px[x, by1+dy] for x in range(bx1, bx2+1)]
        row_lum = sum(0.299*r+0.587*g+0.114*b for r,g,b in row_px)/len(row_px)
        if row_lum > center_lum + 10:
            top_pad += 1
        else:
            break
    
    bot_pad = 0
    for dy in range(min(8, bh//2)):
        row_px = [px[x, by2-dy] for x in range(bx1, bx2+1)]
        row_lum = sum(0.299*r+0.587*g+0.114*b for r,g,b in row_px)/len(row_px)
        if row_lum > center_lum + 10:
            bot_pad += 1
        else:
            break
            
    # 左边距
    left_pad = 0
    for dx in range(min(8, bw//2)):
        col_px = [px[bx1+dx, y] for y in range(by1, by2+1)]
        col_lum = sum(0.299*r+0.587*g+0.114*b for r,g,b in col_px)/len(col_px)
        if col_lum > center_lum + 10:
            left_pad += 1
        else:
            break
    
    fh, fsv, fvv = rgb_to_hsv(*fill_rgb)
    lh, lsv, lvv = rgb_to_hsv(*line_rgb)
    
    print(f"── 块 #{i+1} ──  pos=({bx1},{by1})-({bx2},{by2})  size={bw}×{bh}")
    print(f"  填充底色: {hexc(fill_rgb)}  H={fh:.0f} S={fsv:.2f} V={fvv:.2f}")
    print(f"  左边线色: {hexc(line_rgb)}  H={lh:.0f} S={lsv:.2f} V={lvv:.2f}")
    print(f"  线前填充: {hexc(pre_fill)}  线后填充: {hexc(post_fill)}")
    print(f"  线位置: 列偏移{line_cols}(距左缘{pre_min_x}px)")
    print(f"  上/下/左内边距≈{top_pad}/{bot_pad}/{left_pad}px")
    print(f"  圆角: {'是(四角透背景)' if has_rounded_corners else '否'}  中心LUM={center_lum:.0f} 角LUM={corners_avg:.0f}")
    print()

# 额外：全局提取"所有出现过的不同填充色"作为分类色板
all_fills = set()
for b in blocks:
    bc = Counter()
    for y in range(b["y1"], b["y2"]+1):
        for x in range(b["x1"], b["x2"]+1):
            if not is_bg_like(*px[x,y]):
                bc.add(px[x,y])
    all_fills.update(bc.keys())

print("\n=== 所有彩色像素（去重量化）===")
quantized = Counter()
for r,g,b in all_fills:
    qr,qg,qb = (r//8)*8, (g//8)*8, (b//8)*8
    quantized[(qr,qg,qb)] += 1
for (r,g,b),cnt in quantized.most_common(30):
    hh,ss,vv = rgb_to_hsv(r,g,b)
    print(f"  #{r:02X}{g:02X}{b:02X}  n={cnt:4d}  H={hh:5.0f} S={ss:.2f} V={vv:.2f}")
