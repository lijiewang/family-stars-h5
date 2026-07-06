alter table public.summer_task_templates
  add column if not exists child_id uuid references public.children(id) on delete cascade;

alter table public.summer_task_templates
  drop constraint if exists summer_task_templates_family_id_task_key_key;

create unique index if not exists summer_task_templates_family_child_task_key
on public.summer_task_templates (family_id, child_id, task_key);

create index if not exists idx_summer_task_templates_child
on public.summer_task_templates (child_id, sort_order);

with target as (
  select f.id as family_id, c.id as child_id
  from public.families f
  join public.children c on c.family_id = f.id
  where f.invite_code = 'PIPI-MANMAN'
    and c.name = '一杉'
)
insert into public.summer_task_templates (
  family_id,
  child_id,
  task_key,
  name,
  task_group,
  category,
  reward_stars,
  metric_type,
  sort_order,
  is_active
)
select family_id, child_id, 'yishan_self_meal', '自主吃饭', '行为习惯', '自理能力', 2, '次', 1, true from target
union all select family_id, child_id, 'yishan_self_play', '自主玩耍', '行为习惯', '自理能力', 2, '分钟', 2, true from target
union all select family_id, child_id, 'yishan_self_dress', '自主穿衣', '行为习惯', '自理能力', 2, '次', 3, true from target
union all select family_id, child_id, 'yishan_sofa_tidy', '不弄乱沙发', '行为习惯', '整理', 2, '达成', 4, true from target
union all select family_id, child_id, 'yishan_quiet_for_brother', '不吵闹哥哥写作业', '行为习惯', '兄弟互动', 2, '达成', 5, true from target
union all select family_id, child_id, 'yishan_screen_control', '电子产品不超过 30 分钟', '行为习惯', '自理能力', 2, '分钟', 6, true from target
union all select family_id, child_id, 'yishan_outdoor_sports', '户外运动 2 小时', '行为习惯', '运动', 3, '分钟', 7, true from target
union all select family_id, child_id, 'yishan_character_learning', '识字 5 个', '知识启蒙', '学习', 2, '个', 8, true from target
union all select family_id, child_id, 'yishan_poem_recitation', '经典诵读诗词 1 首', '知识启蒙', '学习', 2, '首', 9, true from target
union all select family_id, child_id, 'yishan_english_lesson', '英语学习 1 课', '知识启蒙', '学习', 2, '课', 10, true from target
on conflict (family_id, child_id, task_key) do update set
  name = excluded.name,
  task_group = excluded.task_group,
  category = excluded.category,
  reward_stars = excluded.reward_stars,
  metric_type = excluded.metric_type,
  sort_order = excluded.sort_order,
  is_active = true;

select
  c.name as child_name,
  count(t.id) as yishan_task_count
from public.children c
left join public.summer_task_templates t on t.child_id = c.id and t.is_active = true
join public.families f on f.id = c.family_id
where f.invite_code = 'PIPI-MANMAN'
  and c.name = '一杉'
group by c.name;
