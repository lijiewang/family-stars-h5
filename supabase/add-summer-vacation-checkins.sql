alter table public.badges
  add column if not exists badge_group text,
  add column if not exists level int not null default 1 check (level >= 1 and level <= 3),
  add column if not exists rule_config jsonb not null default '{}'::jsonb;

create table if not exists public.summer_task_templates (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  child_id uuid references public.children(id) on delete cascade,
  task_key text not null,
  name text not null,
  task_group text not null default '基础任务',
  category text not null default '学习',
  reward_stars int not null default 2 check (reward_stars >= 2 and reward_stars <= 5),
  metric_type text,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (family_id, child_id, task_key)
);

create table if not exists public.summer_task_checkins (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  task_template_id uuid not null references public.summer_task_templates(id) on delete cascade,
  checkin_date date not null,
  completed boolean not null default false,
  metric_value numeric,
  metric_data jsonb not null default '{}'::jsonb,
  awarded_stars int not null default 2 check (awarded_stars >= 2 and awarded_stars <= 5),
  note text,
  guardian_id uuid not null references public.guardians(id),
  star_record_id uuid references public.star_records(id) on delete set null,
  invalidated_at timestamptz,
  invalidated_by uuid references public.guardians(id),
  invalidated_note text,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (family_id, child_id, task_template_id, checkin_date)
);

create table if not exists public.summer_projects (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  project_key text not null,
  name text not null,
  target_count numeric not null default 100,
  unit text not null default '%',
  progress_value numeric not null default 0 check (progress_value >= 0),
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (family_id, project_key)
);

