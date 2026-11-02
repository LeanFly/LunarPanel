return function(temperature)
    local value = tonumber((temperature or ''):match('([+-]?%d+%.?%d*)'))
    if not value then return '暂无建议', '等待天气数据' end
    if value >= 28 then return '短袖 薄裤', '注意防晒' end
    if value >= 24 then return '短袖 长裤', '可备薄外套' end
    if value >= 18 then return '长袖 薄外套', '早晚注意保暖' end
    if value >= 10 then return '毛衣 外套', '早晚注意保暖' end
    if value >= 0 then return '厚外套 毛衣', '注意保暖' end
    return '羽绒服 厚衣', '注意防寒保暖'
end
