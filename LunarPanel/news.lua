local base = debug.getinfo(1, 'S').source:match('^@(.*/)') or '/mnt/us/extensions/LunarPanel/'
local json = dofile(base .. 'json.lua')
local news = {}

function news.load(path)
    local file = io.open(path, 'rb')
    if not file then return nil end
    local contents = file:read('*a')
    file:close()
    local ok, data = pcall(json.decode, contents)
    if not ok or type(data) ~= 'table' then return nil end
    if data.code ~= 200 or type(data.data) ~= 'table' then return nil end
    local items = data.data
    local timestamp = io.open(path .. '.time', 'r')
    local updated = timestamp and tonumber(timestamp:read('*l')) or 0
    if timestamp then timestamp:close() end
    updated = updated or 0
    local titles = {}
    for _, item in ipairs(items) do
        local title = type(item) == 'table' and (item.title or item.word) or nil
        if type(title) == 'string' and title:match('%S') then
            titles[#titles + 1] = title:gsub('[%c]', ' ')
            if #titles == 10 then break end
        end
    end
    if #titles == 0 then return nil end
    return {titles = titles, updated = updated}
end

function news.pages(data)
    local pages = {}
    for i, title in ipairs(data.titles) do
        local chars = {}
        for ch in title:gmatch('[%z\1-\127\194-\244][\128-\191]*') do chars[#chars + 1] = ch end
        for start = 1, #chars, 26 do
            pages[#pages + 1] = {
                index = i,
                first = table.concat(chars, '', start, math.min(start + 12, #chars)),
                second = table.concat(chars, '', start + 13, math.min(start + 25, #chars)),
            }
        end
    end
    return pages
end

function news.rows(directory, now, rotation_time)
    local sources = {
        {id = 'weibo', label = '微博'},
        {id = 'zhihu', label = '知乎'},
        {id = 'ithome', label = 'IT之家'},
    }
    local rows, seen = {}, {}
    local step = math.floor((rotation_time or now) / 300)
    for _, source in ipairs(sources) do
        local path = directory .. 'hot-' .. source.id .. '.json'
        local data = news.load(path)
        local row = {label = source.label, title = '暂无数据', stale = false}
        if data then
            local stale_file = io.open(directory .. 'hot-' .. source.id .. '.stale', 'r')
            row.stale = stale_file ~= nil or now - data.updated > 7200 or data.updated > now + 300
            if stale_file then stale_file:close() end
            for offset = 0, #data.titles - 1 do
                local title = data.titles[((step + offset) % #data.titles) + 1]
                if not seen[title] then row.title = title; seen[title] = true; break end
            end
        end
        rows[#rows + 1] = row
    end
    return rows
end

function news.daily_rows(directory, now)
    local path = directory .. 'hot-douyin.json'
    local data = news.load(path)
    if not data then return {{label = '抖音', title = '暂无数据', stale = false}} end
    local stale_file = io.open(directory .. 'hot-douyin.stale', 'r')
    local stale = stale_file ~= nil or now - data.updated > 7200 or data.updated > now + 300
    if stale_file then stale_file:close() end
    local rows = {}
    local seen = {}
    local first = math.floor(now / 300)
    for offset = 0, #data.titles - 1 do
        local title = data.titles[((first + offset) % #data.titles) + 1]
        if not seen[title] then
            rows[#rows + 1] = {label = '抖音', title = title, stale = stale}
            seen[title] = true
            if #rows == 4 then break end
        end
    end
    return rows
end

return news
