alter table public.badges
  add column if not exists bonus_stars int not null default 0 check (bonus_stars >= 0),
  add column if not exists bonus_note text;

alter table public.star_records
  drop constraint if exists star_records_stars_check;

alter table public.star_records
  add constraint star_records_stars_check check (stars > 0 and stars <= 999);

with family as (
  select id
  from public.families
  where invite_code = 'PIPI-MANMAN'
),
badge_seed as (
  select 'currency-moon' as badge_group, '明亮之星' as name, '累计获得 30 个月亮。达成后系统自动奖励 5 颗星。' as description, 'badge-currency-moon' as icon_key, 1 as level, 'lifetime_currency_count' as rule_type, 30 as rule_value, null::text as category, '{"currency":"moon","count":30}'::jsonb as rule_config, 5 as bonus_stars, 131 as sort_order
  union all select 'currency-sun', '烈日之星', '累计获得 30 个太阳。达成后系统自动奖励 10 颗星。', 'badge-currency-sun', 1, 'lifetime_currency_count', 30, null::text, '{"currency":"sun","count":30}'::jsonb, 10, 132
  union all select 'currency-sun', '夸父逐日', '累计获得 60 个太阳。达成后系统自动奖励 20 颗星。', 'badge-currency-sun', 2, 'lifetime_currency_count', 60, null::text, '{"currency":"sun","count":60}'::jsonb, 20, 133
  union all select 'currency-sun', '逐日火神', '累计获得 100 个太阳。达成后系统自动奖励 35 颗星。', 'badge-currency-sun', 3, 'lifetime_currency_count', 100, null::text, '{"currency":"sun","count":100}'::jsonb, 35, 134
  union all select 'currency-bronze', '满天铜板', '累计获得 100 个铜币。达成后系统自动奖励 60 颗星。', 'badge-currency-bronze', 1, 'lifetime_currency_count', 100, null::text, '{"currency":"bronze","count":100}'::jsonb, 60, 135
  union all select 'currency-bronze', '铜板富翁', '累计获得 120 个铜币。达成后系统自动奖励 100 颗星。', 'badge-currency-bronze', 2, 'lifetime_currency_count', 120, null::text, '{"currency":"bronze","count":120}'::jsonb, 100, 136
  union all select 'currency-silver', '碎银漫天', '累计获得 140 个银币。达成后系统自动奖励 200 颗星。', 'badge-currency-silver', 1, 'lifetime_currency_count', 140, null::text, '{"currency":"silver","count":140}'::jsonb, 200, 137
  union all select 'currency-silver', '碎银富翁', '累计获得 160 个银币。达成后系统自动奖励 230 颗星。', 'badge-currency-silver', 2, 'lifetime_currency_count', 160, null::text, '{"currency":"silver","count":160}'::jsonb, 230, 138
  union all select 'currency-gold', '金碧辉煌', '累计获得 180 个金币。达成后系统自动奖励 400 颗星。', 'badge-currency-gold', 1, 'lifetime_currency_count', 180, null::text, '{"currency":"gold","count":180}'::jsonb, 400, 139
  union all select 'currency-gold', '金钱皇后', '累计获得 200 个金币。达成后系统自动奖励 430 颗星。', 'badge-currency-gold', 2, 'lifetime_currency_count', 200, null::text, '{"currency":"gold","count":200}'::jsonb, 430, 140
  union all select 'currency-diamond', '钻石大王', '累计获得 220 个钻石。达成后系统自动奖励 500 颗星。', 'badge-currency-diamond', 1, 'lifetime_currency_count', 220, null::text, '{"currency":"diamond","count":220}'::jsonb, 500, 141
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
  bonus_stars,
  bonus_note,
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
  badge_seed.bonus_stars,
  concat('达成「', badge_seed.name, '」自动奖励 ', badge_seed.bonus_stars, ' 颗星'),
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
  bonus_stars = excluded.bonus_stars,
  bonus_note = excluded.bonus_note,
  sort_order = excluded.sort_order,
  is_active = true;

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
        b.rule_type = 'lifetime_currency_count'
        and b.rule_value <= floor((
          select greatest(lifetime_stars, available_stars)
          from public.children
          where id = p_child_id and family_id = p_family_id
        ) / (
          case b.rule_config ->> 'currency'
            when 'moon' then 5
            when 'sun' then 15
            when 'bronze' then 30
            when 'silver' then 60
            when 'gold' then 120
            when 'diamond' then 240
            else 1
          end
        ))
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

  bonus := coalesce(nullif(badge_row.bonus_stars, 0), case coalesce(badge_row.level, 0)
    when 1 then 1
    when 2 then 3
    when 3 then 6
    else 0
  end);

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

grant execute on function public.award_badges_for_child(uuid, uuid) to authenticated;

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
  (select count(*) from public.badges b join family f on f.id = b.family_id where b.rule_type = 'lifetime_currency_count') as currency_badges_count;
