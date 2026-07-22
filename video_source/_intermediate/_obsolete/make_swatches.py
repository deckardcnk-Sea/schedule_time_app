from PIL import Image, ImageDraw, ImageFont

# 复刻 colors.dart 的数据
names = ['红','橙','黄','绿','青绿','青蓝','蓝','靛','紫','粉','棕','灰']
# 旧：实色边线 t.color（taskPalette）
old_line = [0xE5554E,0xE56D44,0xE5C04F,0x5BAE72,0x27B28F,0x3C94B2,0x446DE5,0x5A54C9,0x8E59C4,0xE5728F,0xB2705B,0x8E8E93]
# 新：浅填充 + 深线（taskFillPalette / taskLinePalette）
new_fill = [0xFBD9D6,0xFBE3D6,0xFBF0CC,0xDCEFD9,0xCCF0E6,0xD2E9F0,0xD7E1FB,0xE1DFF5,0xEEDCF8,0xFADCE5,0xF0E2DB,0xE6E6EA]
new_line = [0xD2554E,0xD2814B,0xD2A23F,0x3E9A6A,0x1E9C7E,0x3E99B8,0x3F5BD0,0x434CB1,0xB06AC0,0xD2557A,0xB4866F,0x8E8E93]

def rgb(v): return ((v>>16)&255,(v>>8)&255,v&255)
W,H = 1100, 360
img = Image.new('RGB',(W,H),(245,245,247))
d = ImageDraw.Draw(img)

def draw_col(x, name, fill, line, label):
    # 画一个时间块样式：浅填充 + 左深线 + 圆角
    bx, by, bw, bh = x+20, 60, 180, 180
    d.rounded_rectangle([bx,by,bx+bw,by+bh], radius=8, fill=fill, outline=(229,229,234), width=1)
    # 左深线（模拟左边线包裹在格内：先留 4px 填充，再 3px 线）
    d.rectangle([bx+4, by+4, bx+7, by+bh-4], fill=line)
    # 文字
    d.text((bx+16, by+14), '事件标题', fill=line)
    d.text((bx+16, by+34), '09:00 - 10:00', fill=line)
    d.text((x+20, by+bh+18), label, fill=(60,60,67))
    d.text((x+20, by+bh+38), name, fill=(120,120,128))

x=0
for i in range(12):
    draw_col(x, names[i], rgb(new_fill[i]), rgb(new_line[i]), '改后：浅填充+深线')
    x+=90

# 旧版示意（小图例，放底部）
d.text((20, 290), '改前(旧)：边线直接用实色 t.color → 偏亮、对比弱', fill=(150,60,60))
bx=380; by=295
for i in range(12):
    d.rectangle([bx+i*50, by, bx+i*50+46, by+40], fill=rgb(old_line[i]))

img.save('C:/Users/31243/WorkBuddy/2026-07-19-15-04-20/schedule_time_app/video_source/_obsolete/color_preview.png')
print('saved C:/Users/31243/WorkBuddy/2026-07-19-15-04-20/schedule_time_app/video_source/_obsolete/color_preview.png', img.size)
