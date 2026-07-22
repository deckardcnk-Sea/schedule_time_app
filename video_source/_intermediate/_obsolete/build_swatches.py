import os
from PIL import Image, ImageDraw, ImageFont

OUT = "C:/Users/31243/WorkBuddy/2026-07-19-15-04-20/schedule_time_app/video_source/color_swatches.png"

# 视频实测主导分类色（来自 analyze_colors2 全局聚合，按出现量取代表）
video_colors = [
    ("青蓝(工作)",   (0x3C, 0x94, 0xB2)),
    ("深青蓝",       (0x35, 0x93, 0xB2)),
    ("亮蓝",         (0x44, 0x6D, 0xE5)),
    ("靛紫",         (0x35, 0x54, 0xB2)),
    ("蓝灰紫",       (0x59, 0x6E, 0xB2)),
    ("赤陶橙",       (0xB2, 0x54, 0x35)),
    ("暖橙",         (0xB2, 0x70, 0x5B)),
    ("亮橙红",       (0xE5, 0x6D, 0x44)),
    ("粉红",         (0xE5, 0x72, 0x8F)),
    ("品红",         (0xE5, 0x16, 0x4A)),
    ("黄",           (0xE5, 0xC8, 0x72)),
    ("黄绿",         (0x99, 0xB2, 0x51)),
    ("绿",           (0x59, 0xB2, 0x78)),
    ("青绿",         (0x27, 0xB2, 0x8F)),
]

# 当前 app 的 taskPalette（任务色板 12 色）
app_palette = [
    ("红",   (0xE5, 0x4B, 0x47)),
    ("橙",   (0xDA, 0x8A, 0x2E)),
    ("黄",   (0xC9, 0xA2, 0x27)),
    ("绿",   (0x2F, 0xA8, 0x4F)),
    ("青",   (0x1F, 0xA5, 0x9B)),
    ("浅蓝", (0x2C, 0x92, 0xA8)),
    ("蓝",   (0x2D, 0x6F, 0xCB)),
    ("靛",   (0x58, 0x56, 0xD6)),
    ("紫",   (0x9B, 0x45, 0xC9)),
    ("粉",   (0xD8, 0x3C, 0x68)),
    ("棕",   (0x8C, 0x73, 0x55)),
    ("灰",   (0x8E, 0x8E, 0x93)),
]

W, H = 1100, 700
img = Image.new("RGB", (W, H), (0xF2, 0xF2, 0xF7))
d = ImageDraw.Draw(img)
try:
    font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 18)
    font_s = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 14)
except Exception:
    font = ImageFont.load_default()
    font_s = font

def hexc(c):
    return "#%02X%02X%02X" % c

y = 20
d.text((30, y), "色板对照图", fill=(0,0,0), font=font)
y += 40
# 左：视频实测
d.text((30, y), "A. 视频实测主导分类色（来自逐帧取色）", fill=(0,0,0), font=font)
y += 35
bx = 30
for name, c in video_colors:
    d.rectangle([bx, y, bx+120, y+70], fill=c)
    # 文字颜色按亮度
    r,g,b = c
    lum = 0.299*r+0.587*g+0.114*b
    tc = (0,0,0) if lum>140 else (255,255,255)
    d.text((bx+6, y+6), hexc(c), fill=tc, font=font_s)
    d.text((bx+6, y+30), name, fill=tc, font=font_s)
    bx += 135
    if bx > W-140:
        bx = 30; y += 0
# 复杂布局：分两行
y2 = y + 90
bx = 30
row = 0
for name, c in video_colors:
    if bx > W-150:
        bx = 30; y2 += 90; row += 1
    d.rectangle([bx, y2, bx+120, y2+70], fill=c)
    r,g,b = c
    lum = 0.299*r+0.587*g+0.114*b
    tc = (0,0,0) if lum>140 else (255,255,255)
    d.text((bx+6, y2+6), hexc(c), fill=tc, font=font_s)
    d.text((bx+6, y2+30), name, fill=tc, font=font_s)
    bx += 135

# 右/下：当前 app
y3 = y2 + 110
d.text((30, y3), "B. 当前 app taskPalette（待对比修正）", fill=(0,0,0), font=font)
y3 += 35
bx = 30
for name, c in app_palette:
    if bx > W-150:
        bx = 30; y3 += 90
    d.rectangle([bx, y3, bx+120, y3+70], fill=c)
    r,g,b = c
    lum = 0.299*r+0.587*g+0.114*b
    tc = (0,0,0) if lum>140 else (255,255,255)
    d.text((bx+6, y3+6), hexc(c), fill=tc, font=font_s)
    d.text((bx+6, y3+30), name, fill=tc, font=font_s)
    bx += 135

img.save(OUT)
print("saved", OUT, img.size)
