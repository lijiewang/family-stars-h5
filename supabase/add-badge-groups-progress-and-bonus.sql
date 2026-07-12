alter table public.child_badges
  add column if not exists bonus_stars int not null default 0,
  add column if not exists bonus_star_record_id uuid references public.star_records(id) on delete set null;

create or replace function public.summer_metric_total(
  p_family_id uuid,
  p_child_id uuid,
  p_metric_key text
)
returns numeric
language sql
stable
set search_path = public
as $$
  select coalesce(sum(
    case p_metric_key
      when 'oral_math' then coalesce((c.metric_data ->> 'oral_math_count')::numeric, 0)
      when 'word_problems' then coalesce((c.metric_data ->> 'word_problem_count')::numeric, 0)
      when 'jump_rope' then coalesce((c.metric_data ->> 'jump_rope_count')::numeric, 0)
      when 'sit_ups' then coalesce((c.metric_data ->> 'sit_up_count')::numeric, 0)
      else coalesce((c.metric_data ->> p_metric_key)::numeric, 0)
    end
  ), 0)
  from public.summer_task_checkins c
  where c.family_id = p_family_id
    and c.child_id = p_child_id
    and c.completed = true;
$$;

create or replace function public.summer_task_completed_count(
  p_family_id uuid,
  p_child_id uuid,
  p_task_key text
)
returns int
language sql
stable
set search_path = public
as $$
  select count(*)::int
  from public.summer_task_checkins c
  join public.summer_task_templates t on t.id = c.task_template_id
  where c.family_id = p_family_id
    and c.child_id = p_child_id
    and c.completed = true
    and t.task_key = p_task_key;
$$;

create or replace function public.summer_task_max_streak(
  p_family_id uuid,
  p_child_id uuid,
  p_task_key text
)
returns int
language sql
stable
set search_path = public
as $$
  with dates as (
    select distinct c.checkin_date
    from public.summer_task_checkins c
    join public.summer_task_templates t on t.id = c.task_template_id
    where c.family_id = p_family_id
      and c.child_id = p_child_id
      and c.completed = true
      and t.task_key = p_task_key
  ),
  numbered as (
    select
      checkin_date,
      checkin_date - (row_number() over (order by checkin_date))::int as streak_group
    from dates
  )
  select coalesce(max(streak_count), 0)::int
  from (
    select count(*) as streak_count
    from numbered
    group by streak_group
  ) streaks;
$$;

create or replace function public.summer_quality_days(
  p_family_id uuid,
  p_child_id uuid
)
returns int
language sql
stable
set search_path = public
as $$
  select count(*)::int
  from public.summer_task_checkins c
  where c.family_id = p_family_id
    and c.child_id = p_child_id
    and c.completed = true
    and coalesce(c.note, '') ~ '(质量好|认真|主动|优秀|高质量)';
$$;

create or replace function public.completed_summer_weeks(
  p_family_id uuid,
  p_child_id uuid
)
returns int
language sql
stable
set search_path = public
as $$
  with base_tasks as (
    select id
    from public.summer_task_templates
    where family_id = p_family_id
      and is_active = true
      and task_group = '基础任务'
      and (child_id is null or child_id = p_child_id)
  ),
  completed_by_week as (
    select
      date_trunc('week', c.checkin_date)::date as week_start,
      count(distinct c.task_template_id)::int as completed_count
    from public.summer_task_checkins c
    where c.family_id = p_family_id
      and c.child_id = p_child_id
      and c.completed = true
      and c.task_template_id in (select id from base_tasks)
    group by date_trunc('week', c.checkin_date)::date
  )
  select count(*)::int
  from completed_by_week
  where completed_count >= (select count(*) from base_tasks);
$$;

