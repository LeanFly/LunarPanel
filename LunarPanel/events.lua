local events = {}

function events.today(path, day)
    local file = io.open(path, 'r')
    if not file then return {} end
    local found = {}
    for line in file:lines() do
        local date, hour, minute, title = line:match('^(%d%d%d%d%-%d%d%-%d%d)%s+(%d%d):(%d%d)|(.+)$')
        if date == day and tonumber(hour) < 24 and tonumber(minute) < 60 and title:match('%S') then
            found[#found + 1] = {time = hour .. ':' .. minute, title = title:gsub('[%c]', ' ')}
        end
    end
    file:close()
    table.sort(found, function(a, b) return a.time < b.time end)
    return found
end

return events
