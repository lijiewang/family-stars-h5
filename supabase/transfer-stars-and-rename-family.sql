create table if not exists public.star_trades (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  from_child_id uuid not null references public.children(id) on delete cascade,
  to_child_id uuid not null references public.children(id) on delete cascade,
  guardian_id uuid not null references public.guardians(id),
  stars int not null check (stars > 0 and stars <= 999),
  item_title text not null check (length(trim(item_title)) > 0),
  note text,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  check (from_child_id <> to_child_id)
);

create index if not exists idx_star_trades_family_created
on public.star_trades(family_id, created_at desc);

alter table public.star_trades enable row level security;

drop policy if exists "members can read star trades" on public.star_trades;
create policy "members can read star trades"
on public.star_trades for select
using (public.is_family_member(family_id));

drop policy if exists "members can read star trades direct" on public.star_trades;
create policy "members can read star trades direct"
on public.star_trades for select
using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = star_trades.family_id
      and fm.user_id = auth.uid()
  )
);

create or replace function public.transfer_stars(
  p_family_id uuid,
  p_from_child_id uuid,
  p_to_child_id uuid,
  p_guardian_id uuid,
  p_stars int,
  p_item_title text,
  p_note text default null
)
returns public.star_trades
language plpgsql
security definer
set search_path = public
as $$
declare
  from_available_stars int;
  new_trade public.star_trades%rowtype;
begin
  if not public.is_family_member(p_family_id) then
    raise exception '没有访问这个家庭空间的权限';
  end if;

  if p_from_child_id = p_to_child_id then
    raise exception '交易双方必须是两个不同的孩子';
  end if;

  if p_stars <= 0 or p_stars > 999 then
    raise exception '交易星星请填写 1 到 999';
  end if;

  if length(trim(coalesce(p_item_title, ''))) = 0 then
    raise exception '必须填写交换物品';
  end if;

  if not exists (
    select 1 from public.guardians
    where id = p_guardian_id and family_id = p_family_id and is_active = true
  ) then
    raise exception '操作人不存在或已停用';
  end if;

  select available_stars
  into from_available_stars
  from public.children
  where id = p_from_child_id
    and family_id = p_family_id
  for update;

  if from_available_stars is null then
    raise exception '付出星星的孩子不存在';
  end if;

  if not exists (
    select 1 from public.children
    where id = p_to_child_id and family_id = p_family_id
  ) then
    raise exception '获得星星的孩子不存在';
  end if;

  if from_available_stars < p_stars then
    raise exception '当前星星不足，不能交易';
  end if;

  update public.children
  set available_stars = available_stars - p_stars
  where id = p_from_child_id
    and family_id = p_family_id;

  update public.children
  set available_stars = available_stars + p_stars
  where id = p_to_child_id
    and family_id = p_family_id;

  insert into public.star_trades (
    family_id,
    from_child_id,
    to_child_id,
    guardian_id,
    stars,
    item_title,
    note,
    created_by
  )
  values (
    p_family_id,
    p_from_child_id,
    p_to_child_id,
    p_guardian_id,
    p_stars,
    trim(p_item_title),
    nullif(trim(coalesce(p_note, '')), ''),
    auth.uid()
  )
  returning * into new_trade;

  return new_trade;
end;
$$;

grant execute on function public.transfer_stars(uuid, uuid, uuid, uuid, int, text, text) to authenticated;

with target_family as (
  update public.families
  set name = '一涵一杉星球探险队'
  where invite_code = 'PIPI-MANMAN'
  returning id
)
update public.children c
set
  name = '一涵',
  nickname = '一涵',
  age = 9,
  avatar_key = 'rocket-captain',
  theme_planet = 'blue-tech-planet',
  sort_order = 1
from target_family f
where c.family_id = f.id
  and c.name = '皮皮'
  and not exists (
    select 1 from public.children existing
    where existing.family_id = f.id
      and existing.name = '一涵'
  );

with target_family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
update public.children c
set
  nickname = '一涵',
  age = 9,
  avatar_key = 'rocket-captain',
  theme_planet = 'blue-tech-planet',
  sort_order = 1
from target_family f
where c.family_id = f.id
  and c.name = '一涵';

with target_family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
update public.children c
set
  name = '一杉',
  nickname = '一杉',
  age = 3,
  avatar_key = 'little-astronaut',
  theme_planet = 'yellow-candy-planet',
  sort_order = 2
from target_family f
where c.family_id = f.id
  and c.name = '小满'
  and not exists (
    select 1 from public.children existing
    where existing.family_id = f.id
      and existing.name = '一杉'
  );

with target_family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
update public.children c
set
  nickname = '一杉',
  age = 3,
  avatar_key = 'little-astronaut',
  theme_planet = 'yellow-candy-planet',
  sort_order = 2
from target_family f
where c.family_id = f.id
  and c.name = '一杉';