create or replace function public.award_badges_for_child(
  p_family_id uuid,
  p_child_id uuid
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count int := 0;
begin
  insert into public.child_badges (family_id, child_id, badge_id)
  select p_family_id, p_child_id, b.id
  from public.badges b
  where b.family_id = p_family_id
    and b.is_active = true
    and (
      (
        b.rule_type = 'lifetime_stars'
        and b.rule_value <= (
          select greatest(lifetime_stars, available_stars)
          from public.children
          where id = p_child_id and family_id = p_family_id
        )
      )
      or (
        b.rule_type = 'category_positive_stars'
        and b.rule_value <= (
          select coalesce(sum(stars), 0)
          from public.star_records
          where family_id = p_family_id
            and child_id = p_child_id
            and type = 'praise'
            and category = b.category
        )
      )
      or (
        b.rule_type = 'category_positive_count'
        and b.rule_value <= (
          select count(*)::int
          from public.star_records
          where family_id = p_family_id
            and child_id = p_child_id
            and type = 'praise'
            and category = b.category
        )
      )
      or (
        b.rule_type = 'summer_task_count'
        and (
          (
            b.rule_config ? 'count'
            and public.summer_task_completed_count(p_family_id, p_child_id, b.rule_config ->> 'task_key') >= (b.rule_config ->> 'count')::int
          )
          or (
            b.rule_config ? 'streak'
            and public.summer_task_max_streak(p_family_id, p_child_id, b.rule_config ->> 'task_key') >= (b.rule_config ->> 'streak')::int
          )
          or (
            not (b.rule_config ? 'count')
            and not (b.rule_config ? 'streak')
            and public.summer_task_completed_count(p_family_id, p_child_id, b.rule_config ->> 'task_key') >= b.rule_value
          )
        )
      )
      or (
        b.rule_type = 'summer_metric_combo'
        and not exists (
          select 1
          from jsonb_each_text(coalesce(b.rule_config, '{}'::jsonb)) rule_item(metric_key, target_value)
          where public.summer_metric_total(p_family_id, p_child_id, rule_item.metric_key) < rule_item.target_value::numeric
        )
      )
      or (
        b.rule_type = 'summer_quality_days'
        and public.summer_quality_days(p_family_id, p_child_id) >= coalesce((b.rule_config ->> 'count')::int, b.rule_value)
      )
      or (
        b.rule_type = 'summer_week_completion'
        and public.completed_summer_weeks(p_family_id, p_child_id) >= coalesce((b.rule_config ->> 'weeks')::int, b.rule_value)
      )
    )
  on conflict (child_id, badge_id) do nothing;

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

create or replace function public.award_badge_bonus_stars()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  badge_row public.badges%rowtype;
  bonus int := 0;
  guardian_id uuid;
  new_record public.star_records%rowtype;
  next_title text;
begin
  select * into badge_row
  from public.badges
  where id = new.badge_id;

  if badge_row.badge_group is null then
    return new;
  end if;

  bonus := case coalesce(badge_row.level, 0)
    when 1 then 1
    when 2 then 3
    when 3 then 6
    else 0
  end;

  if bonus <= 0 then
    return new;
  end if;

  select id into guardian_id
  from public.guardians
  where family_id = new.family_id
    and is_active = true
  order by sort_order asc
  limit 1;

  if guardian_id is null then
    return new;
  end if;

  insert into public.star_records (
    family_id,
    child_id,
    guardian_id,
    type,
    stars,
    category,
    reason,
    created_by
  )
  values (
    new.family_id,
    new.child_id,
    guardian_id,
    'praise',
    bonus,
    '勋章',
    concat('自动奖励：获得「', badge_row.name, '」，奖励 ', bonus, ' 颗星'),
    coalesce(auth.uid(), (select user_id from public.family_members where family_id = new.family_id limit 1))
  )
  returning * into new_record;

  update public.children
  set
    available_stars = available_stars + bonus,
    lifetime_stars = lifetime_stars + bonus
  where id = new.child_id
    and family_id = new.family_id;

  select title
  into next_title
  from public.title_rules
  where family_id = new.family_id
    and required_lifetime_stars <= (
      select lifetime_stars from public.children where id = new.child_id
    )
  order by required_lifetime_stars desc
  limit 1;

  if next_title is not null then
    update public.children
    set current_title = next_title
    where id = new.child_id and family_id = new.family_id;
  end if;

  update public.child_badges
  set
    bonus_stars = bonus,
    bonus_star_record_id = new_record.id
  where id = new.id;

  perform public.award_badges_for_child(new.family_id, new.child_id);

  return new;
end;
$$;

drop trigger if exists award_badge_bonus_stars on public.child_badges;
create trigger award_badge_bonus_stars
after insert on public.child_badges
for each row execute function public.award_badge_bonus_stars();

create or replace function public.refresh_child_badges_from_star_record()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.type = 'praise' then
    perform public.award_badges_for_child(new.family_id, new.child_id);
  end if;
  return new;
end;
$$;

drop trigger if exists refresh_child_badges_from_star_record on public.star_records;
create trigger refresh_child_badges_from_star_record
after insert or update of category on public.star_records
for each row execute function public.refresh_child_badges_from_star_record();

create or replace function public.refresh_child_badges_from_summer_checkin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.completed = true then
    perform public.award_badges_for_child(new.family_id, new.child_id);
  end if;
  return new;
end;
$$;

drop trigger if exists refresh_child_badges_from_summer_checkin on public.summer_task_checkins;
create trigger refresh_child_badges_from_summer_checkin
after insert or update of completed, metric_data, metric_value on public.summer_task_checkins
for each row execute function public.refresh_child_badges_from_summer_checkin();

grant execute on function public.award_badges_for_child(uuid, uuid) to authenticated;
