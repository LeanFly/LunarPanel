const fs = require('fs');
const { Solar } = require('lunar-javascript');
const formatter = new Intl.DateTimeFormat('zh-CN-u-ca-chinese', {
  timeZone: 'UTC', year: 'numeric', month: 'long', day: 'numeric'
});
const days = ['初一','初二','初三','初四','初五','初六','初七','初八','初九','初十',
  '十一','十二','十三','十四','十五','十六','十七','十八','十九','二十',
  '廿一','廿二','廿三','廿四','廿五','廿六','廿七','廿八','廿九','三十'];
const rows = [];
for (let t = Date.UTC(2025, 0, 1); t < Date.UTC(2041, 0, 1); t += 86400000) {
  const date = new Date(t);
  const parts = Object.fromEntries(formatter.formatToParts(date).map(p => [p.type, p.value]));
  const lunar = Solar.fromYmd(date.getUTCFullYear(), date.getUTCMonth() + 1, date.getUTCDate()).getLunar();
  const yi = lunar.getDayYi().slice(0, 4).join(',');
  const ji = lunar.getDayJi().slice(0, 4).join(',');
  const next = lunar.getNextJieQi(true);
  const nextTerm = next ? `${next.getName()} ${next.getSolar().toYmd().slice(5).replace('-', '.')}` : '';
  rows.push(`${date.toISOString().slice(0, 10)}|${parts.yearName}年|${parts.month}${days[Number(parts.day) - 1]}|${yi}|${ji}|${lunar.getJieQi()}|${nextTerm}`);
}
fs.writeFileSync(process.argv[2] || 'lunar-data.txt', rows.join('\n') + '\n', 'utf8');
