# 晨间简报修复说明

## 已修复的问题

原来的晨间简报没有稳定的数据入口：

- 依赖浏览器里的邮箱/日历登录态，容易被策略拦截。
- 仓库里没有实际的晨报生成脚本。
- 没有明确的数据格式，导致即使拿到数据也不稳定。

现在改成基于本地文件生成：

- 生成脚本：`scripts/generate-morning-brief.mjs`
- 数据目录：`automation-data/`
- 输出格式：固定分为 `P1 / P2 / P3 / 数据缺口`

## 使用方式

1. 把今天的日历写入 `automation-data/calendar/YYYY-MM-DD.json`
2. 把重要未读邮件写入 `automation-data/mail/YYYY-MM-DD.json`
3. 把待跟进事项写入 `automation-data/followups/YYYY-MM-DD.json`
4. 运行：

```bash
node scripts/generate-morning-brief.mjs 2026-06-23
```

如果某类文件缺失，脚本不会失败，而是会在 `数据缺口` 里明确指出缺了哪一项。

## 下一步建议

如果你后面要把它重新接回自动化，可以只做“数据采集”这一层：

- 日历导出为当天 JSON
- 邮件筛选后导出为当天 JSON
- 跟进事项从待办系统同步为当天 JSON

晨报汇总本身就不需要再碰浏览器。
