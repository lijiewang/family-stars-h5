alter table public.badges
  add column if not exists bonus_stars int not null default 0 check (bonus_stars >= 0),
  add column if not exists bonus_note text;

with family as (
  select id
  from public.families
  where invite_code = 'PIPI-MANMAN'
)
update public.summer_task_templates task
set is_active = false
from family
where task.family_id = family.id
  and task.task_key in (
    'summer_homework_am',
    'summer_homework_pm',
    'space_project',
    'essay_project',
    'young_pioneer'
  );

with family as (
  select id
  from public.families
  where invite_code = 'PIPI-MANMAN'
),
task_seed as (
  select 'summer_homework_daily' as task_key, '暑假作业每日练习' as name, '基础任务' as task_group, '学习' as category, 3 as reward_stars, '页' as metric_type, 4 as sort_order
  union all select 'sports_outdoor', '运动户外专项', '基础任务', '运动', 4, '组合', 6
  union all select 'essay_writing', '写作文', '暑假专项', '学习', 2, '步骤', 13
  union all select 'chinese_preview_grade4', '四年级上语文预习', '暑假专项', '学习', 2, '课', 14
  union all select 'math_preview_grade4', '数学预习', '暑假专项', '学习', 2, '单元', 15
)
update public.summer_task_templates task
set
  name = task_seed.name,
  task_group = task_seed.task_group,
  category = task_seed.category,
  reward_stars = task_seed.reward_stars,
  metric_type = task_seed.metric_type,
  sort_order = task_seed.sort_order,
  is_active = true
from family, task_seed
where task.family_id = family.id
  and task.child_id is null
  and task.task_key = task_seed.task_key;

with family as (
  select id
  from public.families
  where invite_code = 'PIPI-MANMAN'
),
task_seed as (
  select 'summer_homework_daily' as task_key, '暑假作业每日练习' as name, '基础任务' as task_group, '学习' as category, 3 as reward_stars, '页' as metric_type, 4 as sort_order
  union all select 'sports_outdoor', '运动户外专项', '基础任务', '运动', 4, '组合', 6
  union all select 'essay_writing', '写作文', '暑假专项', '学习', 2, '步骤', 13
  union all select 'chinese_preview_grade4', '四年级上语文预习', '暑假专项', '学习', 2, '课', 14
  union all select 'math_preview_grade4', '数学预习', '暑假专项', '学习', 2, '单元', 15
)
insert into public.summer_task_templates (
  family_id,
  task_key,
  name,
  task_group,
  category,
  reward_stars,
  metric_type,
  sort_order,
  child_id,
  is_active
)
select
  family.id,
  task_seed.task_key,
  task_seed.name,
  task_seed.task_group,
  task_seed.category,
  task_seed.reward_stars,
  task_seed.metric_type,
  task_seed.sort_order,
  null,
  true
from family
cross join task_seed
where not exists (
  select 1
  from public.summer_task_templates existing
  where existing.family_id = family.id
    and existing.child_id is null
    and existing.task_key = task_seed.task_key
);

