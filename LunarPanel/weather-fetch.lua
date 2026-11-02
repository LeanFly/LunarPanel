local base = debug.getinfo(1, 'S').source:match('^@(.*/)') or '/mnt/us/extensions/LunarPanel/'
local json = dofile(base .. 'json.lua')

local function read_json(path)
    local file = io.open(path, 'rb')
    if not file then return nil end
    local contents = file:read('*a')
    file:close()
    local ok, value = pcall(json.decode, contents)
    return ok and value or nil
end

local weather = read_json(arg[1])
if not weather or type(weather.current) ~= 'table' or type(weather.daily) ~= 'table' then os.exit(1) end
local air = arg[2] and read_json(arg[2]) or nil
local code = tonumber(weather.current.weather_code or -1)
local labels = {
    [0] = '晴', [1] = '少云', [2] = '多云', [3] = '阴',
    [45] = '雾', [48] = '雾', [51] = '小雨', [53] = '小雨', [55] = '小雨',
    [56] = '冻雨', [57] = '冻雨', [61] = '雨', [63] = '中雨', [65] = '大雨',
    [66] = '冻雨', [67] = '冻雨', [71] = '小雪', [73] = '中雪', [75] = '大雪',
    [77] = '雪粒', [80] = '阵雨', [81] = '阵雨', [82] = '强阵雨',
    [85] = '阵雪', [86] = '阵雪', [95] = '雷雨', [96] = '雷雨', [99] = '雷雨',
}
local current = tonumber(weather.current.temperature_2m)
local high = tonumber(weather.daily.temperature_2m_max and weather.daily.temperature_2m_max[1])
local low = tonumber(weather.daily.temperature_2m_min and weather.daily.temperature_2m_min[1])
local rain = tonumber(weather.daily.precipitation_probability_max and weather.daily.precipitation_probability_max[1])
if not current or not high or not low then os.exit(1) end
local aqi = air and air.current and tonumber(air.current.european_aqi) or nil
local file = assert(io.open(base .. 'weather.txt.new', 'w'))
file:write(string.format('Shanghai|%g°C|%s|%g|%g|%s|%s|%d\n', current, labels[code] or '未知', high, low, rain and tostring(math.floor(rain + 0.5)) or '?', aqi and tostring(math.floor(aqi + 0.5)) or '?', os.time()))
file:close()
assert(os.rename(base .. 'weather.txt.new', base .. 'weather.txt'))
