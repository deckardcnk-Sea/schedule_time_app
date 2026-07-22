"""
苹果日历蓝色任务块 1:1 复刻 (最终版)
=========================================
所有尺寸/位置/颜色均来自像素级实测 (measure_all.py + measure_time.py)
原图: 79e6818.jpg (1348x686)

实测参数总表:
┌─────────────┬──────────────────────────────────────────┐
│ 画布         │ 1348 x 686                                │
│ 块左上       │ (168, 100)                               │
│ 块右下       │ (1205, 537)                              │
│ 块尺寸       │ 宽1037 x 高437                           │
│ 圆角半径     │ 11px                                     │
│ 填充色       │ (202, 209, 255)                          │
│ 左边线 X     │ 195 (宽13px → 195~207)                  │
│ 左边线 Y     │ 125 ~ 510 (长385px)                     │
│ 线顶距块顶   │ 25px                                     │
│ 线底距块底   │ 27px                                     │
│ 线左距块左   │ 27px                                     │
│ 线色         │ (0, 12, 132)                             │
│ 标题文字     │ "周复盘计划" @ (240, 133)                │
│ 标题顶距块顶 │ 33px                                     │
│ 标题距线右   │ 36px                                     │
│ 标题色       │ (23, 35, 77)                             │
│ 时间行 ○     │ @ (238, 258), 直径≈13px                 │
│ 时间数字     │ "09:45–10:45" 距○右侧约56px              │
│ 时间行色     │ (23, 35, 77)                             │
└─────────────┴──────────────────────────────────────────┘
"""

from PIL import Image, ImageDraw, ImageFont

# ==================== 画布 ====================
CW, CH = 1348, 686
BG_C = (255, 255, 255)

# ==================== 颜色 ====================
FILL_C   = (202, 209, 255)   # 浅蓝紫填充
LINE_C   = (0, 12, 132)      # 深蓝左边线
TEXT_C   = (23, 35, 77)      # 深蓝灰文字
TIME_LABEL_C = (142, 142, 147)  # 时间轴灰色

# ==================== 任务块几何 ====================
BLOCK_L, BLOCK_T = 168, 100      # 块左上角
BLOCK_R, BLOCK_B = 1205, 537     # 块右下角
CORNER_R = 11                    # 圆角半径

# ==================== 左边线几何 ====================
LINE_X = 195         # 线左边界
LINE_W = 13          # 线宽 (195~207)
LINE_TOP = 125       # 线顶 (距块顶 25px)
LINE_BOT = 510       # 线底 (距块底 27px)

# ==================== 文字几何 ====================
TITLE_TEXT = "周复盘计划"
TITLE_X, TITLE_Y = 240, 133       # 标题绘制位置
TIME_TEXT = "\u25CB 09:45\u201310:45"
TIME_X, TIME_Y = 238, 258         # 时间行(○对齐)绘制位置

# ==================== 字体 ====================
# 微软雅黑 Light 近似苹果苹方笔画
try:
    FT_TITLE = ImageFont.truetype(r'C:\Windows\Fonts\msyhl.ttc', size=62)
    FT_TIME  = ImageFont.truetype(r'C:\Windows\Fonts\msyhl.ttc', size=48)
    FT_LABEL = ImageFont.truetype(r'C:\Windows\Fonts\msyh.ttc', size=34)
except Exception:
    FT_TITLE = FT_TIME = FT_LABEL = ImageFont.load_default()


def draw(out_path=None, with_compare=False):
    """绘制任务块。out_path 默认为 replica_final.png"""
    out = Image.new('RGB', (CW, CH), BG_C)
    d = ImageDraw.Draw(out)

    # --- 块填充 ---
    d.rounded_rectangle(
        [BLOCK_L, BLOCK_T, BLOCK_R, BLOCK_B],
        radius=CORNER_R, fill=FILL_C
    )

    # --- 左边线 ---
    d.rectangle(
        [LINE_X, LINE_TOP, LINE_X + LINE_W - 1, LINE_BOT],
        fill=LINE_C
    )

    # --- 标题 ---
    d.text((TITLE_X, TITLE_Y), TITLE_TEXT, font=FT_TITLE, fill=TEXT_C)

    # --- 时间行 ---
    d.text((TIME_X, TIME_Y), TIME_TEXT, font=FT_TIME, fill=TEXT_C)

    # --- 时间轴标签 (9:00 / 10:00) ---
    d.text((0, 95), "9:00", font=FT_LABEL, fill=TIME_LABEL_C)
    d.text((0, 600), "10:00", font=FT_LABEL, fill=TIME_LABEL_C)

    # --- 右上角橙色标记条 ---
    d.rectangle([1260, 0, 1320, 70], fill=(255, 177, 66))

    if out_path is None:
        out_path = r'C:\Users\31243\WorkBuddy\2026-07-20-17-37-51\replica_final.png'
    out.save(out_path, quality=96)
    print(f"✅ 已保存: {out_path} ({CW}x{CH})")

    if with_compare:
        orig = Image.open(
            r'D:\software\weixin\xwechat_files\wxid_gj79s2kgsrox22_d1ce\temp\RWTemp\2026-07\9e20f478899dc29eb19741386f9343c8\79e681800bd97424f164cbdaa9838022.jpg'
        ).convert('RGB')
        comp = Image.new('RGB', (CW*2 + 4, CH), (240, 240, 240))
        comp.paste(orig, (0, 0))
        comp.paste(out, (CW + 4, 0))
        cp = r'C:\Users\31243\WorkBuddy\2026-07-20-17-37-51\compare_final.png'
        comp.save(cp, quality=96)
        print(f"✅ 对比图: {cp}")


if __name__ == '__main__':
    draw(with_compare=True)