with family as (
  select id
  from public.families
  where invite_code = 'PIPI-MANMAN'
),
badge_seed as (
  select 'morning-run' as badge_group, '晨跑小飞船 Lv1' as name, '晨跑累计 150 分钟。' as description, 'badge-morning-run' as icon_key, 1 as level, 'summer_metric_combo' as rule_type, 150 as rule_value, '运动' as category, '{"morning_run_minutes":150}'::jsonb as rule_config, 142 as sort_order
  union all select 'morning-run', '晨跑小飞船 Lv2', '晨跑累计 300 分钟。', 'badge-morning-run', 2, 'summer_metric_combo', 300, '运动', '{"morning_run_minutes":300}'::jsonb, 143
  union all select 'morning-run', '晨跑小飞船 Lv3', '晨跑累计 600 分钟。', 'badge-morning-run', 3, 'summer_metric_combo', 600, '运动', '{"morning_run_minutes":600}'::jsonb, 144
  union all select 'jump-rope', '跳绳火箭 Lv1', '跳绳累计 3000 个。', 'badge-jump-rope', 1, 'summer_metric_combo', 3000, '运动', '{"jump_rope_count":3000}'::jsonb, 145
  union all select 'jump-rope', '跳绳火箭 Lv2', '跳绳累计 6000 个。', 'badge-jump-rope', 2, 'summer_metric_combo', 6000, '运动', '{"jump_rope_count":6000}'::jsonb, 146
  union all select 'jump-rope', '跳绳火箭 Lv3', '跳绳累计 12000 个。', 'badge-jump-rope', 3, 'summer_metric_combo', 12000, '运动', '{"jump_rope_count":12000}'::jsonb, 147
  union all select 'sit-up', '核心能量 Lv1', '仰卧起坐累计 500 个。', 'badge-sit-up', 1, 'summer_metric_combo', 500, '运动', '{"sit_up_count":500}'::jsonb, 148
  union all select 'sit-up', '核心能量 Lv2', '仰卧起坐累计 1000 个。', 'badge-sit-up', 2, 'summer_metric_combo', 1000, '运动', '{"sit_up_count":1000}'::jsonb, 149
  union all select 'sit-up', '核心能量 Lv3', '仰卧起坐累计 2000 个。', 'badge-sit-up', 3, 'summer_metric_combo', 2000, '运动', '{"sit_up_count":2000}'::jsonb, 150
  union all select 'push-up', '俯卧撑勇士 Lv1', '俯卧撑累计 75 个。', 'badge-push-up', 1, 'summer_metric_combo', 75, '运动', '{"push_up_count":75}'::jsonb, 151
  union all select 'push-up', '俯卧撑勇士 Lv2', '俯卧撑累计 150 个。', 'badge-push-up', 2, 'summer_metric_combo', 150, '运动', '{"push_up_count":150}'::jsonb, 152
  union all select 'push-up', '俯卧撑勇士 Lv3', '俯卧撑累计 300 个。', 'badge-push-up', 3, 'summer_metric_combo', 300, '运动', '{"push_up_count":300}'::jsonb, 153
)
insert into public.badges (
  family_id,
  name,
  description,
  icon_key,
  rule_type,
  rule_value,
  category,
  badge_group,
  level,
  rule_config,
  sort_order,
  is_active
)
select
  family.id,
  badge_seed.name,
  badge_seed.description,
  badge_seed.icon_key,
  badge_seed.rule_type,
  badge_seed.rule_value,
  badge_seed.category,
  badge_seed.badge_group,
  badge_seed.level,
  badge_seed.rule_config,
  badge_seed.sort_order,
  true
from family
cross join badge_seed
on conflict (family_id, name) do update set
  description = excluded.description,
  icon_key = excluded.icon_key,
  rule_type = excluded.rule_type,
  rule_value = excluded.rule_value,
  category = excluded.category,
  badge_group = excluded.badge_group,
  level = excluded.level,
  rule_config = excluded.rule_config,
  sort_order = excluded.sort_order,
  is_active = true;

with family as (
  select id
  from public.families
  where invite_code = 'PIPI-MANMAN'
)
select public.award_badges_for_child(family.id, children.id) as inserted_badges
from family
join public.children on children.family_id = family.id;

with family as (
  select id
  from public.families
  where invite_code = 'PIPI-MANMAN'
)
select
  (select count(*) from public.summer_task_templates t join family f on f.id = t.family_id where t.task_key in ('summer_homework_daily', 'essay_writing', 'chinese_preview_grade4', 'math_preview_grade4') and t.is_active = true) as updated_tasks_count,
  (select count(*) from public.badges b join family f on f.id = b.family_id where b.badge_group in ('morning-run', 'jump-rope', 'sit-up', 'push-up')) as sports_badges_count;
