# 晨间简报数据目录

把每天的数据放到下面 3 个目录里，文件名统一使用 `YYYY-MM-DD.json`：

- `automation-data/calendar/`
- `automation-data/mail/`
- `automation-data/followups/`

示例结构：

```text
automation-data/
  calendar/2026-06-23.json
  mail/2026-06-23.json
  followups/2026-06-23.json
```

脚本入口：

```bash
node scripts/generate-morning-brief.mjs 2026-06-23
```

支持的最小 JSON 结构：

```json
{
  "events": [
    {
      "title": "9:30 产品周会",
      "start": "09:30",
      "end": "10:00",
      "location": "腾讯会议",
      "priority": 1,
      "rsvpPending": true
    }
  ]
}
```

```json
{
  "emails": [
    {
      "from": "老板",
      "subject": "确认周三方案",
      "summary": "需要今天中午前回复",
      "priority": 1,
      "replyNeeded": true,
      "receivedAt": "08:10"
    }
  ]
}
```

```json
{
  "items": [
    {
      "title": "催物业确认空调维修",
      "owner": "Jack",
      "due": "今天 18:00",
      "priority": 2,
      "needsAction": true,
      "notes": "如果没回，直接电话跟进"
    }
  ]
}
```
