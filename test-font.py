from pathlib import Path

from PIL import Image

base = Path('LunarPanel')

def read_index(name):
    entries = (base / name).read_text(encoding='utf-8').split('\n')
    return {ch: int(index) for line in entries if '\t' in line
            for ch, index in [line.rsplit('\t', 1)]}

index = read_index('glyphs.txt')
atlas = (base / 'glyphs.bin').read_bytes()
assert len(atlas) == len(index) * 24 * 24
assert len(set(atlas)) > 2

def image(ch):
    start = index[ch] * 24 * 24
    return Image.frombytes('L', (24, 24), atlas[start:start + 24 * 24])

for ch in 'WMAI09%':
    assert image(ch).crop((16, 0, 24, 24)).getextrema() == (255, 255)
digit = image('0').point(lambda x: 255 if x < 128 else 0).getbbox()
period = image('.').point(lambda x: 255 if x < 128 else 0).getbbox()
assert period[1] > digit[1] and abs(period[3] - digit[3]) <= 2
large = read_index('glyphs-large.txt')
assert all(ch in large for ch in '0123456789.初十廿正闰冬腊一二三四五六七八九月暂无数据')
assert all(ch in large for ch in '乾坤屯蒙需讼师比小畜履泰否同人大有谦豫随蛊临观噬嗑贲剥复无妄颐过坎离咸恒遁壮晋明夷家睽蹇解损益夬姤萃升困井革鼎震艮渐归妹丰旅巽兑涣节中孚既济未卦')
assert (base / 'glyphs-large.bin').stat().st_size == len(large) * (48 * 48 + 72 * 72)
print('Grayscale glyphs, ASCII cell boundaries, baseline and large glyph coverage verified.')
