from datetime import date, timedelta
from pathlib import Path

from lupa import LuaRuntime

lua = LuaRuntime()
hexagrams = lua.eval('dofile')((Path('LunarPanel/hexagrams.lua').resolve()).as_posix())

def day(value):
    return lua.table_from({'year': value.year, 'yday': value.timetuple().tm_yday})

def selected(value):
    return hexagrams.today(day(value))

start = date(2024, 12, 1)
seen = {}
for offset in range(64):
    item, index, theme = selected(start + timedelta(days=offset))
    lines = ''.join(str(item.lines[i]) for i in range(1, 7))
    assert lines not in seen and item.name not in [entry[0] for entry in seen.values()]
    seen[lines] = (item.name, item.upper.name, item.lower.name)
    assert 1 <= index <= 64 and theme
assert seen['111111'] == ('乾', '乾', '乾')
assert seen['000000'] == ('坤', '坤', '坤')
assert seen['100010'] == ('屯', '坎', '震')
assert seen['010001'] == ('蒙', '艮', '坎')
assert seen['111000'] == ('泰', '坤', '乾')
assert seen['000111'] == ('否', '乾', '坤')
assert seen['101010'] == ('既济', '坎', '离')
assert seen['010101'] == ('未济', '离', '坎')
assert selected(start)[0].name == selected(start + timedelta(days=64))[0].name
for value in (date(2024, 12, 31), date(2025, 12, 31)):
    _, current, _ = selected(value)
    _, following, _ = selected(value + timedelta(days=1))
    assert following == current % 64 + 1
print('All 64 hexagrams, representative line patterns and daily rotation verified.')
