local views = {}

function views.news(context)
    local draw, rect = context.text, context.rectangle
    draw(56, 34, '热点简报', 1, 400)
    draw(480, 34, os.date('%Y.%m.%d %H:%M'), 1, 752)
    rect(48, 78, 704, 2, 0)
    local rows, used = {}, {}
    for _, offset in ipairs({0, 300, 600}) do
        for _, item in ipairs(context.news.rows(context.base, context.now, context.now + offset)) do
            if item.title ~= '暂无数据' and not used[item.title] then
                rows[#rows + 1] = item
                used[item.title] = true
                if #rows == 6 then break end
            end
        end
        if #rows == 6 then break end
    end
    if #rows == 0 then draw(56, 108, '暂无热点', 1, 752) end
    for i, item in ipairs(rows) do
        local y = 102 + (i - 1) * 68
        draw(56, y, item.label, 1, 144)
        rect(153, y + 4, 2, 16, 0)
        draw(168, y, context.fit((item.stale and '缓存 ' or '') .. item.title, 584), 1, 752)
        if i < #rows then rect(56, y + 44, 696, 1, 0) end
    end
end

function views.hexagram(context)
    local draw, rect = context.text, context.rectangle
    local hexagram, index, theme = dofile(context.base .. 'hexagrams.lua').today(os.date('*t', context.now))
    draw(56, 34, '每日卦象', 1, 400)
    draw(480, 34, os.date('%Y.%m.%d', context.now), 1, 752)
    rect(48, 78, 704, 2, 0)
    for line = 6, 1, -1 do
        local y = 130 + (6 - line) * 53
        if hexagram.lines[line] == 1 then
            rect(80, y, 240, 16, 0)
        else
            rect(80, y, 105, 16, 0)
            rect(215, y, 105, 16, 0)
        end
    end
    draw(400, 122, string.format('%02d / 64', index), 1, 752)
    draw(400, 169, hexagram.name .. '卦', 2, 752)
    draw(400, 253, '上卦  ' .. hexagram.upper.name .. '  ' .. hexagram.upper.image, 1, 752)
    draw(400, 300, '下卦  ' .. hexagram.lower.name .. '  ' .. hexagram.lower.image, 1, 752)
    draw(400, 353, '卦意', 1, 752)
    draw(400, 392, context.fit(theme, 352), 1, 752)
    rect(48, 466, 704, 1, 0)
    draw(56, 491, '按日期轮换  每日一卦', 1, 752)
end

function views.device(context)
    local draw, rect, read = context.text, context.rectangle, context.read
    draw(56, 34, '设备状态', 1, 400)
    draw(480, 34, os.date('%Y.%m.%d %H:%M'), 1, 752)
    rect(48, 78, 704, 2, 0)
    draw(56, 105, '电量', 1, 200)
    draw(200, 96, (context.battery ~= '' and context.battery or '?') .. '%', 2, 390)
    draw(448, 105, '供电', 1, 560)
    local supply = context.ac == '1' and (context.charging == '1' and '充电中' or '已停充') or (context.ac == '0' and '未接电' or '未知')
    draw(560, 105, supply, 1, 752)
    rect(48, 168, 704, 1, 0)
    draw(56, 195, '限充', 1, 200)
    draw(200, 195, context.limiter and '运行中' or '未运行', 1, 400)
    draw(448, 195, '无线', 1, 560)
    local network = read('/sys/class/net/wlan0/operstate')
    draw(560, 195, network == 'up' and '已启用' or (network == 'down' and '不可用' or '未知'), 1, 752)
    rect(48, 250, 704, 1, 0)
    draw(56, 278, '天气更新', 1, 240)
    local updated = context.weather_time > 0 and os.date('%m.%d %H:%M', context.weather_time) or '暂无数据'
    draw(240, 278, updated, 1, 500)
    draw(56, 335, '热点来源', 1, 240)
    local rows = context.news.rows(context.base, context.now)
    rows[#rows + 1] = context.news.daily_rows(context.base, context.now)[1]
    for i, item in ipairs(rows) do
        local x = (i - 1) * 168 + 56
        draw(x, 375, item.label, 1, x + 144)
        local state = item.title == '暂无数据' and '暂无' or (item.stale and '缓存' or '正常')
        draw(x, 410, state, 1, x + 144)
    end
end

return views
