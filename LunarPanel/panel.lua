local base = '/mnt/us/extensions/LunarPanel/'
local white, black = 255, 0
local width, height = 800, 600
local canvas = {}
for y = 0, height - 1 do
    canvas[y] = {}
    for x = 0, width - 1 do canvas[y][x] = white end
end

local function rectangle(x, y, w, h, color)
    for yy = math.max(0, y), math.min(height - 1, y + h - 1) do
        for xx = math.max(0, x), math.min(width - 1, x + w - 1) do
            canvas[yy][xx] = color
        end
    end
end

local glyphs, atlas = {}, assert(io.open(base .. 'glyphs.bin', 'rb'))
local data = atlas:read('*a')
atlas:close()
for line in io.lines(base .. 'glyphs.txt') do
    local ch, index = line:match('^(.-)\t(%d+)$')
    if ch then glyphs[ch] = tonumber(index) end
end
local large_glyphs, large_data = {}, nil
local large_atlas = io.open(base .. 'glyphs-large.bin', 'rb')
local large_index = io.open(base .. 'glyphs-large.txt', 'r')
if large_atlas and large_index then
    large_data = large_atlas:read('*a')
    for line in large_index:lines() do
        local ch, index = line:match('^(.-)\t(%d+)$')
        if ch then large_glyphs[ch] = tonumber(index) end
    end
end
if large_atlas then large_atlas:close() end
if large_index then large_index:close() end

local function text(x, y, str, scale, max_x)
    scale = scale or 1
    max_x = max_x or width
    for ch in str:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
        local advance = (ch:byte() < 128 and 16 or 24) * scale
        if x + advance > max_x then break end
        local index = glyphs[ch] or glyphs['?']
        local large = scale > 1 and large_data and large_glyphs[ch]
        if large then
            local size = 24 * scale
            local start = large * (48 * 48 + 72 * 72) + (scale == 3 and 48 * 48 or 0)
            for gy = 0, size - 1 do
                for gx = 0, (ch:byte() < 128 and 16 or 24) * scale - 1 do
                    local pixel = large_data:byte(start + gy * size + gx + 1)
                    if pixel and pixel < white then rectangle(x + gx, y + gy, 1, 1, pixel) end
                end
            end
        elseif index then
            for gy = 0, 23 do
                for gx = 0, (ch:byte() < 128 and 15 or 23) do
                    local pixel = data:byte(index * 576 + gy * 24 + gx + 1)
                    if pixel and pixel < white then
                        rectangle(x + gx * scale, y + gy * scale, scale, scale, pixel)
                    end
                end
            end
        end
        x = x + advance
    end
end

local now = os.date('*t')
local key = os.date('%Y-%m-%d')
local lunar_year, lunar_day, yi, ji, term, next_term = '', '暂无数据', '', '', '', ''
local calendar = io.open(base .. 'lunar-data.txt', 'r')
if calendar then
    for line in calendar:lines() do
        local d, year, day, day_yi, day_ji, day_term, day_next = line:match('^(.-)|(.-)|(.-)|(.-)|(.-)|(.-)|(.-)$')
        if d == key then lunar_year, lunar_day, yi, ji, term, next_term = year, day, day_yi, day_ji, day_term, day_next; break end
    end
    calendar:close()
end

local weather, place, temperature, condition, high, low, rain, aqi, weather_time = io.open(base .. 'weather.txt', 'r'), '', '', '', '', '', '', '', 0
if weather then
    local line = weather:read('*l') or ''
    weather:close()
    place, temperature, condition, high, low, rain, aqi, weather_time = line:match('^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$')
    place, temperature, condition = place or '', temperature or '', condition or ''
    high, low, rain, aqi = high or '', low or '', rain or '?', aqi or '?'
    weather_time = tonumber(weather_time) or 0
    if place ~= 'Shanghai' then temperature, condition = '', '' end
end

local weekdays = {'星期日','星期一','星期二','星期三','星期四','星期五','星期六'}
local function read_value(path)
    local file = io.open(path, 'r')
    if not file then return '' end
    local value = file:read('*l') or ''
    file:close()
    return value
end
local battery = read_value('/sys/class/power_supply/bd7181x_bat/capacity')
local charging = read_value('/sys/class/power_supply/bd7181x_bat/charging')
local ac = read_value('/sys/class/power_supply/bd7181x_ac/online')
local limiter_pid = read_value('/tmp/lunarpanel-charge/active')
local heartbeat = tonumber(read_value('/tmp/lunarpanel-charge/heartbeat')) or 0
local limiter = limiter_pid:match('^%d+$') ~= nil
    and read_value('/proc/' .. limiter_pid .. '/cmdline'):find('lunarpanel%-charge/control%-') ~= nil
    and heartbeat > 0 and os.time() - heartbeat <= 180 and heartbeat - os.time() <= 300
