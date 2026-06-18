create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text not null unique,
  admin_pin text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.children (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  nickname text,
  age int not null check (age >= 0),
  avatar_key text not null,
  theme_planet text not null,
  available_stars int not null default 0 check (available_stars >= 0),
  lifetime_stars int not null default 0 check (lifetime_stars >= 0),
  spent_stars int not null default 0 check (spent_stars >= 0),
  current_title text not null default '星球预备队员',
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (family_id, name)
);

create table if not exists public.guardians (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  role_key text not null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (family_id, role_key)
);

create table if not exists public.family_members (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null,
  guardian_id uuid not null references public.guardians(id),
  display_name text not null,
  joined_at timestamptz not null default now(),
  unique (family_id, user_id)
);

create table if not exists public.star_records (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  guardian_id uuid not null references public.guardians(id),
  type text not null check (type in ('praise', 'improvement')),
  stars int not null check (stars > 0 and stars <= 20),
  category text not null,
  reason text not null check (length(trim(reason)) > 0),
  created_by uuid not null,
  created_at timestamptz not null default now()
);

create table if not exists public.rewards (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  description text,
  cost_stars int not null check (cost_stars > 0),
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (family_id, name)
);

create table if not exists public.reward_redemptions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  guardian_id uuid not null references public.guardians(id),
  reward_id uuid references public.rewards(id) on delete set null,
  reward_name text not null,
  cost_stars int not null check (cost_stars > 0),
  note text,
  created_by uuid not null,
  created_at timestamptz not null default now()
);

create table if not exists public.badges (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  description text not null,
  icon_key text not null,
  rule_type text not null,
  rule_value int not null default 0,
  category text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (family_id, name)
);

create table if not exists public.child_badges (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  badge_id uuid not null references public.badges(id) on delete cascade,
  earned_at timestamptz not null default now(),
  unique (child_id, badge_id)
);

create table if not exists public.title_rules (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null,
  required_lifetime_stars int not null check (required_lifetime_stars >= 0),
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (family_id, title)
);

create table if not exists public.settings (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  key text not null,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  unique (family_id, key)
);

create index if not exists idx_children_family_id on public.children(family_id);
create index if not exists idx_guardians_family_id on public.guardians(family_id);
create index if not exists idx_family_members_user_id on public.family_members(user_id);
create index if not exists idx_star_records_family_created on public.star_records(family_id, created_at desc);
create index if not exists idx_star_records_child_created on public.star_records(child_id, created_at desc);
create index if not exists idx_reward_redemptions_family_created on public.reward_redemptions(family_id, created_at desc);
create index if not exists idx_child_badges_child_id on public.child_badges(child_id);

drop trigger if exists set_families_updated_at on public.families;
create trigger set_families_updated_at
before update on public.families
for each row execute function public.set_updated_at();

drop trigger if exists set_children_updated_at on public.children;
create trigger set_children_updated_at
before update on public.children
for each row execute function public.set_updated_at();

drop trigger if exists set_rewards_updated_at on public.rewards;
create trigger set_rewards_updated_at
before update on public.rewards
for each row execute function public.set_updated_at();

drop trigger if exists set_badges_updated_at on public.badges;
create trigger set_badges_updated_at
before update on public.badges
for each row execute function public.set_updated_at();

drop trigger if exists set_title_rules_updated_at on public.title_rules;
create trigger set_title_rules_updated_at
before update on public.title_rules
for each row execute function public.set_updated_at();

drop trigger if exists set_settings_updated_at on public.settings;
create trigger set_settings_updated_at
before update on public.settings
for each row execute function public.set_updated_at();

