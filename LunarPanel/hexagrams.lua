local trigrams = {
    {name = '乾', image = '天', lines = {1, 1, 1}},
    {name = '兑', image = '泽', lines = {1, 1, 0}},
    {name = '离', image = '火', lines = {1, 0, 1}},
    {name = '震', image = '雷', lines = {1, 0, 0}},
    {name = '巽', image = '风', lines = {0, 1, 1}},
    {name = '坎', image = '水', lines = {0, 1, 0}},
    {name = '艮', image = '山', lines = {0, 0, 1}},
    {name = '坤', image = '地', lines = {0, 0, 0}},
}

-- Rows are upper trigrams, columns are lower trigrams.
local names = {
    {'乾','履','同人','无妄','姤','讼','遁','否'},
    {'夬','兑','革','随','大过','困','咸','萃'},
    {'大有','睽','离','噬嗑','鼎','未济','旅','晋'},
    {'大壮','归妹','丰','震','恒','解','小过','豫'},
    {'小畜','中孚','家人','益','巽','涣','渐','观'},
    {'需','节','既济','屯','井','坎','蹇','比'},
    {'大畜','损','贲','颐','蛊','蒙','艮','剥'},
    {'泰','临','明夷','复','升','师','谦','坤'},
}

local order = {
    '乾','坤','屯','蒙','需','讼','师','比',
    '小畜','履','泰','否','同人','大有','谦','豫',
    '随','蛊','临','观','噬嗑','贲','剥','复',
    '无妄','大畜','颐','大过','坎','离','咸','恒',
    '遁','大壮','晋','明夷','家人','睽','蹇','解',
    '损','益','夬','姤','萃','升','困','井',
    '革','鼎','震','艮','渐','归妹','丰','旅',
    '巽','兑','涣','节','中孚','小过','既济','未济',
}
local themes = {
    '自强进取', '包容承载', '初生艰难', '启蒙求知', '耐心等待', '审慎处理争议', '统筹与纪律', '亲近协作',
    '小有积蓄', '谨慎践行', '通达和顺', '闭塞待变', '志同道合', '富足有成', '谦逊自持', '顺势而动',
    '顺应变化', '整治积弊', '临事尽责', '观察反思', '明辨决断', '修饰有度', '剥落衰退', '回归复始',
    '守正无妄', '积蓄力量', '养正修身', '重担需支撑', '险中持守', '光明依附', '相互感应', '持久不懈',
    '适时退守', '壮盛有节', '日进光明', '晦暗中守正', '修齐家道', '求同存异', '遇阻知止', '化解困境',
    '有所减损', '增益互助', '果断决断', '意外相遇', '聚合众力', '循序上升', '困境坚守', '共享资源',
    '革故鼎新', '更新鼎立', '震动警醒', '知止安定', '循序渐进', '行动合宜', '丰盛之时', '旅途谨慎',
    '柔顺深入', '和悦交流', '涣散与凝聚', '节制有度', '诚信相待', '小事审慎', '功成守持', '尚未完成',
}

local by_name = {}
for upper, row in ipairs(names) do
    for lower, name in ipairs(row) do
        local top, bottom = trigrams[upper], trigrams[lower]
        by_name[name] = {name = name, upper = top, lower = bottom,
            lines = {bottom.lines[1], bottom.lines[2], bottom.lines[3],
                     top.lines[1], top.lines[2], top.lines[3]}}
    end
end

local hexagrams = {}
function hexagrams.today(date)
    local year = date.year - 1
    local day = 365 * year + math.floor(year / 4) - math.floor(year / 100)
        + math.floor(year / 400) + date.yday
    local index = (day - 1) % #order + 1
    return by_name[order[index]], index, themes[index]
end

return hexagrams