local news = dofile(base .. 'news.lua')
local function fit_title(value, limit)
    local chars, used = {}, 0
    for ch in value:gmatch('[%z\1-\127\194-\244][\128-\191]*') do chars[#chars + 1] = ch end
    local total = 0
    for _, ch in ipairs(chars) do total = total + (ch:byte() < 128 and 16 or 24) end
    if total <= limit then return value end
    local visible = {}
    for _, ch in ipairs(chars) do
        local advance = ch:byte() < 128 and 16 or 24
        if used + advance + 24 > limit then break end
        visible[#visible + 1], used = ch, used + advance
    end
    return table.concat(visible) .. '…'
end
local function wrap_title(value, limit, max_lines)
    local lines, line, used, truncated = {}, {}, 0, false
    for ch in value:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
        local advance = ch:byte() < 128 and 16 or 24
        if used + advance > limit then
            if #lines == max_lines - 1 then truncated = true; break end
            lines[#lines + 1] = table.concat(line)
            line, used = {}, 0
        end
        line[#line + 1], used = ch, used + advance
    end
    if truncated then
        while used + 24 > limit do
            local ch = table.remove(line)
            used = used - (ch:byte() < 128 and 16 or 24)
        end
        line[#line + 1] = '…'
    end
    lines[#lines + 1] = table.concat(line)
    return lines
end
local mode = read_value(base .. 'mode.txt')
if mode ~= 'daily' and mode ~= 'news' and mode ~= 'hexagram' and mode ~= 'device' then mode = 'auto' end
local pages = {'daily', 'news', 'hexagram'}
local view = mode == 'auto' and pages[math.floor(os.time() / 300) % #pages + 1] or mode
local daily_stale = false
if view == 'daily' then
text(56, 30, '今日 ' .. now.year .. '  ' .. weekdays[now.wday], 1, 392)
text(48, 73, string.format('%02d.%02d', now.month, now.day), 3, 392)
text(448, 32, '上海  天气', 1, 760)
if temperature ~= '' then
    text(448, 72, temperature, 2, 760)
    local stale = io.open(base .. 'weather.stale', 'r')
    local cache_label = (stale or os.time() - weather_time > 7200 or weather_time > os.time() + 300) and ' 缓存' or ''
    if stale then stale:close() end
    text(448, 127, condition .. '  ' .. low .. '~' .. high .. '°C' .. cache_label, 1, 760)
else
    text(448, 82, '暂无天气', 1, 760)
    text(448, 122, '请检查网络', 1, 760)
end
rectangle(48, 164, 704, 2, black)
text(56, 184, '农历', 1, 392)
text(48, 222, lunar_day, 2, 392)
text(56, 279, lunar_year, 1, 392)
text(56, 303, term ~= '' and ('节气 ' .. term) or (next_term ~= '' and ('下个节气 ' .. next_term) or '节气 暂无数据'), 1, 392)
local function almanac(y, label, items)
    text(56, y, label, 1, 392)
    local words = {}
    for word in items:gmatch('[^,]+') do words[#words + 1] = word end
    if #words == 0 then words[1] = '暂无数据' end
    text(104, y, table.concat(words, ' ', 1, math.min(2, #words)), 1, 392)
    if #words > 2 then text(104, y + 26, table.concat(words, ' ', 3, math.min(4, #words)), 1, 392) end
end
almanac(335, '宜', yi)
almanac(388, '忌', ji)
rectangle(416, 184, 2, 216, black)
if temperature ~= '' then text(448, 184, '降雨 ' .. rain .. '% 欧标AQI ' .. aqi, 1, 760) end
text(448, 215, '穿衣指南', 1, 760)
local clothing = dofile(base .. 'clothing.lua')
local advice, detail = clothing(temperature)
text(448, 261, advice, 1, 760)
text(448, 298, detail, 1, 760)
text(448, 335, '日程', 1, 760)
local upcoming = dofile(base .. 'events.lua').today(base .. 'events.txt', key)
if #upcoming == 0 then
    text(448, 367, '暂无日程', 1, 760)
else
    for i = 1, math.min(2, #upcoming) do
        text(448, 367 + (i - 1) * 27, fit_title(upcoming[i].time .. ' ' .. upcoming[i].title, 312), 1, 760)
    end
end
rectangle(48, 428, 704, 2, black)
local rows = news.daily_rows(base, os.time())
for i, row in ipairs(rows) do
    local x = 56 + (i - 1) * 176
    if i > 1 then rectangle(x - 8, 440, 1, 76, black) end
    for line_number, line in ipairs(wrap_title(row.title, 160, 3)) do
        text(x, 436 + (line_number - 1) * 30, line, 1, x + 160)
    end
    daily_stale = daily_stale or row.stale
end
local quote = dofile(base .. 'quotes.lua').today(base .. 'quotes.txt', now)
text(56, 526, '今日一句', 1, 152)
text(176, 526, fit_title(quote, 576), 1, 752)
else
    local views = dofile(base .. 'views.lua')
    views[view]({text = text, rectangle = rectangle, fit = fit_title, news = news, base = base,
        now = os.time(), battery = battery, charging = charging, ac = ac, limiter = limiter,
        weather_time = weather_time, read = read_value})
end
local power_status = '未接电'
if ac == '1' then
    power_status = limiter and (charging == '1' and '限充充电' or '限充停充') or (charging == '1' and '充电中' or '未充电')
end
text(56, 557, '更新 ' .. os.date('%H:%M'), 1, 220)
text(240, 557, '电量 ' .. (battery ~= '' and battery or '?') .. '%', 1, 360)
text(390, 557, power_status, 1, 560)
text(570, 557, daily_stale and '热搜缓存' or 'LUNAR PANEL', 1, 752)

local orientation = 'right'
local orientation_file = io.open(base .. 'orientation.txt', 'r')
if orientation_file then
    if orientation_file:read('*l') == 'left' then orientation = 'left' end
    orientation_file:close()
end
local out = assert(io.open((arg and arg[1]) or (base .. 'panel.pgm'), 'wb'))
out:write('P5\n600 800\n255\n')
for x = 0, width - 1 do
    local row = {}
    for y = height - 1, 0, -1 do
        local source_x, source_y = x, y
        if orientation == 'left' then source_x, source_y = width - 1 - x, height - 1 - y end
        row[#row + 1] = string.char(canvas[source_y][source_x])
    end
    out:write(table.concat(row))
end
out:close()