create or replace function public.is_family_member(target_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.family_members
    where family_id = target_family_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.join_family(
  p_invite_code text,
  p_guardian_role_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_family public.families%rowtype;
  target_guardian public.guardians%rowtype;
begin
  if auth.uid() is null then
    raise exception '请先创建匿名登录身份';
  end if;

  select *
  into target_family
  from public.families
  where invite_code = upper(trim(p_invite_code));

  if target_family.id is null then
    raise exception '家庭邀请码不存在';
  end if;

  select *
  into target_guardian
  from public.guardians
  where family_id = target_family.id
    and role_key = p_guardian_role_key
    and is_active = true;

  if target_guardian.id is null then
    raise exception '操作人不存在或已停用';
  end if;

  insert into public.family_members (family_id, user_id, guardian_id, display_name)
  values (target_family.id, auth.uid(), target_guardian.id, target_guardian.name)
  on conflict (family_id, user_id)
  do update set
    guardian_id = excluded.guardian_id,
    display_name = excluded.display_name;

  return jsonb_build_object(
    'family_id', target_family.id,
    'family_name', target_family.name,
    'guardian_id', target_guardian.id,
    'guardian_name', target_guardian.name,
    'guardian_role_key', target_guardian.role_key
  );
end;
$$;

create or replace function public.add_star_record(
  p_family_id uuid,
  p_child_id uuid,
  p_guardian_id uuid,
  p_type text,
  p_stars int,
  p_category text,
  p_reason text
)
returns public.star_records
language plpgsql
security definer
set search_path = public
as $$
declare
  new_record public.star_records%rowtype;
  next_title text;
  max_praise_stars int := 5;
  max_improvement_stars int := 3;
  daily_deduct_limit int := 5;
  already_deducted_today int := 0;
begin
  if not public.is_family_member(p_family_id) then
    raise exception '没有访问这个家庭空间的权限';
  end if;

  if p_type not in ('praise', 'improvement') then
    raise exception '记录类型不正确';
  end if;

  if p_stars <= 0 then
    raise exception '星星数量必须大于 0';
  end if;

  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception '必须填写原因';
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

  select coalesce((value #>> '{}')::int, 5)
  into max_praise_stars
  from public.settings
  where family_id = p_family_id and key = 'max_praise_stars';

  select coalesce((value #>> '{}')::int, 3)
  into max_improvement_stars
  from public.settings
  where family_id = p_family_id and key = 'max_improvement_stars';

  select coalesce((value #>> '{}')::int, 5)
  into daily_deduct_limit
  from public.settings
  where family_id = p_family_id and key = 'daily_deduct_limit';

  if p_type = 'praise' and p_stars > max_praise_stars then
    raise exception '单次加星超过上限';
  end if;

  if p_type = 'improvement' and p_stars > max_improvement_stars then
    raise exception '单次减星超过上限';
  end if;

  if p_type = 'improvement' then
    select coalesce(sum(stars), 0)
    into already_deducted_today
    from public.star_records
    where family_id = p_family_id
      and child_id = p_child_id
      and type = 'improvement'
      and created_at >= date_trunc('day', now());

    if already_deducted_today + p_stars > daily_deduct_limit then
      raise exception '今日减星超过上限';
    end if;
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
    p_family_id,
    p_child_id,
    p_guardian_id,
    p_type,
    p_stars,
    p_category,
    trim(p_reason),
    auth.uid()
  )
  returning * into new_record;

  if p_type = 'praise' then
    update public.children
    set
      available_stars = available_stars + p_stars,
      lifetime_stars = lifetime_stars + p_stars
    where id = p_child_id and family_id = p_family_id;

    select title
    into next_title
    from public.title_rules
    where family_id = p_family_id
      and required_lifetime_stars <= (
        select lifetime_stars from public.children where id = p_child_id
      )
    order by required_lifetime_stars desc
    limit 1;

    if next_title is not null then
      update public.children
      set current_title = next_title
      where id = p_child_id and family_id = p_family_id;
    end if;

    insert into public.child_badges (family_id, child_id, badge_id)
    select p_family_id, p_child_id, b.id
    from public.badges b
    where b.family_id = p_family_id
      and b.is_active = true
      and (
        (
          b.rule_type = 'lifetime_stars'
          and b.rule_value <= (
            select lifetime_stars from public.children where id = p_child_id
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
      )
    on conflict (child_id, badge_id) do nothing;
  else
    update public.children
    set available_stars = greatest(available_stars - p_stars, 0)
    where id = p_child_id and family_id = p_family_id;
  end if;

  return new_record;
end;
$$;

create or replace function public.redeem_reward(
  p_family_id uuid,
  p_child_id uuid,
  p_guardian_id uuid,
  p_reward_id uuid,
  p_note text default null
)
returns public.reward_redemptions
language plpgsql
security definer
set search_path = public
as $$
declare
  target_reward public.rewards%rowtype;
  child_available_stars int;
  new_redemption public.reward_redemptions%rowtype;
begin
  if not public.is_family_member(p_family_id) then
    raise exception '没有访问这个家庭空间的权限';
  end if;

  select *
  into target_reward
  from public.rewards
  where id = p_reward_id
    and family_id = p_family_id
    and is_active = true;

  if target_reward.id is null then
    raise exception '奖励不存在或已停用';
  end if;

  select available_stars
  into child_available_stars
  from public.children
  where id = p_child_id
    and family_id = p_family_id
  for update;

  if child_available_stars is null then
    raise exception '孩子不存在';
  end if;

  if child_available_stars < target_reward.cost_stars then
    raise exception '当前星星不足，不能兑换';
  end if;

  update public.children
  set
    available_stars = available_stars - target_reward.cost_stars,
    spent_stars = spent_stars + target_reward.cost_stars
  where id = p_child_id
    and family_id = p_family_id;

  insert into public.reward_redemptions (
    family_id,
    child_id,
    guardian_id,
    reward_id,
    reward_name,
    cost_stars,
    note,
    created_by
  )
  values (
    p_family_id,
    p_child_id,
    p_guardian_id,
    target_reward.id,
    target_reward.name,
    target_reward.cost_stars,
    p_note,
    auth.uid()
  )
  returning * into new_redemption;

  return new_redemption;
end;
$$;

alter table public.families enable row level security;
alter table public.children enable row level security;
alter table public.guardians enable row level security;
alter table public.family_members enable row level security;
alter table public.star_records enable row level security;
alter table public.rewards enable row level security;
alter table public.reward_redemptions enable row level security;
alter table public.badges enable row level security;
alter table public.child_badges enable row level security;
alter table public.title_rules enable row level security;
alter table public.settings enable row level security;

drop policy if exists "members can read their family" on public.families;
create policy "members can read their family"
on public.families for select
using (public.is_family_member(id));

drop policy if exists "members can read children" on public.children;
create policy "members can read children"
on public.children for select
using (public.is_family_member(family_id));

drop policy if exists "members can read guardians" on public.guardians;
create policy "members can read guardians"
on public.guardians for select
using (public.is_family_member(family_id));

drop policy if exists "members can read family members" on public.family_members;
create policy "members can read family members"
on public.family_members for select
using (public.is_family_member(family_id));

drop policy if exists "users can read own memberships" on public.family_members;
create policy "users can read own memberships"
on public.family_members for select
using (user_id = auth.uid());

drop policy if exists "users can update own memberships" on public.family_members;
create policy "users can update own memberships"
on public.family_members for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "members can read star records" on public.star_records;
create policy "members can read star records"
on public.star_records for select
using (public.is_family_member(family_id));

drop policy if exists "members can read rewards" on public.rewards;
create policy "members can read rewards"
on public.rewards for select
using (public.is_family_member(family_id));

drop policy if exists "members can manage rewards" on public.rewards;
create policy "members can manage rewards"
on public.rewards for all
using (public.is_family_member(family_id))
with check (public.is_family_member(family_id));

drop policy if exists "members can read reward redemptions" on public.reward_redemptions;
create policy "members can read reward redemptions"
on public.reward_redemptions for select
using (public.is_family_member(family_id));

drop policy if exists "members can read badges" on public.badges;
create policy "members can read badges"
on public.badges for select
using (public.is_family_member(family_id));

drop policy if exists "members can manage badges" on public.badges;
create policy "members can manage badges"
on public.badges for all
using (public.is_family_member(family_id))
with check (public.is_family_member(family_id));

drop policy if exists "members can read child badges" on public.child_badges;
create policy "members can read child badges"
on public.child_badges for select
using (public.is_family_member(family_id));

drop policy if exists "members can read title rules" on public.title_rules;
create policy "members can read title rules"
on public.title_rules for select
using (public.is_family_member(family_id));

drop policy if exists "members can manage title rules" on public.title_rules;
create policy "members can manage title rules"
on public.title_rules for all
using (public.is_family_member(family_id))
with check (public.is_family_member(family_id));

drop policy if exists "members can read settings" on public.settings;
create policy "members can read settings"
on public.settings for select
using (public.is_family_member(family_id));

drop policy if exists "members can manage settings" on public.settings;
create policy "members can manage settings"
on public.settings for all
using (public.is_family_member(family_id))
with check (public.is_family_member(family_id));

grant usage on schema public to anon, authenticated;
grant select on all tables in schema public to authenticated;
grant insert, update, delete on public.rewards to authenticated;
grant insert, update, delete on public.badges to authenticated;
grant insert, update, delete on public.title_rules to authenticated;
grant insert, update, delete on public.settings to authenticated;
grant execute on function public.join_family(text, text) to authenticated;
grant execute on function public.add_star_record(uuid, uuid, uuid, text, int, text, text) to authenticated;
grant execute on function public.redeem_reward(uuid, uuid, uuid, uuid, text) to authenticated;

with family as (
  insert into public.families (name, invite_code, admin_pin)
  values ('皮皮小满星球探险队', 'PIPI-MANMAN', '2468')
  on conflict (invite_code) do update set name = excluded.name
  returning id
)
insert into public.children (
  family_id,
  name,
  nickname,
  age,
  avatar_key,
  theme_planet,
  sort_order
)
select id, '皮皮', '皮皮', 9, 'rocket-captain', 'blue-tech-planet', 1 from family
union all
select id, '小满', '小满', 3, 'little-astronaut', 'yellow-candy-planet', 2 from family
on conflict (family_id, name) do update set
  nickname = excluded.nickname,
  age = excluded.age,
  avatar_key = excluded.avatar_key,
  theme_planet = excluded.theme_planet,
  sort_order = excluded.sort_order;

with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
insert into public.guardians (family_id, name, role_key, sort_order)
select id, '爸爸', 'dad', 1 from family
union all
select id, '妈妈', 'mom', 2 from family
union all
select id, '奶奶', 'grandma', 3 from family
on conflict (family_id, role_key) do update set name = excluded.name;

with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
insert into public.rewards (family_id, name, description, cost_stars, sort_order)
select id, '选择一个睡前故事', '今晚可以自己选择一本睡前故事。', 10, 1 from family
union all
select id, '亲子游戏 15 分钟', '晚饭后安排 15 分钟亲子游戏时间。', 20, 2 from family
union all
select id, '选择一次家庭电影', '周末可以选择一部适合全家看的电影。', 30, 3 from family
union all
select id, '一次小礼物', '兑换一个提前约定好的小礼物。', 50, 4 from family
union all
select id, '户外活动选择权', '选择一次公园、运动或户外活动。', 80, 5 from family
union all
select id, '大愿望兑换', '兑换一次提前约定的大愿望。', 120, 6 from family
on conflict (family_id, name) do update set
  description = excluded.description,
  cost_stars = excluded.cost_stars,
  sort_order = excluded.sort_order;

with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
insert into public.title_rules (family_id, title, required_lifetime_stars, sort_order)
select id, '星球小队员', 10, 1 from family
union all
select id, '闪亮探险家', 30, 2 from family
union all
select id, '自律小勇士', 60, 3 from family
union all
select id, '星球队长', 100, 4 from family
union all
select id, '超级成长官', 150, 5 from family
union all
select id, '家庭英雄', 220, 6 from family
on conflict (family_id, title) do update set
  required_lifetime_stars = excluded.required_lifetime_stars,
  sort_order = excluded.sort_order;

with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
insert into public.badges (
  family_id,
  name,
  description,
  icon_key,
  rule_type,
  rule_value,
  category,
  sort_order
)
select id, '星球小队员勋章', '累计获得 10 颗成长星。', 'badge-star-rookie', 'lifetime_stars', 10, null, 1 from family
union all
select id, '闪亮探险家勋章', '累计获得 30 颗成长星。', 'badge-explorer', 'lifetime_stars', 30, null, 2 from family
union all
select id, '自律小勇士勋章', '累计获得 60 颗成长星。', 'badge-discipline', 'lifetime_stars', 60, null, 3 from family
union all
select id, '星球队长勋章', '累计获得 100 颗成长星。', 'badge-captain', 'lifetime_stars', 100, null, 4 from family
union all
select id, '整理达人勋章', '整理类累计获得 20 颗星。', 'badge-tidy', 'category_positive_stars', 20, '整理', 5 from family
union all
select id, '友爱兄弟勋章', '兄弟互动累计获得 20 颗星。', 'badge-brothers', 'category_positive_stars', 20, '兄弟互动', 6 from family
union all
select id, '睡前小达人勋章', '睡觉类获得 5 次正向记录。', 'badge-bedtime', 'category_positive_count', 5, '睡觉', 7 from family
union all
select id, '情绪管理勋章', '情绪类获得 10 次正向记录。', 'badge-emotion', 'category_positive_count', 10, '情绪', 8 from family
on conflict (family_id, name) do update set
  description = excluded.description,
  icon_key = excluded.icon_key,
  rule_type = excluded.rule_type,
  rule_value = excluded.rule_value,
  category = excluded.category,
  sort_order = excluded.sort_order;

with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
insert into public.settings (family_id, key, value)
select id, 'max_praise_stars', '5'::jsonb from family
union all
select id, 'max_improvement_stars', '3'::jsonb from family
union all
select id, 'daily_deduct_limit', '5'::jsonb from family
union all
select id, 'allow_negative_stars', 'false'::jsonb from family
on conflict (family_id, key) do update set value = excluded.value;
