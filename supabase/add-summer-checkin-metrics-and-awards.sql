alter table public.summer_task_templates
  alter column reward_stars set default 2;

update public.summer_task_templates
set reward_stars = 2
where reward_stars < 2;

alter table public.summer_task_templates
  drop constraint if exists summer_task_templates_reward_stars_check;

alter table public.summer_task_templates
  add constraint summer_task_templates_reward_stars_check
  check (reward_stars >= 2 and reward_stars <= 5);

alter table public.summer_task_checkins
  add column if not exists metric_data jsonb not null default '{}'::jsonb,
  add column if not exists awarded_stars int not null default 2 check (awarded_stars >= 2 and awarded_stars <= 5);

drop function if exists public.save_summer_task_checkin(uuid, uuid, uuid, uuid, date, boolean, numeric, text);

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

grant execute on function public.save_summer_task_checkin(uuid, uuid, uuid, uuid, date, boolean, int, numeric, jsonb, text) to authenticated;

with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
update public.summer_task_templates
set reward_stars = greatest(reward_stars, 2)
where family_id in (select id from family);

select
  count(*) filter (where reward_stars >= 2) as tasks_with_min_two_stars,
  count(*) as total_tasks
from public.summer_task_templates t
join public.families f on f.id = t.family_id
where f.invite_code = 'PIPI-MANMAN';
