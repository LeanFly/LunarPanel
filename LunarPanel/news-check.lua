local base = '/mnt/us/extensions/LunarPanel/'
local news = dofile(base .. 'news.lua')
if not news.load(arg[1]) then os.exit(1) end
