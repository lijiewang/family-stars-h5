import fs from "node:fs";
import path from "node:path";

const cwd = process.cwd();
const dataRoot = path.join(cwd, "automation-data");
const inputDate = process.argv[2];
const today = inputDate || formatDate(new Date());

const calendarPath = path.join(dataRoot, "calendar", `${today}.json`);
const mailPath = path.join(dataRoot, "mail", `${today}.json`);
const followupPath = path.join(dataRoot, "followups", `${today}.json`);

const calendar = loadItems(calendarPath, ["events", "items"]);
const mail = loadItems(mailPath, ["emails", "items"]);
const followups = loadItems(followupPath, ["items", "followups"]);

const calendarItems = normalizeCalendar(calendar.items);
const mailItems = normalizeMail(mail.items);
const followupItems = normalizeFollowups(followups.items);

const actionItems = [
  ...calendarItems.filter((item) => item.needsAction),
  ...mailItems.filter((item) => item.needsAction),
  ...followupItems.filter((item) => item.needsAction)
].sort(comparePriority);
const actionSet = new Set(actionItems);

const allPriorityItems = [
  ...calendarItems,
  ...mailItems,
  ...followupItems
].sort(comparePriority);

const p1 = allPriorityItems.filter((item) => item.priority === 1 && !actionSet.has(item));
const p2 = allPriorityItems.filter((item) => item.priority === 2 && !actionSet.has(item));
const p3 = allPriorityItems.filter((item) => item.priority >= 3 && !actionSet.has(item));

const gaps = [];
if (calendar.missing) gaps.push(`今日日历未提供：${relative(calendarPath)}`);
if (mail.missing) gaps.push(`今日邮件未提供：${relative(mailPath)}`);
if (followups.missing) gaps.push(`今日跟进事项未提供：${relative(followupPath)}`);

const lines = [];
lines.push(`**晨间简报｜${today}**`);
lines.push("");

lines.push("**P1｜需要行动**");
if (actionItems.length) {
  for (const item of actionItems) {
    lines.push(`- ${renderItem(item, true)}`);
  }
} else {
  lines.push("- 今日没有明确标记为需要立即处理的事项。");
}
lines.push("");

lines.push("**P2｜重要安排与关注项**");
if (p1.length || p2.length) {
  for (const item of [...p1, ...p2]) {
    lines.push(`- ${renderItem(item, false)}`);
  }
} else {
  lines.push("- 暂无已录入的重要安排。");
}
lines.push("");

lines.push("**P3｜一般事项**");
if (p3.length) {
  for (const item of p3) {
    lines.push(`- ${renderItem(item, false)}`);
  }
} else {
  lines.push("- 暂无一般优先级事项。");
}
lines.push("");

lines.push("**数据缺口**");
if (gaps.length) {
  for (const gap of gaps) {
    lines.push(`- ${gap}`);
  }
} else {
  lines.push("- 今日数据完整。");
}

process.stdout.write(`${lines.join("\n")}\n`);

function loadItems(filePath, keys) {
  if (!fs.existsSync(filePath)) {
    return { items: [], missing: true };
  }

  try {
    const raw = fs.readFileSync(filePath, "utf8");
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) {
      return { items: parsed, missing: false };
    }

    for (const key of keys) {
      if (Array.isArray(parsed?.[key])) {
        return { items: parsed[key], missing: false };
      }
    }

    return { items: [], missing: false };
  } catch (error) {
    return {
      items: [
        {
          title: `数据文件解析失败：${relative(filePath)}`,
          summary: error instanceof Error ? error.message : "未知错误",
          priority: 1,
          needsAction: true,
          source: "system"
        }
      ],
      missing: false
    };
  }
}

function normalizeCalendar(items) {
  return items.map((item) => ({
    source: "calendar",
    title: item.title || "未命名日程",
    summary: joinParts([
      item.start && item.end ? `${item.start}-${item.end}` : item.start || item.end,
      item.location,
      item.notes
    ]),
    priority: normalizePriority(item.priority, 2),
    needsAction: Boolean(item.needsAction || item.actionRequired || item.rsvpPending),
    actionLabel: item.actionLabel || (item.rsvpPending ? "需要回复" : item.needsAction ? "需要处理" : ""),
    meta: joinParts([
      item.attendee,
      item.organizer
    ])
  }));
}

function normalizeMail(items) {
  return items
    .filter((item) => item.unread !== false)
    .map((item) => ({
      source: "mail",
      title: item.subject || "无主题邮件",
      summary: joinParts([
        item.from ? `来自 ${item.from}` : "",
        item.summary,
        item.receivedAt ? `收到于 ${item.receivedAt}` : ""
      ]),
      priority: normalizePriority(item.priority, item.important ? 1 : 2),
      needsAction: Boolean(item.needsAction || item.replyNeeded || item.deadlineToday),
      actionLabel: item.actionLabel || (item.replyNeeded ? "需要回复" : item.deadlineToday ? "今日截止" : item.needsAction ? "需要处理" : ""),
      meta: item.thread
    }));
}

function normalizeFollowups(items) {
  return items.map((item) => ({
    source: "followup",
    title: item.title || "未命名待跟进事项",
    summary: joinParts([
      item.owner ? `责任人 ${item.owner}` : "",
      item.due ? `截止 ${item.due}` : "",
      item.notes
    ]),
    priority: normalizePriority(item.priority, 2),
    needsAction: Boolean(item.needsAction ?? true),
    actionLabel: item.actionLabel || "需要跟进",
    meta: Array.isArray(item.tags) ? item.tags.join(" / ") : item.tags
  }));
}

function renderItem(item, showAction) {
  const tags = [];
  tags.push(sourceLabel(item.source));
  if (showAction && item.actionLabel) tags.push(item.actionLabel);
  const head = `\`${tags.join("｜")}\`：${item.title}`;
  const details = joinParts([item.summary, item.meta]);
  return details ? `${head}；${details}` : head;
}

function sourceLabel(source) {
  if (source === "calendar") return "日历";
  if (source === "mail") return "邮件";
  if (source === "followup") return "跟进";
  return "系统";
}

function normalizePriority(value, fallback) {
  const number = Number(value);
  if (Number.isFinite(number) && number >= 1 && number <= 3) {
    return number;
  }
  return fallback;
}

function comparePriority(a, b) {
  return a.priority - b.priority || a.title.localeCompare(b.title, "zh-CN");
}

function joinParts(parts) {
  return parts.filter(Boolean).join("；");
}

function relative(filePath) {
  return path.relative(cwd, filePath);
}

function formatDate(value) {
  const year = value.getFullYear();
  const month = `${value.getMonth() + 1}`.padStart(2, "0");
  const day = `${value.getDate()}`.padStart(2, "0");
  return `${year}-${month}-${day}`;
}