create table if not exists public.summer_project_updates (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  project_id uuid not null references public.summer_projects(id) on delete cascade,
  guardian_id uuid not null references public.guardians(id),
  progress_value numeric not null check (progress_value >= 0),
  note text,
  created_by uuid not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_summer_task_templates_family on public.summer_task_templates(family_id, sort_order);
create index if not exists idx_summer_task_templates_child on public.summer_task_templates(child_id, sort_order);
create index if not exists idx_summer_task_checkins_child_date on public.summer_task_checkins(child_id, checkin_date desc);
create index if not exists idx_summer_projects_family on public.summer_projects(family_id, sort_order);
create index if not exists idx_summer_project_updates_project on public.summer_project_updates(project_id, created_at desc);

drop trigger if exists set_summer_task_templates_updated_at on public.summer_task_templates;
create trigger set_summer_task_templates_updated_at
before update on public.summer_task_templates
for each row execute function public.set_updated_at();

drop trigger if exists set_summer_task_checkins_updated_at on public.summer_task_checkins;
create trigger set_summer_task_checkins_updated_at
before update on public.summer_task_checkins
for each row execute function public.set_updated_at();

drop trigger if exists set_summer_projects_updated_at on public.summer_projects;
create trigger set_summer_projects_updated_at
before update on public.summer_projects
for each row execute function public.set_updated_at();

create or replace function public.save_summer_task_checkin(
  p_family_id uuid,
  p_child_id uuid,
  p_guardian_id uuid,
  p_task_template_id uuid,
  p_checkin_date date,
  p_completed boolean,
  p_award_stars int default 2,
  p_metric_value numeric default null,
  p_metric_data jsonb default '{}'::jsonb,
  p_note text default null
)
returns public.summer_task_checkins
language plpgsql
security definer
set search_path = public
as $$
declare
  target_task public.summer_task_templates%rowtype;
  old_checkin public.summer_task_checkins%rowtype;
  saved_checkin public.summer_task_checkins%rowtype;
  new_star_record public.star_records%rowtype;
  metric_text text;
begin
  if not public.is_family_member(p_family_id) then
    raise exception '没有访问这个家庭空间的权限';
  end if;

  if p_award_stars < 2 or p_award_stars > 5 then
    raise exception '暑期打卡奖励星请填写 2 到 5';
  end if;

  if not exists (
    select 1 from public.children
    where id = p_child_id and family_id = p_family_id
  ) then
    raise exception '孩子不存在';
  end if;

  if not exists (
    select 1 from public.guardians
    where id = p_guardian_id and family_id = p_family_id and is_active = true
  ) then
    raise exception '操作人不存在或已停用';
  end if;

  select *
  into target_task
  from public.summer_task_templates
  where id = p_task_template_id
    and family_id = p_family_id
    and is_active = true;

  if target_task.id is null then
    raise exception '暑期任务不存在或已停用';
  end if;

  select *
  into old_checkin
  from public.summer_task_checkins
  where family_id = p_family_id
    and child_id = p_child_id
    and task_template_id = p_task_template_id
    and checkin_date = p_checkin_date
  for update;

  insert into public.summer_task_checkins (
    family_id,
    child_id,
    task_template_id,
    checkin_date,
    completed,
    metric_value,
    metric_data,
    awarded_stars,
    note,
    guardian_id,
    created_by
  )
  values (
    p_family_id,
    p_child_id,
    p_task_template_id,
    p_checkin_date,
    p_completed,
    p_metric_value,
    coalesce(p_metric_data, '{}'::jsonb),
    p_award_stars,
    nullif(trim(coalesce(p_note, '')), ''),
    p_guardian_id,
    auth.uid()
  )
  on conflict (family_id, child_id, task_template_id, checkin_date)
  do update set
    completed = excluded.completed,
    metric_value = excluded.metric_value,
    metric_data = excluded.metric_data,
    awarded_stars = case
      when public.summer_task_checkins.star_record_id is null then excluded.awarded_stars
      else public.summer_task_checkins.awarded_stars
    end,
    note = excluded.note,
    guardian_id = excluded.guardian_id
  returning * into saved_checkin;

  select string_agg(key || ':' || value, '，')
  into metric_text
  from jsonb_each_text(coalesce(p_metric_data, '{}'::jsonb));

  if p_completed
    and p_award_stars > 0
    and coalesce(old_checkin.completed, false) = false
  then
    select *
    into new_star_record
    from public.add_star_record(
      p_family_id,
      p_child_id,
      p_guardian_id,
      'praise',
      p_award_stars,
      target_task.category,
      concat(
        '暑期打卡完成：',
        target_task.name,
        coalesce('；数量：' || nullif(metric_text, ''), ''),
        coalesce('；' || nullif(trim(coalesce(p_note, '')), ''), '')
      )
    );

    update public.summer_task_checkins
    set star_record_id = new_star_record.id
    where id = saved_checkin.id
    returning * into saved_checkin;
  end if;

  if p_completed then
    insert into public.child_badges (family_id, child_id, badge_id)
    select p_family_id, p_child_id, b.id
    from public.badges b
    where b.family_id = p_family_id
      and b.is_active = true
      and b.rule_type = 'summer_task_count'
      and b.rule_config ->> 'task_key' = target_task.task_key
      and b.rule_value <= (
        select count(*)::int
        from public.summer_task_checkins c
        join public.summer_task_templates t on t.id = c.task_template_id
        where c.family_id = p_family_id
          and c.child_id = p_child_id
          and c.completed = true
          and t.task_key = target_task.task_key
      )
    on conflict (child_id, badge_id) do nothing;
  end if;

  return saved_checkin;
end;
$$;

create or replace function public.update_summer_project_progress(
  p_family_id uuid,
  p_project_id uuid,
  p_guardian_id uuid,
  p_progress_value numeric,
  p_note text default null
)
returns public.summer_projects
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_project public.summer_projects%rowtype;
begin
  if not public.is_family_member(p_family_id) then
    raise exception '没有访问这个家庭空间的权限';
  end if;

  if p_progress_value < 0 or p_progress_value > 100 then
    raise exception '专项进度请填写 0 到 100';
  end if;

  if not exists (
    select 1 from public.guardians
    where id = p_guardian_id and family_id = p_family_id and is_active = true
  ) then
    raise exception '操作人不存在或已停用';
  end if;

  update public.summer_projects
  set progress_value = p_progress_value
  where id = p_project_id
    and family_id = p_family_id
  returning * into updated_project;

  if updated_project.id is null then
    raise exception '暑期专项不存在';
  end if;

  insert into public.summer_project_updates (
    family_id,
    project_id,
    guardian_id,
    progress_value,
    note,
    created_by
  )
  values (
    p_family_id,
    p_project_id,
    p_guardian_id,
    p_progress_value,
    nullif(trim(coalesce(p_note, '')), ''),
    auth.uid()
  );

  return updated_project;
end;
$$;

create or replace function public.invalidate_summer_task_checkin(
  p_family_id uuid,
  p_checkin_id uuid,
  p_guardian_id uuid,
  p_note text default null
)
returns public.summer_task_checkins
language plpgsql
security definer
set search_path = public
as $$
declare
  target_checkin public.summer_task_checkins%rowtype;
  updated_checkin public.summer_task_checkins%rowtype;
begin
  if not public.is_family_member(p_family_id) then
    raise exception '没有访问这个家庭空间的权限';
  end if;

  if not exists (
    select 1 from public.guardians
    where id = p_guardian_id and family_id = p_family_id and is_active = true
  ) then
    raise exception '操作人不存在或已停用';
  end if;

  select *
  into target_checkin
  from public.summer_task_checkins
  where id = p_checkin_id
    and family_id = p_family_id
  for update;

  if target_checkin.id is null then
    raise exception '暑期打卡记录不存在';
  end if;

  if target_checkin.completed = false then
    raise exception '这条暑期打卡记录已经失效';
  end if;

  update public.children
  set
    available_stars = greatest(available_stars - coalesce(target_checkin.awarded_stars, 0), 0),
    lifetime_stars = greatest(lifetime_stars - coalesce(target_checkin.awarded_stars, 0), 0)
  where id = target_checkin.child_id
    and family_id = p_family_id;

  update public.summer_task_checkins
  set
    completed = false,
    star_record_id = null,
    invalidated_at = now(),
    invalidated_by = p_guardian_id,
    invalidated_note = nullif(trim(coalesce(p_note, '')), '')
  where id = target_checkin.id
  returning * into updated_checkin;

  return updated_checkin;
end;
$$;

alter table public.summer_task_templates enable row level security;
alter table public.summer_task_checkins enable row level security;
alter table public.summer_projects enable row level security;
alter table public.summer_project_updates enable row level security;

drop policy if exists "members can read summer task templates" on public.summer_task_templates;
create policy "members can read summer task templates"
on public.summer_task_templates for select
using (public.is_family_member(family_id));

drop policy if exists "members can read summer task checkins" on public.summer_task_checkins;
create policy "members can read summer task checkins"
on public.summer_task_checkins for select
using (public.is_family_member(family_id));

drop policy if exists "members can read summer projects" on public.summer_projects;
create policy "members can read summer projects"
on public.summer_projects for select
using (public.is_family_member(family_id));

drop policy if exists "members can read summer project updates" on public.summer_project_updates;
create policy "members can read summer project updates"
on public.summer_project_updates for select
using (public.is_family_member(family_id));

grant select on public.summer_task_templates to authenticated;
grant select on public.summer_task_checkins to authenticated;
grant select on public.summer_projects to authenticated;
grant select on public.summer_project_updates to authenticated;
grant execute on function public.save_summer_task_checkin(uuid, uuid, uuid, uuid, date, boolean, int, numeric, jsonb, text) to authenticated;
grant execute on function public.update_summer_project_progress(uuid, uuid, uuid, numeric, text) to authenticated;
grant execute on function public.invalidate_summer_task_checkin(uuid, uuid, uuid, text) to authenticated;

with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
insert into public.summer_task_templates (
  family_id,
  task_key,
  name,
  task_group,
  category,
  reward_stars,
  metric_type,
  sort_order
)
select id, 'morning_reading', '晨读', '基础任务', '学习', 2, '分钟', 1 from family
union all select id, 'handwriting', '练字', '基础任务', '学习', 2, '分钟', 2 from family
union all select id, 'math_drill', '数学口算与应用题', '基础任务', '学习', 3, '题', 3 from family
union all select id, 'summer_homework_am', '暑假作业上午段', '基础任务', '学习', 2, '分钟', 4 from family
union all select id, 'summer_homework_pm', '暑假作业下午段', '基础任务', '学习', 2, '分钟', 5 from family
union all select id, 'reading', '阅读 1 小时', '基础任务', '学习', 3, '分钟', 6 from family
union all select id, 'sports_outdoor', '运动户外', '基础任务', '运动', 3, '分钟', 7 from family
union all select id, 'english_checkin', '英语打卡', '基础任务', '学习', 2, '分钟', 8 from family
union all select id, 'housework', '家务劳动', '基础任务', '自理能力', 2, '次', 9 from family
union all select id, 'night_review', '睡前复盘', '基础任务', '学习', 2, '篇', 10 from family
union all select id, 'screen_control', '电子产品不超过 30 分钟', '基础任务', '自理能力', 2, '达成', 11 from family
union all select id, 'space_reading', '航天主题阅读', '暑假专项', '学习', 2, '分钟', 12 from family
union all select id, 'space_project', '航天实践作品', '暑假专项', '学习', 2, '步骤', 13 from family
union all select id, 'essay_project', '暑期主题征文推进', '暑假专项', '学习', 2, '步骤', 14 from family
union all select id, 'young_pioneer', '少先队实践推进', '暑假专项', '礼貌', 2, '步骤', 15 from family
union all select id, 'reading_output', '读书成果积累', '暑假专项', '学习', 2, '条', 16 from family
on conflict (family_id, task_key) do update set
  name = excluded.name,
  task_group = excluded.task_group,
  category = excluded.category,
  reward_stars = excluded.reward_stars,
  metric_type = excluded.metric_type,
  sort_order = excluded.sort_order,
  is_active = true;

with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
insert into public.summer_projects (
  family_id,
  project_key,
  name,
  target_count,
  unit,
  sort_order
)
select id, 'space_recommend_card', '航空航天书籍推荐卡', 100, '%', 1 from family
union all select id, 'space_experiment', '航天实验或模型作品', 100, '%', 2 from family
union all select id, 'summer_essay', '暑期主题征文', 100, '%', 3 from family
union all select id, 'young_pioneer_practice', '少先队实践成果', 100, '%', 4 from family
union all select id, 'reading_result', '读书记录/推荐卡/读后感', 100, '%', 5 from family
on conflict (family_id, project_key) do update set
  name = excluded.name,
  target_count = excluded.target_count,
  unit = excluded.unit,
  sort_order = excluded.sort_order,
  is_active = true;

with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
),
badge_seed as (
  select 'morning-reading' as badge_group, '晨读之星 Lv1' as name, '晨读累计 7 天或连续 3 天。' as description, 'badge-morning-reading' as icon_key, 1 as level, 'summer_task_count' as rule_type, 7 as rule_value, '学习' as category, '{"task_key":"morning_reading","streak":3,"count":7}'::jsonb as rule_config, 101 as sort_order
  union all select 'morning-reading', '晨读之星 Lv2', '晨读累计 15 天或连续 7 天。', 'badge-morning-reading', 2, 'summer_task_count', 15, '学习', '{"task_key":"morning_reading","streak":7,"count":15}'::jsonb, 102
  union all select 'morning-reading', '晨读之星 Lv3', '晨读累计 22 天或连续 12 天。', 'badge-morning-reading', 3, 'summer_task_count', 22, '学习', '{"task_key":"morning_reading","streak":12,"count":22}'::jsonb, 103
  union all select 'handwriting', '练字之星 Lv1', '练字累计 7 天或连续 3 天。', 'badge-handwriting', 1, 'summer_task_count', 7, '学习', '{"task_key":"handwriting","streak":3,"count":7}'::jsonb, 104
  union all select 'handwriting', '练字之星 Lv2', '练字累计 15 天或连续 7 天。', 'badge-handwriting', 2, 'summer_task_count', 15, '学习', '{"task_key":"handwriting","streak":7,"count":15}'::jsonb, 105
  union all select 'handwriting', '练字之星 Lv3', '练字累计 22 天或连续 12 天。', 'badge-handwriting', 3, 'summer_task_count', 22, '学习', '{"task_key":"handwriting","streak":12,"count":22}'::jsonb, 106
  union all select 'reading', '阅读之星 Lv1', '阅读 1 小时累计 5 天。', 'badge-reading', 1, 'summer_task_count', 5, '学习', '{"task_key":"reading","count":5}'::jsonb, 107
  union all select 'reading', '阅读之星 Lv2', '阅读 1 小时累计 10 天。', 'badge-reading', 2, 'summer_task_count', 10, '学习', '{"task_key":"reading","count":10}'::jsonb, 108
  union all select 'reading', '阅读之星 Lv3', '阅读 1 小时累计 30 天。', 'badge-reading', 3, 'summer_task_count', 30, '学习', '{"task_key":"reading","count":30}'::jsonb, 109
  union all select 'sports', '运动之星 Lv1', '跳绳 1000 个，仰卧起坐 200 个，登山 5 公里。', 'badge-summer-sports', 1, 'summer_metric_combo', 1, '运动', '{"jump_rope":1000,"sit_ups":200,"hike_km":5}'::jsonb, 110
  union all select 'sports', '运动之星 Lv2', '跳绳 5000 个，仰卧起坐 1000 个，登山 20 公里，骑车 40 公里。', 'badge-summer-sports', 2, 'summer_metric_combo', 2, '运动', '{"jump_rope":5000,"sit_ups":1000,"hike_km":20,"bike_km":40}'::jsonb, 111
  union all select 'sports', '运动之星 Lv3', '跳绳 20000 个，仰卧起坐 7500 个，登山 35 公里，骑车 100 公里，滑雪 2000 米。', 'badge-summer-sports', 3, 'summer_metric_combo', 3, '运动', '{"jump_rope":20000,"sit_ups":7500,"hike_km":35,"bike_km":100,"ski_meter":2000}'::jsonb, 112
  union all select 'english', '英语打卡之星 Lv1', '连续 1 周完成英语打卡。', 'badge-english', 1, 'summer_task_count', 7, '学习', '{"task_key":"english_checkin","streak":7}'::jsonb, 113
  union all select 'english', '英语打卡之星 Lv2', '连续 3 周完成英语打卡。', 'badge-english', 2, 'summer_task_count', 21, '学习', '{"task_key":"english_checkin","streak":21}'::jsonb, 114
  union all select 'english', '英语打卡之星 Lv3', '连续 8 周完成英语打卡。', 'badge-english', 3, 'summer_task_count', 56, '学习', '{"task_key":"english_checkin","streak":56}'::jsonb, 115
  union all select 'housework', '劳动小达人 Lv1', '完成家务劳动累计 7 天。', 'badge-housework', 1, 'summer_task_count', 7, '自理能力', '{"task_key":"housework","count":7}'::jsonb, 116
  union all select 'housework', '劳动小达人 Lv2', '完成家务劳动累计 15 天。', 'badge-housework', 2, 'summer_task_count', 15, '自理能力', '{"task_key":"housework","count":15}'::jsonb, 117
  union all select 'housework', '劳动小达人 Lv3', '完成家务劳动累计 30 天。', 'badge-housework', 3, 'summer_task_count', 30, '自理能力', '{"task_key":"housework","count":30}'::jsonb, 118
  union all select 'recording', '记录小达人 Lv1', '日记、小作文或睡前复盘累计 3 篇。', 'badge-recording', 1, 'summer_task_count', 3, '学习', '{"task_key":"night_review","count":3}'::jsonb, 119
  union all select 'recording', '记录小达人 Lv2', '日记、小作文或睡前复盘累计 10 篇。', 'badge-recording', 2, 'summer_task_count', 10, '学习', '{"task_key":"night_review","count":10}'::jsonb, 120
  union all select 'recording', '记录小达人 Lv3', '日记、小作文或睡前复盘累计 30 篇。', 'badge-recording', 3, 'summer_task_count', 30, '学习', '{"task_key":"night_review","count":30}'::jsonb, 121
  union all select 'quality', '质量之星 Lv1', '累计 5 天任务质量较好。', 'badge-quality', 1, 'summer_quality_days', 5, null, '{"count":5}'::jsonb, 122
  union all select 'quality', '质量之星 Lv2', '累计 10 天任务质量较好。', 'badge-quality', 2, 'summer_quality_days', 10, null, '{"count":10}'::jsonb, 123
  union all select 'quality', '质量之星 Lv3', '累计 30 天任务质量较好。', 'badge-quality', 3, 'summer_quality_days', 30, null, '{"count":30}'::jsonb, 124
  union all select 'math', '解题之星 Lv1', '口算 500 道且应用题 30 道。', 'badge-math', 1, 'summer_metric_combo', 1, '学习', '{"oral_math":500,"word_problems":30}'::jsonb, 125
  union all select 'math', '解题之星 Lv2', '口算 1000 道且应用题 60 道。', 'badge-math', 2, 'summer_metric_combo', 2, '学习', '{"oral_math":1000,"word_problems":60}'::jsonb, 126
  union all select 'math', '解题之星 Lv3', '口算 1500 道且应用题 120 道。', 'badge-math', 3, 'summer_metric_combo', 3, '学习', '{"oral_math":1500,"word_problems":120}'::jsonb, 127
  union all select 'winning-streak', '连胜之星 Lv1', '基础任务连续完成 1 周。', 'badge-winning-streak', 1, 'summer_week_completion', 1, null, '{"weeks":1}'::jsonb, 128
  union all select 'winning-streak', '连胜之星 Lv2', '基础任务连续完成 3 周。', 'badge-winning-streak', 2, 'summer_week_completion', 3, null, '{"weeks":3}'::jsonb, 129
  union all select 'winning-streak', '连胜之星 Lv3', '基础任务连续完成 8 周。', 'badge-winning-streak', 3, 'summer_week_completion', 8, null, '{"weeks":8}'::jsonb, 130
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
  sort_order
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
  badge_seed.sort_order
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

select
  (select count(*) from public.summer_task_templates t join public.families f on f.id = t.family_id where f.invite_code = 'PIPI-MANMAN') as summer_task_count,
  (select count(*) from public.summer_projects p join public.families f on f.id = p.family_id where f.invite_code = 'PIPI-MANMAN') as summer_project_count,
  (select count(*) from public.badges b join public.families f on f.id = b.family_id where f.invite_code = 'PIPI-MANMAN' and b.badge_group is not null) as summer_badge_count;
