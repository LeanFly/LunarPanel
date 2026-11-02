import os
import sys
from PIL import Image, ImageDraw, ImageFont

chars = (
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz '
    '+-.,:/%()°?~'
    '今日农历天气星期一二三四五六七八九日年月初十廿正闰冬腊节气下个'
    '甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥'
    '无法获取网络位置本地数据更新请检查时间暂无宜忌'
    '穿衣指南建议等待短袖薄裤注意防晒长可备外套早晚保暖毛厚羽绒服寒上海百度热搜缓存热点电量未接限充充电中停充降雨空气未知'
)
target = sys.argv[1] if len(sys.argv) > 1 else '.'
with open(os.path.join(target, 'lunar-data.txt'), encoding='utf-8') as calendar:
    chars += calendar.read().replace('\n', '').replace('|', '')
chars += ''.join(chr(code) for start, end in ((0x4e00, 0xa000), (0x3000, 0x3040), (0xff00, 0xfff0), (0x2000, 0x2070)) for code in range(start, end))
chars = ''.join(dict.fromkeys(chars))
font_path = 'C:/Windows/Fonts/msyh.ttc'

def glyph(ch, scale, font):
    cell = 24 * scale
    advance = (16 if ord(ch) < 128 else 24) * scale
    box = font.getbbox(ch, anchor='ls')
    ink_width = box[2] - box[0]
    image = Image.new('L', (cell, cell), 255)
    if ink_width <= 0:
        return image.tobytes()
    source = Image.new('L', (ink_width, cell), 255)
    ImageDraw.Draw(source).text((-box[0], 19 * scale), ch, font=font, fill=0, anchor='ls')
    available = advance - 2 * scale
    if ink_width > available:
        source = source.resize((available, cell), Image.Resampling.LANCZOS)
        ink_width = available
    image.paste(source, ((advance - ink_width) // 2, 0))
    return image.tobytes()

font = ImageFont.truetype(font_path, 22)
with open(os.path.join(target, 'glyphs.txt'), 'w', encoding='utf-8', newline='\n') as index, open(os.path.join(target, 'glyphs.bin'), 'wb') as data:
    for i, ch in enumerate(chars):
        index.write(f'{ch}\t{i}\n')
        data.write(glyph(ch, 1, font))

large_chars = ''.join(dict.fromkeys(chars[:chars.index('今日')] + '初十廿正闰冬腊一二三四五六七八九月暂无数据'
    + '乾坤屯蒙需讼师比小畜履泰否同人大有谦豫随蛊临观噬嗑贲剥复无妄颐过坎离咸恒遁壮晋明夷家睽蹇解损益夬姤萃升困井革鼎震艮渐归妹丰旅巽兑涣节中孚既济未卦'))
with open(os.path.join(target, 'glyphs-large.txt'), 'w', encoding='utf-8', newline='\n') as index, open(os.path.join(target, 'glyphs-large.bin'), 'wb') as data:
    fonts = {scale: ImageFont.truetype(font_path, 22 * scale) for scale in (2, 3)}
    for i, ch in enumerate(large_chars):
        index.write(f'{ch}\t{i}\n')
        for scale in (2, 3):
            data.write(glyph(ch, scale, fonts[scale]))
