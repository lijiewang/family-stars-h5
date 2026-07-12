alter table public.summer_task_checkins
  add column if not exists awarded_stars int not null default 2 check (awarded_stars >= 2 and awarded_stars <= 5),
  add column if not exists invalidated_at timestamptz,
  add column if not exists invalidated_by uuid references public.guardians(id),
  add column if not exists invalidated_note text;

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

grant execute on function public.invalidate_summer_task_checkin(uuid, uuid, uuid, text) to authenticated;
