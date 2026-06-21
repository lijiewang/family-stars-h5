alter table public.reward_redemptions
add column if not exists status text not null default 'active';

alter table public.reward_redemptions
add column if not exists invalidated_at timestamptz;

alter table public.reward_redemptions
add column if not exists invalidated_by uuid references public.guardians(id);

alter table public.reward_redemptions
add column if not exists invalidated_note text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'reward_redemptions_status_check'
      and conrelid = 'public.reward_redemptions'::regclass
  ) then
    alter table public.reward_redemptions
    add constraint reward_redemptions_status_check
    check (status in ('active', 'invalidated'));
  end if;
end;
$$;

update public.reward_redemptions
set status = 'active'
where status is null;

create or replace function public.invalidate_reward_redemption(
  p_family_id uuid,
  p_redemption_id uuid,
  p_guardian_id uuid,
  p_note text default null
)
returns public.reward_redemptions
language plpgsql
security definer
set search_path = public
as $$
declare
  target_redemption public.reward_redemptions%rowtype;
  updated_redemption public.reward_redemptions%rowtype;
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
  into target_redemption
  from public.reward_redemptions
  where id = p_redemption_id
    and family_id = p_family_id
  for update;

  if target_redemption.id is null then
    raise exception '兑奖记录不存在';
  end if;

  if target_redemption.status = 'invalidated' then
    raise exception '这条兑奖记录已经失效，不能重复撤回';
  end if;

  update public.children
  set
    available_stars = available_stars + target_redemption.cost_stars,
    spent_stars = greatest(spent_stars - target_redemption.cost_stars, 0)
  where id = target_redemption.child_id
    and family_id = p_family_id;

  update public.reward_redemptions
  set
    status = 'invalidated',
    invalidated_at = now(),
    invalidated_by = p_guardian_id,
    invalidated_note = nullif(trim(coalesce(p_note, '')), '')
  where id = target_redemption.id
  returning * into updated_redemption;

  return updated_redemption;
end;
$$;

grant execute on function public.invalidate_reward_redemption(uuid, uuid, uuid, text) to authenticated;
