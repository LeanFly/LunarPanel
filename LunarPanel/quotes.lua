local quotes = {}

function quotes.today(path, date)
    local file = io.open(path, 'r')
    if not file then return '暂无内容' end
    local lines = {}
    for raw in file:lines() do
        local line = raw:gsub('^\239\187\191', ''):gsub('[%c]', ' '):match('^%s*(.-)%s*$')
        if line ~= '' and not line:match('^#') then lines[#lines + 1] = line end
    end
    file:close()
    if #lines == 0 then return '暂无内容' end
    local year = date.year - 1
    local day = 365 * year + math.floor(year / 4) - math.floor(year / 100)
        + math.floor(year / 400) + date.yday
    return lines[(day - 1) % #lines + 1]
end

return quotes
